import '../filters/ema10_entry_gates.dart';
import '../models/candle_data.dart';
import '../models/indicator_result.dart';
import '../models/screener_filter.dart';
import '../utils/constants.dart';
import 'ema_10_cross_indicator.dart';
import 'indicator_utils.dart';

/// Watchlist flag: EMA 10 has crossed 30 and 48, close is still 0–8% below a
/// flattening EMA 200. Not a BUY — wait for close to reclaim 200 (EMA 10 Cross).
class ApproachingEma200Indicator {
  static const int _kHistoryLen = 50;

  static ApproachingEma200Result? calculate(
    List<CandleData> candles,
    ApproachingEma200FilterParams params, {
    String? symbol,
  }) {
    final n = candles.length;
    final minBars = params.trendPeriod + params.slopeLookback + 1;
    if (n < minBars) return null;

    final closes = List<double>.generate(n, (i) => candles[i].close);
    final ema10 = IndicatorUtils.emaAligned(closes, params.fastPeriod);
    final ema30 = IndicatorUtils.emaAligned(closes, params.midFastPeriod);
    final ema48 = IndicatorUtils.emaAligned(closes, params.midSlowPeriod);
    final ema200 = IndicatorUtils.emaAligned(closes, params.trendPeriod);

    final last = n - 1;
    final e10 = ema10[last];
    final e30 = ema30[last];
    final e48 = ema48[last];
    final e200 = ema200[last];
    if (e10 == null || e30 == null || e48 == null || e200 == null) return null;

    final history = <SignalType>[];
    for (var i = params.trendPeriod; i < n; i++) {
      history.add(_signalAt(candles, closes, ema10, ema30, ema48, ema200, i, params, symbol: symbol));
    }

    final signal = history.isEmpty ? SignalType.neutral : history.last;
    final watchlistActive = signal == SignalType.watch;
    final cross30Age =
        Ema10CrossIndicator.barsSinceCrossAbove(ema10, ema30, last) ?? _kHistoryLen;
    final cross48Age =
        Ema10CrossIndicator.barsSinceCrossAbove(ema10, ema48, last) ?? _kHistoryLen;
    final completingAge = cross30Age < cross48Age ? cross30Age : cross48Age;
    final age = watchlistActive
        ? completingAge
        : IndicatorUtils.signalAge(history, maxLookback: _kHistoryLen);

    final pctBelow = e200 > 0 ? (e200 - closes[last]) / e200 * 100.0 : 0.0;
    final slopePct = _slopePct(ema200, last, params.slopeLookback) ?? 0.0;

    String? skipReason;
    if (!watchlistActive) {
      if (_isSetup(closes, ema10, ema30, ema48, ema200, last, params)) {
        skipReason = Ema10EntryGates.buySkipReason(
          candles: candles,
          i: last,
          params: params.gateParams,
          symbol: symbol,
        );
      }
    }

    return ApproachingEma200Result(
      ema10: e10,
      ema30: e30,
      ema48: e48,
      ema200: e200,
      pctBelow200: pctBelow,
      ema200SlopePct: slopePct,
      cross30Age: cross30Age,
      cross48Age: cross48Age,
      watchlistActive: watchlistActive,
      skipReason: skipReason,
      signal: signal,
      signalAge: age,
    );
  }

  static bool matchesFilter(
    ApproachingEma200Result result,
    ApproachingEma200FilterParams params,
  ) {
    switch (params.signal) {
      case FilterSignal.watch:
        return result.signal == SignalType.watch;
      case FilterSignal.neutral:
        return result.signal == SignalType.neutral;
      default:
        return true;
    }
  }

  static SignalType _signalAt(
    List<CandleData> candles,
    List<double> closes,
    List<double?> ema10,
    List<double?> ema30,
    List<double?> ema48,
    List<double?> ema200,
    int i,
    ApproachingEma200FilterParams params, {
    String? symbol,
  }) {
    if (!_isSetup(closes, ema10, ema30, ema48, ema200, i, params)) {
      return SignalType.neutral;
    }
    final skip = Ema10EntryGates.buySkipReason(
      candles: candles,
      i: i,
      params: params.gateParams,
      symbol: symbol,
    );
    if (skip != null) return SignalType.neutral;
    return SignalType.watch;
  }

  static bool _isSetup(
    List<double> closes,
    List<double?> ema10,
    List<double?> ema30,
    List<double?> ema48,
    List<double?> ema200,
    int i,
    ApproachingEma200FilterParams params,
  ) {
    final close = closes[i];
    final e10 = ema10[i];
    final e30 = ema30[i];
    final e48 = ema48[i];
    final e200 = ema200[i];
    if (e10 == null || e30 == null || e48 == null || e200 == null) return false;
    if (!(close > e10 && e10 > e30 && e10 > e48)) return false;
    if (close >= e200 || e200 <= 0) return false;

    final pctBelow = (e200 - close) / e200 * 100.0;
    if (pctBelow <= 0 || pctBelow > params.maxPctBelow) return false;

    final slope = _slopePct(ema200, i, params.slopeLookback);
    if (slope == null || slope < params.minEma200SlopePct) return false;

    final age30 = Ema10CrossIndicator.barsSinceCrossAbove(ema10, ema30, i);
    final age48 = Ema10CrossIndicator.barsSinceCrossAbove(ema10, ema48, i);
    if (age30 == null || age48 == null) return false;
    final completingAge = age30 < age48 ? age30 : age48;
    return completingAge <= params.crossLookback;
  }

  static double? _slopePct(List<double?> ema200, int i, int lookback) {
    if (lookback <= 0 || i < lookback) return null;
    final now = ema200[i];
    final prev = ema200[i - lookback];
    if (now == null || prev == null || prev <= 0) return null;
    return (now / prev - 1.0) * 100.0;
  }
}
