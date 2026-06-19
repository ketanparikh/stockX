import '../models/candle_data.dart';
import '../models/indicator_result.dart';
import '../models/screener_filter.dart';
import 'indicator_utils.dart';

class SupertrendIndicator {
  static SupertrendResult? calculate(
    List<CandleData> candles,
    SupertrendFilterParams params,
  ) {
    final atrValues = IndicatorUtils.atr(candles, params.period);
    if (atrValues.length < 2) return null;

    final startIdx = params.period;
    final n = atrValues.length;

    final upperBand = List<double>.filled(n, 0);
    final lowerBand = List<double>.filled(n, 0);
    final supertrend = List<double>.filled(n, 0);
    final isBull = List<bool>.filled(n, true);

    final c0 = candles[startIdx];
    final hl2_0 = (c0.high + c0.low) / 2;
    upperBand[0] = hl2_0 + params.multiplier * atrValues[0];
    lowerBand[0] = hl2_0 - params.multiplier * atrValues[0];
    isBull[0] = true;
    supertrend[0] = lowerBand[0];

    for (int i = 1; i < n; i++) {
      final c = candles[startIdx + i];
      final prevC = candles[startIdx + i - 1];
      final hl2 = (c.high + c.low) / 2;

      final basicUpper = hl2 + params.multiplier * atrValues[i];
      final basicLower = hl2 - params.multiplier * atrValues[i];

      lowerBand[i] = (basicLower > lowerBand[i - 1] || prevC.close < lowerBand[i - 1])
          ? basicLower : lowerBand[i - 1];
      upperBand[i] = (basicUpper < upperBand[i - 1] || prevC.close > upperBand[i - 1])
          ? basicUpper : upperBand[i - 1];

      // TradingView / Zerodha: flip uses previous bar's final band (not today's).
      if (isBull[i - 1]) {
        isBull[i] = c.close >= lowerBand[i - 1];
      } else {
        isBull[i] = c.close > upperBand[i - 1];
      }
      supertrend[i] = isBull[i] ? lowerBand[i] : upperBand[i];
    }

    // Signal age: scan full history so long-running trends show correct duration.
    final signals = isBull
        .map((b) => b ? SignalType.buy : SignalType.sell)
        .toList();
    final age = IndicatorUtils.signalAge(signals, maxLookback: signals.length);

    final bullish = isBull.last;
    return SupertrendResult(
      supertrendValue: supertrend.last,
      isBullish: bullish,
      signal: bullish ? SignalType.buy : SignalType.sell,
      signalAge: age,
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
