import 'dart:math' as math;
import '../models/candle_data.dart';
import '../models/indicator_result.dart';
import '../models/screener_filter.dart';
import 'indicator_utils.dart';

/// Chandelier Exit — TradingView-accurate implementation.
///
/// Key behaviours matching new_combined_strategy.py:
///   • ATR  : Wilder's smoothing (RMA) — same as Pine Script ta.atr / pine_rma
///   • Stops: highest HIGH / lowest LOW over the ATR period (TradingView default)
///   • Trailing: stops only ratchet in the profitable direction:
///       - long stop  rises if prev close > prev long stop
///       - short stop falls if prev close < prev short stop
///   • Direction: BUY when close > prev short stop,
///                SELL when close < prev long stop,
///                else continue previous direction
class ChandelierExitIndicator {
  static const int _kHistoryLen = 50;

  static ChandelierResult? calculate(
    List<CandleData> candles,
    ChandelierFilterParams params,
  ) {
    final period     = params.period;
    final multiplier = params.multiplier;

    if (candles.length < period + 2) return null;

    // ── Step 1: Wilder-smoothed ATR (matches Pine Script ta.atr / python pine_rma)
    // atrList[k] corresponds to candles[period + k]
    final atrList = IndicatorUtils.atr(candles, period);
    if (atrList.isEmpty) return null;

    final n = atrList.length; // number of bars with a valid ATR value

    // ── Step 2: Raw (untrailed) stop levels per bar using highest HIGH / lowest LOW
    final rawLongStop  = List<double>.filled(n, 0);
    final rawShortStop = List<double>.filled(n, 0);

    for (int k = 0; k < n; k++) {
      final barIdx  = period + k;
      final winStart = (barIdx - period + 1).clamp(0, candles.length - 1);
      final window   = candles.sublist(winStart, barIdx + 1);
      final hh = window.map((c) => c.high).reduce((a, b) => a > b ? a : b);
      final ll = window.map((c) => c.low ).reduce((a, b) => a < b ? a : b);
      rawLongStop[k]  = hh - multiplier * atrList[k];
      rawShortStop[k] = ll + multiplier * atrList[k];
    }

    // ── Step 3: Trailing stop state + direction tracking
    // Mirrors the bar-by-bar loop in calculate_ce_signals() from Python:
    //   • long  stop trails upward   (ratchets up,  never down)
    //   • short stop trails downward (ratchets down, never up)
    //   • direction flips on confirmed breakout of the opposite stop
    final trailLong  = List<double>.filled(n, 0);
    final trailShort = List<double>.filled(n, 0);
    final dirList    = List<int>.filled(n, 1); // 1 = BUY, -1 = SELL

    trailLong[0]  = rawLongStop[0];
    trailShort[0] = rawShortStop[0];

    for (int k = 1; k < n; k++) {
      final prevClose = candles[period + k - 1].close;

      // Long stop: only ratchets up when previous close is above it
      trailLong[k] = prevClose > trailLong[k - 1]
          ? math.max(rawLongStop[k], trailLong[k - 1])
          : rawLongStop[k];

      // Short stop: only ratchets down when previous close is below it
      trailShort[k] = prevClose < trailShort[k - 1]
          ? math.min(rawShortStop[k], trailShort[k - 1])
          : rawShortStop[k];

      // Direction: compare current close to PREVIOUS bar's trailing stop
      final close = candles[period + k].close;
      if (close > trailShort[k - 1]) {
        dirList[k] = 1;           // confirmed breakout above → BUY
      } else if (close < trailLong[k - 1]) {
        dirList[k] = -1;          // confirmed breakdown below → SELL
      } else {
        dirList[k] = dirList[k - 1]; // no breakout → continue previous direction
      }
    }

    // ── Step 4: Build signal history for signalAge calculation
    final histStart = n > _kHistoryLen ? n - _kHistoryLen : 0;
    final signalHistory = dirList.sublist(histStart).map((d) {
      if (d == 1)  return SignalType.buy;
      if (d == -1) return SignalType.sell;
      return SignalType.neutral;
    }).toList();

    if (signalHistory.isEmpty) return null;

    final currentSignal = signalHistory.last;
    final age = IndicatorUtils.signalAge(signalHistory);

    return ChandelierResult(
      longStop:  trailLong.last,
      shortStop: trailShort.last,
      signal:    currentSignal,
      signalAge: age,
    );
  }

  static bool matchesFilter(ChandelierResult result, ChandelierFilterParams params) {
    switch (params.signal) {
      case 'BUY':     return result.signal == SignalType.buy;
      case 'SELL':    return result.signal == SignalType.sell;
      case 'NEUTRAL': return result.signal == SignalType.neutral;
      default:        return true;
    }
  }
}
