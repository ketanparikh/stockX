import '../filters/stock_quality_filter.dart';
import '../indicators/adx_indicator.dart';
import '../indicators/sethi_indicator.dart';
import '../indicators/bollinger_bands_indicator.dart';
import '../indicators/chandelier_exit_indicator.dart';
import '../indicators/ema_indicator.dart';
import '../indicators/macd_indicator.dart';
import '../indicators/rsi_indicator.dart';
import '../indicators/supertrend_indicator.dart';
import '../models/stock_search_analysis.dart';
import '../models/candle_data.dart';
import '../models/indicator_result.dart';
import '../models/screener_filter.dart';
import '../models/screener_result.dart';
import '../models/screener_result_codec.dart';
import '../utils/constants.dart';
import '../utils/screener_filter_fingerprint.dart';
import '../utils/stock_symbols.dart';
import 'cache_service.dart';
import 'data_sync_service.dart';
import 'supabase_service.dart';
import 'yahoo_finance_service.dart';

class ScreenerService {
  final CacheService _cache;
  final DataSyncService _syncService;
  final SupabaseService _supabase;
  final YahooFinanceService _yahoo;

  ScreenerService(
    this._cache,
    this._syncService,
    this._supabase,
    this._yahoo,
  );

  Future<List<ScreenerResult>> runScreener(
    ScreenerFilter filter, {
    void Function(int processed, int total)? onProgress,
  }) async {
    // Get stocks to screen
    final stocksToScreen = _getStocksToScreen(filter);
    if (stocksToScreen.isEmpty) return [];

    // Bulk-load candles from Supabase into the session cache (few HTTP calls).
    // Avoids thousands of per-stock Yahoo requests when data was pre-filled
    // by fetch_nse_data.py / in-app sync.
    if (_supabase.isAvailable) {
      final symbols = stocksToScreen.map((s) => s.symbol).toList();
      final fromCloud = await _supabase.readBatch(symbols, filter.timeframe);
      for (final entry in fromCloud.entries) {
        if (entry.value.length >= 2) {
          _cache.store(entry.key, filter.timeframe, entry.value);
        }
      }
    }

    final String? filterCacheHash =
        filter.hasAnyFilter && _supabase.isAvailable
            ? screenerFilterCacheHash(filter)
            : null;

    if (filterCacheHash != null) {
      final row =
          await _supabase.readScreenerFilterCache(filterCacheHash, filter.timeframe);
      if (row != null) {
        final builtAt = _parseUtc(row['built_at']);
        final payloadRaw = row['payload'];
        if (builtAt != null &&
            DateTime.now().toUtc().difference(builtAt) <=
                AppConstants.screenerFilterCacheTtl &&
            payloadRaw is Map) {
          final payload = Map<String, dynamic>.from(payloadRaw);
          final cached = decodeScreenerResultsPayload(
            payload,
            (sym) => _cache.get(sym, filter.timeframe) ?? const [],
          );
          if (cached.isNotEmpty) {
            onProgress?.call(stocksToScreen.length, stocksToScreen.length);
            return _applyMaxResults(cached, filter.maxResults);
          }
        }
      }
    }

    // After a warm cache, use higher concurrency and shorter pauses so the
    // screener is CPU-bound instead of waiting on artificial throttling.
    final cacheRatio = _cacheCoverageRatio(stocksToScreen, filter.timeframe);
    final batchSize = cacheRatio >= 0.85
        ? 40
        : cacheRatio >= 0.5
            ? 25
            : 12;
    final batchDelay = cacheRatio >= 0.85
        ? Duration.zero
        : cacheRatio >= 0.5
            ? const Duration(milliseconds: 40)
            : const Duration(milliseconds: 120);

    final results = <ScreenerResult>[];
    int processed = 0;

    final marketCaps = filter.useQualityFilter &&
            filter.qualityParams.minMarketCapCrore > 0
        ? await _loadMarketCaps(stocksToScreen)
        : const <String, double>{};

    for (int i = 0; i < stocksToScreen.length; i += batchSize) {
      final end = (i + batchSize).clamp(0, stocksToScreen.length);
      final batch = stocksToScreen.sublist(i, end);

      final batchResults = await Future.wait(
        batch.map((stock) => _processStock(stock, filter, marketCaps)),
      );

      for (final result in batchResults) {
        if (result != null) {
          final passes = _passesFilter(result, filter);
          if (passes) results.add(result);
        }
      }

      processed += batch.length;
      onProgress?.call(processed, stocksToScreen.length);

      if (i + batchSize < stocksToScreen.length && batchDelay > Duration.zero) {
        await Future.delayed(batchDelay);
      }
    }

    results.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    final finalResults = _applyMaxResults(results, filter.maxResults);

    if (filterCacheHash != null && finalResults.isNotEmpty) {
      _supabase
          .writeScreenerFilterCache(
            filterCacheHash,
            filter.timeframe,
            encodeScreenerResultsPayload(finalResults),
          )
          .ignore();
    }

    return finalResults;
  }

