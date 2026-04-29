import '../models/candle_data.dart';
import '../models/indicator_result.dart';
import '../models/screener_filter.dart';
import 'indicator_utils.dart';

/// Supertrend indicator based on ATR with Wilder smoothing.
///
/// Algorithm (matches TradingView / standard Pine Script implementation):
///   basic_upper = hl2 + multiplier * ATR
///   basic_lower = hl2 - multiplier * ATR
///
/// Final bands only move in one direction per trend leg:
///   finalLower = max(basicLower, prevFinalLower)  when prevClose > prevFinalLower
///             = basicLower                         when prevClose <= prevFinalLower
///   finalUpper = min(basicUpper, prevFinalUpper)  when prevClose < prevFinalUpper
///             = basicUpper                         when prevClose >= prevFinalUpper
///
/// Direction flips:
///   Bullish leg → flip to bearish when close < finalLower
///   Bearish leg → flip to bullish when close > finalUpper
class SupertrendIndicator {
  static SupertrendResult? calculate(
    List<CandleData> candles,
    SupertrendFilterParams params,
  ) {
    // atr output length = candles.length - period
    final atrValues = IndicatorUtils.atr(candles, params.period);
    if (atrValues.length < 2) return null;

    // atr[i] aligns with candles[params.period + i]
    final startIdx = params.period;
    final n = atrValues.length; // number of candles we can compute Supertrend for

    final upperBand = List<double>.filled(n, 0);
    final lowerBand = List<double>.filled(n, 0);
    final supertrend = List<double>.filled(n, 0);
    // true = bullish (price above lowerBand), false = bearish (price below upperBand)
    final isBull = List<bool>.filled(n, true);

    // Initialise first bar
    final c0 = candles[startIdx];
    final hl2_0 = (c0.high + c0.low) / 2;
    upperBand[0] = hl2_0 + params.multiplier * atrValues[0];
    lowerBand[0] = hl2_0 - params.multiplier * atrValues[0];
    // Seed: assume bullish on the first bar
    isBull[0] = true;
    supertrend[0] = lowerBand[0];

    for (int i = 1; i < n; i++) {
      final c = candles[startIdx + i];
      final prevC = candles[startIdx + i - 1];
      final hl2 = (c.high + c.low) / 2;

      // Basic bands for current bar
      final basicUpper = hl2 + params.multiplier * atrValues[i];
      final basicLower = hl2 - params.multiplier * atrValues[i];

      // Final lower band: only allowed to move UP (support ratchets up)
      // Reset if previous close broke below the previous support
      lowerBand[i] = (basicLower > lowerBand[i - 1] || prevC.close < lowerBand[i - 1])
          ? basicLower
          : lowerBand[i - 1];

      // Final upper band: only allowed to move DOWN (resistance ratchets down)
      // Reset if previous close broke above the previous resistance
      upperBand[i] = (basicUpper < upperBand[i - 1] || prevC.close > upperBand[i - 1])
          ? basicUpper
          : upperBand[i - 1];

      // Determine direction
      if (isBull[i - 1]) {
        // Was bullish — flip to bearish only if close drops below the lower band
        isBull[i] = c.close >= lowerBand[i];
      } else {
        // Was bearish — flip to bullish only if close rises above the upper band
        isBull[i] = c.close > upperBand[i];
      }

      supertrend[i] = isBull[i] ? lowerBand[i] : upperBand[i];
    }

    final bullish = isBull.last;
    return SupertrendResult(
      supertrendValue: supertrend.last,
      isBullish: bullish,
      signal: bullish ? SignalType.buy : SignalType.sell,
    );
  }

  static bool matchesFilter(SupertrendResult result, SupertrendFilterParams params) {
    switch (params.signal) {
      case 'BUY':
        return result.signal == SignalType.buy;
      case 'SELL':
        return result.signal == SignalType.sell;
      default:
        return true;
    }
  }
}
