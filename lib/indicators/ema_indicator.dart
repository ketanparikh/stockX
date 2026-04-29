import '../models/candle_data.dart';
import '../models/indicator_result.dart';
import '../models/screener_filter.dart';
import 'indicator_utils.dart';

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

    // Align: fastEma[k] and slowEma[k] both correspond to closes.last - (slowEma.length-1-k)
    // fast is longer by (slowPeriod - fastPeriod) elements at the start
    final offset = fastEma.length - slowEma.length;
    if (offset < 0) return null;

    // Build aligned signal history
    final signalHistory = List.generate(slowEma.length, (k) {
      final f = fastEma[offset + k];
      final s = slowEma[k];
      return f >= s ? SignalType.buy : SignalType.sell;
    });

    final age = IndicatorUtils.signalAge(signalHistory);

    final currentFast = fastEma.last;
    final currentSlow = slowEma.last;
    final prevFast    = fastEma[fastEma.length - 2];
    final prevSlow    = slowEma[slowEma.length - 2];

    final SignalType signal;
    if (prevFast <= prevSlow && currentFast > currentSlow) {
      signal = SignalType.buy;
    } else if (prevFast >= prevSlow && currentFast < currentSlow) {
      signal = SignalType.sell;
    } else {
      signal = currentFast >= currentSlow ? SignalType.buy : SignalType.sell;
    }

    return EmaResult(
      label: 'EMA ${params.fastPeriod}/${params.slowPeriod}',
      fastEma: currentFast,
      slowEma: currentSlow,
      signal: signal,
      signalAge: age,
    );
  }

  static bool matchesFilter(EmaResult result, EmaFilterParams params) {
    switch (params.signal) {
      case 'BUY':  return result.signal == SignalType.buy;
      case 'SELL': return result.signal == SignalType.sell;
      default:     return true;
    }
  }
}