  DateTime? _parseUtc(Object? raw) {
    if (raw is String) return DateTime.tryParse(raw)?.toUtc();
    return null;
  }

  List<ScreenerResult> _applyMaxResults(List<ScreenerResult> rows, int cap) {
    if (cap > 0 && rows.length > cap) return rows.sublist(0, cap);
    return rows;
  }

  List<StockSymbol> _getStocksToScreen(ScreenerFilter filter) {
    final all = StockUniverse.getAll();
    return all.where((s) {
      if (filter.markets.isNotEmpty && !filter.markets.contains(s.market)) {
        return false;
      }
      if (filter.sectors.isNotEmpty && !filter.sectors.contains(s.sector)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Share of [stocks] that already have at least two candles in cache.
  double _cacheCoverageRatio(List<StockSymbol> stocks, String timeframe) {
    if (stocks.isEmpty) return 0;
    int ok = 0;
    for (final s in stocks) {
      final c = _cache.get(s.symbol, timeframe);
      if (c != null && c.length >= 2) ok++;
    }
    return ok / stocks.length;
  }

  Future<Map<String, double>> _loadMarketCaps(List<StockSymbol> stocks) async {
    final indian =
        stocks.where((s) => s.market == 'NSE' || s.market == 'BSE').toList();
    final caps = <String, double>{};
    const chunkSize = 40;

    for (var i = 0; i < indian.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, indian.length);
      final chunk = indian.sublist(i, end);
      try {
        final quotes = await _yahoo.fetchBatchQuotes(chunk);
        for (final entry in quotes.entries) {
          final cap = entry.value.marketCap;
          if (cap != null && cap > 0) caps[entry.key] = cap;
        }
      } catch (_) {}
      if (end < indian.length) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }
    return caps;
  }

  Future<ScreenerResult?> _processStock(
    StockSymbol stock,
    ScreenerFilter filter,
    Map<String, double> marketCaps, {
    bool applyQualityGate = true,
  }) async {
    try {
      // Cache-first: skip the network call if we already have candle data.
      List<CandleData> candles =
          _cache.get(stock.symbol, filter.timeframe) ?? [];

      if (candles.length < 2) {
        // Cache miss — fetch live and populate the cache for future runs.
        final fetched = await _syncService.fetchAndCache(stock, filter.timeframe);
        if (fetched == null || fetched.length < 2) return null;
        candles = fetched;
      }

      if (candles.length < 2) return null;

      if (filter.useQualityFilter && applyQualityGate) {
        final ok = StockQualityFilter.passes(
          candles,
          filter.qualityParams,
          marketCapInr: marketCaps[stock.symbol],
          market: stock.market,
        );
        if (!ok) return null;
      }

      // Derive the quote from candle data — avoids a second API call
      // and the rate-limit / CORS failures that killed results silently.
      final quote = _quoteFromCandles(stock, candles);

      final indicators = _computeIndicators(candles, filter);

      int matchingFilters = 0;
      int totalFilters = 0;

      for (final indicator in indicators) {
        totalFilters++;
        if (_indicatorMatchesFilter(indicator, filter)) {
          matchingFilters++;
        }
      }

      // A stock is only included if at least one indicator was successfully
      // computed (prevents "0 of 0 match" artefacts), unless quality-only run.
      if (totalFilters == 0 && filter.hasIndicatorFilters) return null;

      return ScreenerResult(
        quote: quote,
        candles: candles,
        indicators: indicators,
        matchingFilters: matchingFilters,
        totalFilters: totalFilters,
      );
    } catch (_) {
      return null;
    }
  }

  /// Build a StockQuote from the last two candles.
  /// Covers price, daily change, volume — no extra API call needed.
  StockQuote _quoteFromCandles(StockSymbol stock, List<CandleData> candles) {
    final last = candles.last;
    final prev = candles[candles.length - 2];
    final change = last.close - prev.close;
    final changePct = prev.close != 0 ? (change / prev.close) * 100 : 0.0;

    var week52High = candles.first.high;
    var week52Low = candles.first.low;
    for (final c in candles) {
      if (c.high > week52High) week52High = c.high;
      if (c.low < week52Low) week52Low = c.low;
    }

    return StockQuote(
      symbol: stock.symbol,
      name: stock.name,
      market: stock.market,
      sector: stock.sector,
      price: last.close,
      change: change,
      changePercent: changePct,
      volume: last.volume,
      week52High: week52High,
      week52Low: week52Low,
    );
  }

  List<IndicatorResult> _computeIndicators(
    List<CandleData> candles,
    ScreenerFilter filter,
  ) {
    final indicators = <IndicatorResult>[];

    if (filter.useRsi) {
      final result = RsiIndicator.calculate(candles, filter.rsiParams);
      if (result != null) indicators.add(result);
    }

    if (filter.useSupertrend) {
      final result = SupertrendIndicator.calculate(candles, filter.supertrendParams);
      if (result != null) indicators.add(result);
    }

    if (filter.useChandelier) {
      final result = ChandelierExitIndicator.calculate(candles, filter.chandelierParams);
      if (result != null) indicators.add(result);
    }

    if (filter.useMacd) {
      final result = MacdIndicator.calculate(candles, filter.macdParams);
      if (result != null) indicators.add(result);
    }

    if (filter.useEma) {
      final result = EmaIndicator.calculate(candles, filter.emaParams);
      if (result != null) indicators.add(result);
    }

    if (filter.useBollinger) {
      final result = BollingerBandsIndicator.calculate(candles, filter.bollingerParams);
      if (result != null) indicators.add(result);
    }

    if (filter.useAdx) {
      final result = AdxIndicator.calculate(candles, filter.adxParams);
      if (result != null) indicators.add(result);
    }

    if (filter.useSethi) {
      final result = SethiIndicator.calculate(candles, filter.sethiParams);
      if (result != null) indicators.add(result);
    }

    return indicators;
  }

  bool _indicatorMatchesFilter(IndicatorResult indicator, ScreenerFilter filter) {
    switch (indicator.name) {
      case 'RSI':
        return RsiIndicator.matchesFilter(indicator as RsiResult, filter.rsiParams);
      case 'Supertrend':
        return SupertrendIndicator.matchesFilter(indicator as SupertrendResult, filter.supertrendParams);
      case 'Chandelier Exit':
        return ChandelierExitIndicator.matchesFilter(indicator as ChandelierResult, filter.chandelierParams);
      case 'MACD':
        return MacdIndicator.matchesFilter(indicator as MacdResult, filter.macdParams);
      case 'Bollinger Bands':
        return BollingerBandsIndicator.matchesFilter(indicator as BollingerResult, filter.bollingerParams);
      case 'ADX':
        return AdxIndicator.matchesFilter(indicator as AdxResult, filter.adxParams);
      case 'Sethi':
        return SethiIndicator.matchesFilter(indicator as SethiResult, filter.sethiParams);
      default:
        if (indicator.name.startsWith('EMA')) {
          return EmaIndicator.matchesFilter(indicator as EmaResult, filter.emaParams);
        }
        return true;
    }
  }

  bool _passesFilter(ScreenerResult result, ScreenerFilter filter) {
    if (!filter.hasAnyFilter) return true;

    if (filter.hasIndicatorFilters) {
      final signalOk = filter.requireAllFilters
          ? result.totalFilters > 0 &&
              result.matchingFilters == result.totalFilters
          : result.matchingFilters > 0;

      if (!signalOk) return false;

      if (filter.requireFreshSignal) {
        final matchingIndicators = result.indicators
            .where((ind) => _indicatorMatchesFilter(ind, filter));
        final allFresh = matchingIndicators
            .every((ind) => ind.isFresh(filter.freshSignalMaxBars));
        if (!allFresh) return false;
      }
    }

    return true;
  }

  bool passesQualityFilter(
    List<CandleData> candles,
    StockSymbol stock,
    ScreenerFilter filter, {
    Map<String, double>? marketCaps,
  }) {
    if (!filter.useQualityFilter) return true;
    return StockQualityFilter.passes(
      candles,
      filter.qualityParams,
      marketCapInr: marketCaps?[stock.symbol],
      market: stock.market,
    );
  }

  /// Analyze one stock against [filter] (same logic as a screener run).
  Future<ScreenerResult?> analyzeStock(
    StockSymbol stock,
    ScreenerFilter filter, {
    Map<String, double>? marketCaps,
  }) async {
    Map<String, double> caps = marketCaps ?? const {};
    if (filter.useQualityFilter &&
        filter.qualityParams.minMarketCapCrore > 0 &&
        caps.isEmpty &&
        (stock.market == 'NSE' || stock.market == 'BSE')) {
      caps = await _loadMarketCaps([stock]);
    }
    return _processStock(stock, filter, caps);
  }

  /// Same as [analyzeStock] but keeps stocks that fail the quality gate (for search UI).
  Future<ScreenerResult?> analyzeStockForSearch(
    StockSymbol stock,
    ScreenerFilter filter, {
    Map<String, double>? marketCaps,
  }) async {
    Map<String, double> caps = marketCaps ?? const {};
    if (filter.useQualityFilter &&
        filter.qualityParams.minMarketCapCrore > 0 &&
        caps.isEmpty &&
        (stock.market == 'NSE' || stock.market == 'BSE')) {
      caps = await _loadMarketCaps([stock]);
    }
    return _processStock(stock, filter, caps, applyQualityGate: false);
  }

  /// Whether [result] would be included in screener results for [filter].
  bool passesScreenerFilter(ScreenerResult result, ScreenerFilter filter) =>
      _passesFilter(result, filter);

  List<IndicatorFilterStatus> buildFilterStatuses(
    ScreenerResult result,
    ScreenerFilter filter,
  ) {
    return result.indicators.map((indicator) {
      final enabled = _isIndicatorEnabled(indicator.name, filter);
      return IndicatorFilterStatus(
        indicator: indicator,
        criteriaLabel: _criteriaLabel(indicator.name, filter),
        isFilterEnabled: enabled,
        matchesFilter: enabled && _indicatorMatchesFilter(indicator, filter),
      );
    }).toList();
  }

  Future<StockSearchAnalysis?> analyzeStockSearch(
    StockSymbol stock,
    ScreenerFilter filter,
  ) async {
    Map<String, double> caps = const {};
    if (filter.useQualityFilter &&
        filter.qualityParams.minMarketCapCrore > 0 &&
        (stock.market == 'NSE' || stock.market == 'BSE')) {
      caps = await _loadMarketCaps([stock]);
    }

    ScreenerResult? result = await analyzeStockForSearch(stock, filter, marketCaps: caps);

    if (result == null) return null;

    final qualityPasses = passesQualityFilter(
      result.candles,
      stock,
      filter,
      marketCaps: caps,
    );
    final qualityLabel = filter.useQualityFilter
        ? StockQualityFilter.criteriaLabel(filter.qualityParams)
        : null;

    if (!filter.hasIndicatorFilters) {
      final allIndicators = await computeAllIndicators(result.candles);
      result = ScreenerResult(
        quote: result.quote,
        candles: result.candles,
        indicators: allIndicators,
        matchingFilters: 0,
        totalFilters: 0,
      );
      final statuses = allIndicators
          .map(
            (indicator) => IndicatorFilterStatus(
              indicator: indicator,
              criteriaLabel: 'Signal only (no filter enabled)',
              isFilterEnabled: false,
              matchesFilter: false,
            ),
          )
          .toList();
      return StockSearchAnalysis(
        result: result,
        statuses: statuses,
        passesScreener: filter.useQualityFilter ? qualityPasses : false,
        hasActiveFilters: filter.useQualityFilter,
        qualityPasses: filter.useQualityFilter ? qualityPasses : null,
        qualityCriteriaLabel: qualityLabel,
      );
    }

    final statuses = buildFilterStatuses(result, filter);
    return StockSearchAnalysis(
      result: result,
      statuses: statuses,
      passesScreener:
          qualityPasses && passesScreenerFilter(result, filter),
      hasActiveFilters: true,
      qualityPasses: filter.useQualityFilter ? qualityPasses : null,
      qualityCriteriaLabel: qualityLabel,
    );
  }

  bool _isIndicatorEnabled(String name, ScreenerFilter filter) {
    switch (name) {
      case 'RSI':
        return filter.useRsi;
      case 'Supertrend':
        return filter.useSupertrend;
      case 'Chandelier Exit':
        return filter.useChandelier;
      case 'MACD':
        return filter.useMacd;
      case 'Bollinger Bands':
        return filter.useBollinger;
      case 'ADX':
        return filter.useAdx;
      case 'Sethi':
        return filter.useSethi;
      default:
        if (name.startsWith('EMA')) return filter.useEma;
        return false;
    }
  }

  String _criteriaLabel(String name, ScreenerFilter filter) {
    switch (name) {
      case 'RSI':
        return 'RSI — ${filter.rsiParams.signal}';
      case 'Supertrend':
        return 'Supertrend — ${filter.supertrendParams.signal}';
      case 'Chandelier Exit':
        return 'Chandelier Exit — ${filter.chandelierParams.signal}';
      case 'MACD':
        return 'MACD — ${filter.macdParams.signal}';
      case 'Bollinger Bands':
        return 'Bollinger — ${filter.bollingerParams.signal}';
      case 'ADX':
        return 'ADX — ${filter.adxParams.signal}';
      case 'Sethi':
        return 'Sethi — ${filter.sethiParams.signal}';
      default:
        if (name.startsWith('EMA')) {
          return 'EMA — ${filter.emaParams.signal}';
        }
        return name;
    }
  }

  // Compute all indicators for a single stock (for detail view)
  Future<List<IndicatorResult>> computeAllIndicators(
    List<CandleData> candles,
  ) async {
    final indicators = <IndicatorResult>[];

    final rsi = RsiIndicator.calculate(candles, const RsiFilterParams());
    if (rsi != null) indicators.add(rsi);

    final supertrend = SupertrendIndicator.calculate(candles, const SupertrendFilterParams());
    if (supertrend != null) indicators.add(supertrend);

    final chandelier = ChandelierExitIndicator.calculate(candles, const ChandelierFilterParams());
    if (chandelier != null) indicators.add(chandelier);

    final macd = MacdIndicator.calculate(candles, const MacdFilterParams());
    if (macd != null) indicators.add(macd);

    final ema = EmaIndicator.calculate(candles, const EmaFilterParams());
    if (ema != null) indicators.add(ema);

    final bollinger = BollingerBandsIndicator.calculate(candles, const BollingerFilterParams());
    if (bollinger != null) indicators.add(bollinger);

    final adx = AdxIndicator.calculate(candles, const AdxFilterParams());
    if (adx != null) indicators.add(adx);

    final sethi = SethiIndicator.calculate(candles, const SethiFilterParams());
    if (sethi != null) indicators.add(sethi);

    return indicators;
  }
}
