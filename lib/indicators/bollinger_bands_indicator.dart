import '../models/candle_data.dart';
import '../models/indicator_result.dart';
import '../models/screener_filter.dart';
import 'indicator_utils.dart';

/// Bollinger Bands (John Bollinger).
///
/// Formula:
///   Middle Band = SMA(close, period)
///   Upper  Band = Middle + stdDev * σ(close, period)
///   Lower  Band = Middle − stdDev * σ(close, period)
///
/// σ is the population standard deviation of the last [period] closes.
///
/// Signal (price position within the band):
///   BUY     — close is within the bottom 10% of the band width (near lower band)
///   SELL    — close is within the top 10% of the band width (near upper band)
///   NEUTRAL — close is between 10% and 90% of the band width
class BollingerBandsIndicator {
  static BollingerResult? calculate(
    List<CandleData> candles,
    BollingerFilterParams params,
  ) {
    if (candles.length < params.period) return null;

    final closes = candles.map((c) => c.close).toList();
    final smaValues = IndicatorUtils.sma(closes, params.period);
    if (smaValues.isEmpty) return null;

    final middle = smaValues.last;
    final window = closes.sublist(closes.length - params.period);
    final sd = IndicatorUtils.stdDev(window); // population std dev

    final upper = middle + params.stdDev * sd;
    final lower = middle - params.stdDev * sd;
    final currentClose = closes.last;

    final SignalType signal;
    final bandwidth = upper - lower;
    if (bandwidth > 0) {
      final position = (currentClose - lower) / bandwidth;
      if (position <= 0.1) {
        signal = SignalType.buy;     // near lower band — potential bounce
      } else if (position >= 0.9) {
        signal = SignalType.sell;    // near upper band — potential reversal
      } else {
        signal = SignalType.neutral;
      }
    } else {
      signal = SignalType.neutral; // zero bandwidth (flat price)
    }

    return BollingerResult(
      upper: upper,
      middle: middle,
      lower: lower,
      close: currentClose,
      signal: signal,
    );
  }

  static bool matchesFilter(BollingerResult result, BollingerFilterParams params) {
    switch (params.signal) {
      case 'BUY':
        return result.signal == SignalType.buy;
      case 'SELL':
        return result.signal == SignalType.sell;
      case 'NEUTRAL':
        return result.signal == SignalType.neutral;
      default:
        return true;
    }
  }
}
