import 'dart:math' as math;
import '../models/candle_data.dart';

class IndicatorUtils {
  /// Simple Moving Average. Returns values starting from index [period-1].
  /// Output length = values.length - period + 1.
  static List<double> sma(List<double> values, int period) {
    if (values.length < period) return [];
    final result = <double>[];
    double windowSum = 0;
    for (int i = 0; i < period; i++) {
      windowSum += values[i];
    }
    result.add(windowSum / period);
    for (int i = period; i < values.length; i++) {
      windowSum += values[i] - values[i - period];
      result.add(windowSum / period);
    }
    return result;
  }

  /// Exponential Moving Average seeded with SMA of the first [period] values.
  /// Output length = values.length - period + 1.
  /// output[k] corresponds to values[period - 1 + k].
  static List<double> ema(List<double> values, int period) {
    if (values.length < period) return [];
    final k = 2.0 / (period + 1);
    final result = <double>[];
    double seed = 0;
    for (int i = 0; i < period; i++) {
      seed += values[i];
    }
    seed /= period;
    result.add(seed);
    for (int i = period; i < values.length; i++) {
      result.add(values[i] * k + result.last * (1 - k));
    }
    return result;
  }

  /// Wilder EMA (smoothing factor = 1/period), seeded with SMA of first [period] values.
  /// Used for ATR and ADX calculations.
  /// Output length = values.length - period + 1.
  static List<double> wilderEma(List<double> values, int period) {
    if (values.length < period) return [];
    final result = <double>[];
    double seed = 0;
    for (int i = 0; i < period; i++) {
      seed += values[i];
    }
    seed /= period;
    result.add(seed);
    for (int i = period; i < values.length; i++) {
      result.add(result.last + (values[i] - result.last) / period);
    }
    return result;
  }

  /// True Range for each candle starting from index 1.
  /// Output length = candles.length - 1.
  static List<double> trueRange(List<CandleData> candles) {
    final tr = <double>[];
    for (int i = 1; i < candles.length; i++) {
      final high = candles[i].high;
      final low = candles[i].low;
      final prevClose = candles[i - 1].close;
      final tr1 = high - low;
      final tr2 = (high - prevClose).abs();
      final tr3 = (low - prevClose).abs();
      tr.add(math.max(tr1, math.max(tr2, tr3)));
    }
    return tr;
  }

  /// Wilder-smoothed ATR.
  /// atr[0] corresponds to candles[period] (uses candles[0..period] for TR).
  /// Output length = candles.length - period.
  static List<double> atr(List<CandleData> candles, int period) {
    final tr = trueRange(candles); // length = candles.length - 1
    return wilderEma(tr, period);
  }

  /// Simple rolling ATR (straight average of TR over [period] bars).
  /// Used by Chandelier Exit for a non-lagging ATR.
  /// Output length = candles.length - period  (same indexing as atr()).
  static List<double> simpleAtr(List<CandleData> candles, int period) {
    final tr = trueRange(candles);
    return sma(tr, period);
  }

  /// Counts how many consecutive bars (starting from the last) share the
  /// same signal state, then subtracts 1 to get the "age".
  ///
  /// Age 0 → signal started on the most recent bar (today).
  /// Age N → signal has been continuously active for N+1 bars.
  ///
  /// [signals] must have at least one element.
  /// [maxLookback] caps the scan so we never walk further back than needed.
  static int signalAge<T>(List<T> signals, {int maxLookback = 50}) {
    if (signals.isEmpty) return 0;
    final current = signals.last;
    int age = 0;
    final limit = signals.length - 1;
    for (int i = limit - 1; i >= 0 && age < maxLookback; i--) {
      if (signals[i] == current) {
        age++;
      } else {
        break;
      }
    }
    return age;
  }

  /// Population standard deviation.
  static double stdDev(List<double> values) {
    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            values.length;
    return math.sqrt(variance);
  }
}
