import '../models/candle_data.dart';
import '../models/indicator_result.dart';
import '../models/screener_filter.dart';
import '../utils/constants.dart';
import 'indicator_utils.dart';

/// Breakout + trend + volume + RSI setup from the NSE backtest strategy.
class SethiIndicator {
  static const int _kHistoryLen = 50;
  static const int _minBars = 201;

  static SethiResult? calculate(
    List<CandleData> candles,
    SethiFilterParams params,
  ) {
    if (candles.length < _minBars) return null;

    final n = candles.length;
    final closes = List<double>.generate(n, (i) => candles[i].close);
    final highs = List<double>.generate(n, (i) => candles[i].high);
    final volumes = List<double>.generate(n, (i) => candles[i].volume);

    final dma50 = _sma(closes, params.dmaFastPeriod);
    final dma200 = _sma(closes, params.dmaSlowPeriod);
    final high20 = _rollingMax(highs, params.highLookback, shift: 1);
    final vol20 = _sma(volumes, params.volumeLookback);
    final avgValue = _sma(
      List<double>.generate(n, (i) => closes[i] * volumes[i]),
      params.volumeLookback,
    );
    final rsiSeries = _rsiSeries(closes, params.rsiPeriod);
    if (dma50.length < 2 ||
        dma200.length < 2 ||
        high20.length < 2 ||
        vol20.length < 2 ||
        avgValue.length < 2 ||
        rsiSeries.length < 2) {
      return null;
    }

    final signalHistory = <SignalType>[];
    final start = _minBars - 1;
    for (int i = start; i < n; i++) {
      signalHistory.add(
        _setupActive(
          i,
          candles,
          dma50,
          dma200,
          high20,
          vol20,
          avgValue,
          rsiSeries,
          params,
        )
            ? SignalType.buy
            : SignalType.neutral,
      );
    }

    final age = IndicatorUtils.signalAge(signalHistory, maxLookback: _kHistoryLen);
    final active = signalHistory.last == SignalType.buy;
    final rsi = rsiSeries.last;

    return SethiResult(
      rsi: rsi,
      priorHigh20: high20.last,
      dma50: dma50.last,
      dma200: dma200.last,
      signal: active ? SignalType.buy : SignalType.neutral,
      signalAge: age,
      setupActive: active,
    );
  }

  static bool matchesFilter(SethiResult result, SethiFilterParams params) {
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

  static bool _setupActive(
    int i,
    List<CandleData> candles,
    List<double> dma50,
    List<double> dma200,
    List<double> high20,
    List<double> vol20,
    List<double> avgValue,
    List<double> rsiSeries,
    SethiFilterParams params,
  ) {
    final close = candles[i].close;
    final vol = candles[i].volume;
    final rsi = rsiSeries[i];
    final d50 = dma50[i];
    final d200 = dma200[i];
    final h20 = high20[i];
    final v20 = vol20[i];
    final av = avgValue[i];

    if (close.isNaN ||
        d50.isNaN ||
        d200.isNaN ||
        h20.isNaN ||
        v20.isNaN ||
        av.isNaN ||
        rsi.isNaN) {
      return false;
    }

    return close > h20 &&
        close > d50 &&
        d50 > d200 &&
        vol > params.volumeMultiplier * v20 &&
        rsi >= params.rsiMin &&
        rsi <= params.rsiMax &&
        close >= params.minPrice &&
        av >= params.minAvgValue;
  }

  static List<double> _sma(List<double> values, int period) {
    final out = List<double>.filled(values.length, double.nan);
    if (values.length < period) return out;
    double sum = 0;
    for (int i = 0; i < period; i++) {
      sum += values[i];
    }
    out[period - 1] = sum / period;
    for (int i = period; i < values.length; i++) {
      sum += values[i] - values[i - period];
      out[i] = sum / period;
    }
    return out;
  }

  /// Rolling max with optional shift (1 = prior bar window, matching pandas shift(1)).
  static List<double> _rollingMax(
    List<double> values,
    int period, {
    int shift = 0,
  }) {
    final out = List<double>.filled(values.length, double.nan);
    for (int i = period + shift - 1; i < values.length; i++) {
      final end = i - shift;
      if (end < period - 1) continue;
      var maxV = values[end - period + 1];
      for (int j = end - period + 2; j <= end; j++) {
        if (values[j] > maxV) maxV = values[j];
      }
      out[i] = maxV;
    }
    return out;
  }

  static List<double> _rsiSeries(List<double> closes, int period) {
    final out = List<double>.filled(closes.length, double.nan);
    if (closes.length < period + 1) return out;

    double avgGain = 0, avgLoss = 0;
    for (int i = 1; i <= period; i++) {
      final d = closes[i] - closes[i - 1];
      if (d > 0) {
        avgGain += d;
      } else {
        avgLoss += -d;
      }
    }
    avgGain /= period;
    avgLoss /= period;

    out[period] = _rsiFromAverages(avgGain, avgLoss);
    for (int i = period + 1; i < closes.length; i++) {
      final d = closes[i] - closes[i - 1];
      final gain = d > 0 ? d : 0.0;
      final loss = d < 0 ? -d : 0.0;
      avgGain = (avgGain * (period - 1) + gain) / period;
      avgLoss = (avgLoss * (period - 1) + loss) / period;
      out[i] = _rsiFromAverages(avgGain, avgLoss);
    }
    return out;
  }

  static double _rsiFromAverages(double avgGain, double avgLoss) {
    if (avgLoss == 0) return 100;
    final rs = avgGain / avgLoss;
    return 100 - (100 / (1 + rs));
  }
}
