import '../indicators/adx_indicator.dart';
import '../indicators/sethi_indicator.dart';
import '../indicators/bollinger_bands_indicator.dart';
import '../indicators/chandelier_exit_indicator.dart';
import '../indicators/ema_indicator.dart';
import '../indicators/macd_indicator.dart';
import '../indicators/rsi_indicator.dart';
import '../indicators/supertrend_indicator.dart';
import '../models/candle_data.dart';
import '../models/indicator_result.dart';
import '../models/screener_filter.dart';
import '../models/watchlist_entry.dart';
import 'cache_service.dart';

class AlertService {
  /// Check every watchlist entry against current cached candle data.
  /// Returns one [WatchlistAlert] per indicator whose signal has flipped.
  List<WatchlistAlert> checkAlerts(
    Map<String, WatchlistEntry> entries,
    CacheService cache,
  ) {
    final alerts = <WatchlistAlert>[];
    final now = DateTime.now();

    for (final entry in entries.values) {
      if (entry.savedSignals.isEmpty) continue;

      // Try daily first, fall back to weekly
      final List<CandleData>? candles =
          cache.get(entry.symbol, 'daily') ??
          cache.get(entry.symbol, 'weekly');
      if (candles == null || candles.length < 30) continue;

      final current = _computeAll(candles);

      for (final saved in entry.savedSignals) {
        try {
          final ind = current.firstWhere((i) => i.name == saved.indicatorName);
          if (saved.hasFlipped(ind.signal)) {
            alerts.add(WatchlistAlert(
              symbol: entry.symbol,
              indicatorName: saved.indicatorName,
              previousSignal: saved.signal,
              currentSignal: ind.signal.name,
              detectedAt: now,
            ));
          }
        } catch (_) {
          // indicator not found — skip
        }
      }
    }

    return alerts;
  }

  /// Return alerts only for a specific symbol (used on watchlist screen).
  List<WatchlistAlert> checkForSymbol(
    WatchlistEntry entry,
    CacheService cache,
  ) =>
      checkAlerts({entry.symbol: entry}, cache);

  // ── Synchronous all-indicators computation ─────────────────────────────────

  List<IndicatorResult> _computeAll(List<CandleData> candles) {
    final results = <IndicatorResult>[];

    final rsi = RsiIndicator.calculate(candles, const RsiFilterParams());
    if (rsi != null) results.add(rsi);

    final st = SupertrendIndicator.calculate(candles, const SupertrendFilterParams());
    if (st != null) results.add(st);

    final ce = ChandelierExitIndicator.calculate(candles, const ChandelierFilterParams());
    if (ce != null) results.add(ce);

    final macd = MacdIndicator.calculate(candles, const MacdFilterParams());
    if (macd != null) results.add(macd);

    final ema = EmaIndicator.calculate(candles, const EmaFilterParams());
    if (ema != null) results.add(ema);

    final bb = BollingerBandsIndicator.calculate(candles, const BollingerFilterParams());
    if (bb != null) results.add(bb);

    final adx = AdxIndicator.calculate(candles, const AdxFilterParams());
    if (adx != null) results.add(adx);

    final sethi = SethiIndicator.calculate(candles, const SethiFilterParams());
    if (sethi != null) results.add(sethi);

    return results;
  }
}
