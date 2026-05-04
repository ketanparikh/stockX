import '../indicators/adx_indicator.dart';
import '../indicators/bollinger_bands_indicator.dart';
import '../indicators/chandelier_exit_indicator.dart';
import '../indicators/ema_indicator.dart';
import '../indicators/macd_indicator.dart';
import '../indicators/rsi_indicator.dart';
import '../indicators/supertrend_indicator.dart';
import '../models/candle_data.dart';
import '../models/indicator_result.dart';
import '../models/screener_filter.dart';
import '../models/screener_result.dart';
import '../utils/constants.dart';
import '../utils/stock_symbols.dart';
import 'cache_service.dart';
import 'data_sync_service.dart';
import 'yahoo_finance_service.dart';

class ScreenerService {
  final YahooFinanceService _financeService;
  final CacheService _cache;
  final DataSyncService _syncService;

  ScreenerService(this._financeService, this._cache, this._syncService);

  Future<List<ScreenerResult>> runScreener(
    ScreenerFilter filter, {
    void Function(int processed, int total)? onProgress,
  }) async {
    // Get stocks to screen
    final stocksToScreen = _getStocksToScreen(filter);
    if (stocksToScreen.isEmpty) return [];

    final results = <ScreenerResult>[];
    int processed = 0;

    // 10 concurrent requests per batch; 150 ms inter-batch pause.
    // This gives ~3–4 min for the full 1 500-stock NSE universe.
    const batchSize = 10;
    const batchDelay = Duration(milliseconds: 150);

    for (int i = 0; i < stocksToScreen.length; i += batchSize) {
      final end = (i + batchSize).clamp(0, stocksToScreen.length);
      final batch = stocksToScreen.sublist(i, end);

      final batchResults = await Future.wait(
        batch.map((stock) => _processStock(stock, filter)),
      );

      for (final result in batchResults) {
        if (result != null) {
          final passes = _passesFilter(result, filter);
          if (passes) results.add(result);
        }
      }

      processed += batch.length;
      onProgress?.call(processed, stocksToScreen.length);

      if (i + batchSize < stocksToScreen.length) {
        await Future.delayed(batchDelay);
      }
    }

    // Sort by match score descending, then cap to maxResults
    results.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    final cap = filter.maxResults;
    return (cap > 0 && results.length > cap) ? results.sublist(0, cap) : results;
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

  Future<ScreenerResult?> _processStock(
    StockSymbol stock,
    ScreenerFilter filter,
  ) async {
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
      // computed (prevents "0 of 0 match" artefacts).
      if (totalFilters == 0 && filter.hasAnyFilter) return null;

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

    return StockQuote(
      symbol: stock.symbol,
      name: stock.name,
      market: stock.market,
      sector: stock.sector,
      price: last.close,
      change: change,
      changePercent: changePct,
      volume: last.volume,
      week52High: candles.map((c) => c.high).reduce((a, b) => a > b ? a : b),
      week52Low: candles.map((c) => c.low).reduce((a, b) => a < b ? a : b),
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
      default:
        if (indicator.name.startsWith('EMA')) {
          return EmaIndicator.matchesFilter(indicator as EmaResult, filter.emaParams);
        }
        return true;
    }
  }

  bool _passesFilter(ScreenerResult result, ScreenerFilter filter) {
    if (!filter.hasAnyFilter) return true;

    final signalOk = filter.requireAllFilters
        ? result.totalFilters > 0 && result.matchingFilters == result.totalFilters
        : result.matchingFilters > 0;

    if (!signalOk) return false;

    // Fresh-signal gate: every MATCHING indicator must have fired within
    // the configured look-back window.
    if (filter.requireFreshSignal) {
      final matchingIndicators = result.indicators
          .where((ind) => _indicatorMatchesFilter(ind, filter));
      final allFresh = matchingIndicators
          .every((ind) => ind.isFresh(filter.freshSignalMaxBars));
      if (!allFresh) return false;
    }

    return true;
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

    return indicators;
  }
}
