import '../models/candle_data.dart';
import '../models/indicator_result.dart';
import '../models/screener_filter.dart';
import 'indicator_utils.dart';

/// MACD — Moving Average Convergence/Divergence.
///
/// Components:
///   MACD Line   = EMA(close, fast) − EMA(close, slow)
///   Signal Line = EMA(MACD Line, signal)
///   Histogram   = MACD Line − Signal Line  (positive = bullish momentum)
///
/// Alignment note:
///   IndicatorUtils.ema(values, period) seeds at index (period-1), so:
///     fastEma[k] aligns with closes[fastPeriod - 1 + k]
///     slowEma[k] aligns with closes[slowPeriod - 1 + k]
///   MACD line starts where the slow EMA starts:
///     macdLine[k] = fastEma[k + offset] − slowEma[k]
///     where offset = slowPeriod − fastPeriod
///
/// Signal:
///   BUY  — MACD line crossed above Signal line on the last bar
///   SELL — MACD line crossed below Signal line on the last bar
///   (If no fresh crossover, direction is inferred from current position)
class MacdIndicator {
  static MacdResult? calculate(
    List<CandleData> candles,
    MacdFilterParams params,
  ) {
    final minLength = params.slowPeriod + params.signalPeriod;
    if (candles.length < minLength) return null;

    final closes = candles.map((c) => c.close).toList();
    final fastEma = IndicatorUtils.ema(closes, params.fastPeriod);
    final slowEma = IndicatorUtils.ema(closes, params.slowPeriod);

    if (fastEma.isEmpty || slowEma.isEmpty) return null;

    // Align fast to slow: offset = slowPeriod - fastPeriod
    final offset = params.slowPeriod - params.fastPeriod;
    if (fastEma.length <= offset) return null;

    final macdLine = <double>[];
    for (int i = 0; i < slowEma.length; i++) {
      macdLine.add(fastEma[i + offset] - slowEma[i]);
    }

    // Signal line = EMA of MACD line
    final signalLine = IndicatorUtils.ema(macdLine, params.signalPeriod);
    if (signalLine.isEmpty) return null;

    // Last bar values
    // signalLine[k] aligns with macdLine[signalPeriod - 1 + k]
    // so signalLine.last aligns with macdLine.last ✓
    final currentMacd   = macdLine.last;
    final currentSignal = signalLine.last;
    // Histogram: positive means bullish momentum (MACD above Signal)
    final histogram = currentMacd - currentSignal;

    // Previous bar values for crossover detection
    // signalLine[length-2] aligns with macdLine[signalPeriod - 1 + length - 2]
    final macdAlignedPrev = signalLine.length >= 2
        ? macdLine[macdLine.length - signalLine.length + signalLine.length - 2]
        : null; // = macdLine[macdLine.length - 2]
    final prevSignal = signalLine.length >= 2 ? signalLine[signalLine.length - 2] : null;

    final SignalType signal;
    if (macdAlignedPrev != null && prevSignal != null) {
      if (macdAlignedPrev <= prevSignal && currentMacd > currentSignal) {
        signal = SignalType.buy;  // bullish crossover
      } else if (macdAlignedPrev >= prevSignal && currentMacd < currentSignal) {
        signal = SignalType.sell; // bearish crossover
      } else {
        // No fresh crossover — indicate current momentum direction
        signal = currentMacd >= currentSignal ? SignalType.buy : SignalType.sell;
      }
    } else {
      signal = currentMacd >= currentSignal ? SignalType.buy : SignalType.sell;
    }

    return MacdResult(
      macdLine: currentMacd,
      signalLine: currentSignal,
      histogram: histogram,
      signal: signal,
    );
  }

  static bool matchesFilter(MacdResult result, MacdFilterParams params) {
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
