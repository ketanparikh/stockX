import '../models/candle_data.dart';
import '../models/indicator_result.dart';
import '../models/screener_filter.dart';
import 'indicator_utils.dart';

class RsiIndicator {
  static const int _kHistoryLen = 50;

  static RsiResult? calculate(
    List<CandleData> candles,
    RsiFilterParams params,
  ) {
    if (candles.length < params.period + 1) return null;

    final closes = candles.map((c) => c.close).toList();

    // Compute full RSI series for signal-age detection
    final fastSeries = _rsiSeries(closes, params.period);
    if (fastSeries.isEmpty) return null;
    final fastRsi = fastSeries.last;

    List<double>? slowSeries;
    double? slowRsi;
    if (params.useDualRsi) {
      if (candles.length < params.slowPeriod + 1) return null;
      slowSeries = _rsiSeries(closes, params.slowPeriod);
      if (slowSeries.isEmpty) return null;
      slowRsi = slowSeries.last;
    }

    // Build aligned signal history for age computation
    final signalHistory = _buildSignalHistory(
      fastSeries, slowSeries, params,
    );
    final age = IndicatorUtils.signalAge(signalHistory, maxLookback: _kHistoryLen);
    final signal = _determineSignal(fastRsi, slowRsi, params);

    return RsiResult(
      fastRsi: fastRsi,
      slowRsi: slowRsi,
      signal: signal,
      signalAge: age,
    );
  }

  // ---------------------------------------------------------------------------

  /// Returns RSI values for every bar starting at index [period].
  static List<double> _rsiSeries(List<double> closes, int period) {
    if (closes.length < period + 1) return [];

    double avgGain = 0, avgLoss = 0;
    for (int i = 1; i <= period; i++) {
      final d = closes[i] - closes[i - 1];
      if (d > 0) avgGain += d; else avgLoss += -d;
    }
    avgGain /= period;
    avgLoss /= period;

    final series = <double>[];
    // seed RSI at bar `period`
    series.add(avgLoss == 0 ? 100.0 : 100.0 - 100.0 / (1.0 + avgGain / avgLoss));

    for (int i = period + 1; i < closes.length; i++) {
      final d = closes[i] - closes[i - 1];
      avgGain = (avgGain * (period - 1) + (d > 0 ? d : 0.0)) / period;
      avgLoss = (avgLoss * (period - 1) + (d < 0 ? -d : 0.0)) / period;
      series.add(avgLoss == 0 ? 100.0 : 100.0 - 100.0 / (1.0 + avgGain / avgLoss));
    }
    return series;
  }

  /// Builds the signal list aligned to the slow series end
  /// (or fast series end if no dual RSI).
  static List<SignalType> _buildSignalHistory(
    List<double> fastSeries,
    List<double>? slowSeries,
    RsiFilterParams params,
  ) {
    if (slowSeries == null) {
      // Single RSI: signal from last _kHistoryLen fast values
      final start = fastSeries.length > _kHistoryLen
          ? fastSeries.length - _kHistoryLen
          : 0;
      return fastSeries.sublist(start).map((rsi) {
        if (rsi <= params.oversoldLevel) return SignalType.buy;
        if (rsi >= params.overboughtLevel) return SignalType.sell;
        return SignalType.neutral;
      }).toList();
    }

    // Dual RSI: align fast to slow (slow starts later)
    final offset = fastSeries.length - slowSeries.length;
    if (offset < 0) return [];
    final len = slowSeries.length;
    final start = len > _kHistoryLen ? len - _kHistoryLen : 0;
    return List.generate(len - start, (k) {
      final f = fastSeries[offset + start + k];
      final s = slowSeries[start + k];
      return f > s ? SignalType.buy : SignalType.sell;
    });
  }

  static SignalType _determineSignal(
    double fastRsi, double? slowRsi, RsiFilterParams params,
  ) {
    if (params.useDualRsi && slowRsi != null) {
      return fastRsi > slowRsi ? SignalType.buy : SignalType.sell;
    }
    if (fastRsi <= params.oversoldLevel) return SignalType.buy;
    if (fastRsi >= params.overboughtLevel) return SignalType.sell;
    return SignalType.neutral;
  }

  static bool matchesFilter(RsiResult result, RsiFilterParams params) {
    if (params.signal != 'ANY') {
      final ok = switch (params.signal) {
        'BUY'     => result.fastRsi <= params.oversoldLevel,
        'SELL'    => result.fastRsi >= params.overboughtLevel,
        'NEUTRAL' => result.fastRsi > params.oversoldLevel &&
                     result.fastRsi < params.overboughtLevel,
        _         => true,
      };
      if (!ok) return false;
    }
    if (params.useDualRsi) {
      final slow = result.slowRsi;
      if (slow == null) return false;
      final ok = switch (params.crossover) {
        RsiCrossover.fastAboveSlow => result.fastRsi > slow,
        RsiCrossover.fastBelowSlow => result.fastRsi < slow,
        _                          => true,
      };
      if (!ok) return false;
    }
    return true;
  }
}
