import '../filters/ema10_entry_gates.dart';
import '../models/candle_data.dart';
import '../models/indicator_result.dart';
import '../models/screener_filter.dart';
import '../utils/constants.dart';
import 'indicator_utils.dart';
import 'supertrend_indicator.dart';

/// Entry: close above EMA 10/200, EMA 10 crossed above 30 and 48,
///        Supertrend BUY when [Ema10CrossFilterParams.requireSupertrend],
///        and entry gates (liquidity, no climax volume, not defensive).
/// Exit: EMA 10 crossed below 30 and 48, or Supertrend SELL.
class Ema10CrossIndicator {
  static const int _kHistoryLen = 50;

  static Ema10CrossResult? calculate(
    List<CandleData> candles,
    Ema10CrossFilterParams params, {
    String? symbol,
  }) {
    final n = candles.length;
    if (n < params.trendPeriod + 1) return null;

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

    final start = params.trendPeriod;
    final stBull = params.requireSupertrend
        ? SupertrendIndicator.bullSeries(candles, const SupertrendFilterParams())
        : null;
    final history = <SignalType>[];
    for (var i = start; i < n; i++) {
      history.add(
        _signalAt(
          candles,
          closes,
          ema10,
          ema30,
          ema48,
          ema200,
          i,
          params,
          symbol: symbol,
          stBull: stBull?[i],
        ),
      );
    }

    final signal = history.isEmpty ? SignalType.neutral : history.last;
    final setupActive = signal == SignalType.buy;
    final exitActive = signal == SignalType.sell;
    final age = IndicatorUtils.signalAge(history, maxLookback: _kHistoryLen);

    final int cross30Age;
    final int cross48Age;
    if (exitActive) {
      cross30Age = _barsSinceCrossBelow(ema10, ema30, last) ?? _kHistoryLen;
      cross48Age = _barsSinceCrossBelow(ema10, ema48, last) ?? _kHistoryLen;
    } else {
      cross30Age = _barsSinceCrossAbove(ema10, ema30, last) ?? _kHistoryLen;
      cross48Age = _barsSinceCrossAbove(ema10, ema48, last) ?? _kHistoryLen;
    }

    String? skipReason;
    if (!setupActive && !exitActive) {
      final emaBuy = _isSetup(closes, ema10, ema30, ema48, ema200, last, params.crossLookback);
      if (emaBuy) {
        skipReason = Ema10EntryGates.buySkipReason(
          candles: candles,
          i: last,
          params: params,
          symbol: symbol,
        );
      }
    }

    return Ema10CrossResult(
      ema10: e10,
      ema30: e30,
      ema48: e48,
      ema200: e200,
      cross30Age: cross30Age,
      cross48Age: cross48Age,
      setupActive: setupActive,
      exitActive: exitActive,
      skipReason: skipReason,
      requireSupertrend: params.requireSupertrend,
      signal: signal,
      signalAge: age,
    );
  }

  static bool matchesFilter(
    Ema10CrossResult result,
    Ema10CrossFilterParams params,
  ) {
    switch (params.signal) {
      case FilterSignal.buy:
        return result.signal == SignalType.buy;
      case FilterSignal.sell:
        return result.signal == SignalType.sell;
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
    Ema10CrossFilterParams params, {
    String? symbol,
    bool? stBull,
  }) {
    final emaBuy = _isSetup(
      closes,
      ema10,
      ema30,
      ema48,
      ema200,
      i,
      params.crossLookback,
    );
    final emaSell = _isExit(ema10, ema30, ema48, i, params.crossLookback);
    final stBuy = !params.requireSupertrend || stBull == true;
    final stSell = params.requireSupertrend && stBull == false;

    if (emaBuy && stBuy) {
      final skip = Ema10EntryGates.buySkipReason(
        candles: candles,
        i: i,
        params: params,
        symbol: symbol,
      );
      if (skip == null) return SignalType.buy;
      return SignalType.neutral;
    }
    if (emaSell || stSell) return SignalType.sell;
    return SignalType.neutral;
  }

  static bool _isSetup(
    List<double> closes,
    List<double?> ema10,
    List<double?> ema30,
    List<double?> ema48,
    List<double?> ema200,
    int i,
    int lookback,
  ) {
    final close = closes[i];
    final e10 = ema10[i];
    final e30 = ema30[i];
    final e48 = ema48[i];
    final e200 = ema200[i];
    if (e10 == null || e30 == null || e48 == null || e200 == null) return false;

    final above10200 = close > e10 && close > e200 && e10 > e200;
    if (!above10200 || e10 <= e30 || e10 <= e48) return false;

    final age30 = _barsSinceCrossAbove(ema10, ema30, i);
    final age48 = _barsSinceCrossAbove(ema10, ema48, i);
    if (age30 == null || age48 == null) return false;
    final completingAge = age30 < age48 ? age30 : age48;
    return completingAge <= lookback;
  }

  static bool _isExit(
    List<double?> ema10,
    List<double?> ema30,
    List<double?> ema48,
    int i,
    int lookback,
  ) {
    final e10 = ema10[i];
    final e30 = ema30[i];
    final e48 = ema48[i];
    if (e10 == null || e30 == null || e48 == null) return false;
    if (e10 >= e30 || e10 >= e48) return false;

    final age30 = _barsSinceCrossBelow(ema10, ema30, i);
    final age48 = _barsSinceCrossBelow(ema10, ema48, i);
    if (age30 == null || age48 == null) return false;
    final completingAge = age30 < age48 ? age30 : age48;
    return completingAge <= lookback;
  }

  /// Bars since EMA [fast] last crossed above [slow], while still above.
  static int? _barsSinceCrossAbove(
    List<double?> fast,
    List<double?> slow,
    int end,
  ) {
    final fNow = fast[end];
    final sNow = slow[end];
    if (fNow == null || sNow == null || fNow <= sNow) return null;

    for (var i = end; i >= 1; i--) {
      final f = fast[i];
      final s = slow[i];
      final pf = fast[i - 1];
      final ps = slow[i - 1];
      if (f == null || s == null || pf == null || ps == null) return null;
      if (pf <= ps && f > s) return end - i;
      if (f <= s) return null;
    }
    return null;
  }

  /// Bars since EMA [fast] last crossed below [slow], while still below.
  static int? _barsSinceCrossBelow(
    List<double?> fast,
    List<double?> slow,
    int end,
  ) {
    final fNow = fast[end];
    final sNow = slow[end];
    if (fNow == null || sNow == null || fNow >= sNow) return null;

    for (var i = end; i >= 1; i--) {
      final f = fast[i];
      final s = slow[i];
      final pf = fast[i - 1];
      final ps = slow[i - 1];
      if (f == null || s == null || pf == null || ps == null) return null;
      if (pf >= ps && f < s) return end - i;
      if (f >= s) return null;
    }
    return null;
  }
}
