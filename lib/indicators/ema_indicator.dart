import '../models/candle_data.dart';
import '../models/indicator_result.dart';
import '../models/screener_filter.dart';
import 'indicator_utils.dart';

/// EMA Crossover indicator.
///
/// Alignment:
///   IndicatorUtils.ema(closes, period) seeds at index (period-1).
///   fastEma[k] corresponds to closes[fastPeriod - 1 + k].
///   slowEma[k] corresponds to closes[slowPeriod - 1 + k].
///
///   Both fastEma.last and slowEma.last correspond to closes.last. ✓
///   fastEma[fastEma.length - 2] and slowEma[slowEma.length - 2]
///   also correspond to closes[closes.length - 2]. ✓
///
/// Signal:
///   BUY  — fast EMA crossed above slow EMA on the last completed bar
///   SELL — fast EMA crossed below slow EMA on the last completed bar
///   (If no fresh crossover, direction from current relative position is used)
class EmaIndicator {
  static EmaResult? calculate(
    List<CandleData> candles,
    EmaFilterParams params,
  ) {
    if (candles.length < params.slowPeriod + 1) return null;

    final closes = candles.map((c) => c.close).toList();
    final fastEma = IndicatorUtils.ema(closes, params.fastPeriod);
    final slowEma = IndicatorUtils.ema(closes, params.slowPeriod);

    if (fastEma.isEmpty || slowEma.isEmpty) return null;

    final currentFast = fastEma.last;
    final currentSlow = slowEma.last;

    // Previous bar: both [length-2] correspond to the same candle (closes.last - 1)
    final SignalType signal;
    if (fastEma.length >= 2 && slowEma.length >= 2) {
      final prevFast = fastEma[fastEma.length - 2];
      final prevSlow = slowEma[slowEma.length - 2];

      if (prevFast <= prevSlow && currentFast > currentSlow) {
        signal = SignalType.buy;  // bullish crossover
      } else if (prevFast >= prevSlow && currentFast < currentSlow) {
        signal = SignalType.sell; // bearish crossover
      } else {
        signal = currentFast >= currentSlow ? SignalType.buy : SignalType.sell;
      }
    } else {
      signal = currentFast >= currentSlow ? SignalType.buy : SignalType.sell;
    }

    return EmaResult(
      label: 'EMA ${params.fastPeriod}/${params.slowPeriod}',
      fastEma: currentFast,
      slowEma: currentSlow,
      signal: signal,
    );
  }

  static bool matchesFilter(EmaResult result, EmaFilterParams params) {
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
