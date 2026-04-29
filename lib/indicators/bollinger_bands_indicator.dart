import '../models/candle_data.dart';
import '../models/indicator_result.dart';
import '../models/screener_filter.dart';
import 'indicator_utils.dart';

class BollingerBandsIndicator {
  static const int _kHistoryLen = 50;

  static BollingerResult? calculate(
    List<CandleData> candles,
    BollingerFilterParams params,
  ) {
    if (candles.length < params.period) return null;

    final closes = candles.map((c) => c.close).toList();
    final smaValues = IndicatorUtils.sma(closes, params.period);
    if (smaValues.isEmpty) return null;

    // Build signal history from the SMA series
    final histStart = smaValues.length > _kHistoryLen
        ? smaValues.length - _kHistoryLen
        : 0;

    final signalHistory = <SignalType>[];
    for (int k = histStart; k < smaValues.length; k++) {
      final barIdx = params.period - 1 + k; // closes index
      if (barIdx >= closes.length) break;

      final middle = smaValues[k];
      final window = closes.sublist(barIdx - params.period + 1, barIdx + 1);
      final sd = IndicatorUtils.stdDev(window);

      final upper = middle + params.stdDev * sd;
      final lower = middle - params.stdDev * sd;
      final close = closes[barIdx];
      final bandwidth = upper - lower;

      if (bandwidth > 0) {
        final pos = (close - lower) / bandwidth;
        if (pos <= 0.1) {
          signalHistory.add(SignalType.buy);
        } else if (pos >= 0.9) {
          signalHistory.add(SignalType.sell);
        } else {
          signalHistory.add(SignalType.neutral);
        }
      } else {
        signalHistory.add(SignalType.neutral);
      }
    }

    if (signalHistory.isEmpty) return null;

    final age    = IndicatorUtils.signalAge(signalHistory);
    final middle = smaValues.last;
    final lastWindow = closes.sublist(closes.length - params.period);
    final sd     = IndicatorUtils.stdDev(lastWindow);
    final upper  = middle + params.stdDev * sd;
    final lower  = middle - params.stdDev * sd;

    return BollingerResult(
      upper: upper,
      middle: middle,
      lower: lower,
      close: closes.last,
      signal: signalHistory.last,
      signalAge: age,
    );
  }

  static bool matchesFilter(BollingerResult result, BollingerFilterParams params) {
    switch (params.signal) {
      case 'BUY':     return result.signal == SignalType.buy;
      case 'SELL':    return result.signal == SignalType.sell;
      case 'NEUTRAL': return result.signal == SignalType.neutral;
      default:        return true;
    }
  }
}
