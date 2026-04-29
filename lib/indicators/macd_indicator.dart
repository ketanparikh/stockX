import '../models/candle_data.dart';
import '../models/indicator_result.dart';
import '../models/screener_filter.dart';
import 'indicator_utils.dart';

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

    final offset = params.slowPeriod - params.fastPeriod;
    if (fastEma.length <= offset) return null;

    final macdLine = List.generate(
      slowEma.length,
      (i) => fastEma[i + offset] - slowEma[i],
    );

    final signalLine = IndicatorUtils.ema(macdLine, params.signalPeriod);
    if (signalLine.isEmpty) return null;

    // Build signal series aligned to signal line end
    // signalLine[k] aligns with macdLine[signalPeriod-1+k]
    final macdAlignedStart = params.signalPeriod - 1;
    final signalHistory = List.generate(signalLine.length, (k) {
      final m = macdLine[macdAlignedStart + k];
      final s = signalLine[k];
      return m >= s ? SignalType.buy : SignalType.sell;
    });

    final age = IndicatorUtils.signalAge(signalHistory);

    final currentMacd   = macdLine.last;
    final currentSignal = signalLine.last;
    final histogram     = currentMacd - currentSignal;

    // Cross detection on last two bars
    final prevMacd   = macdLine[macdLine.length - 2];
    final prevSig    = signalLine[signalLine.length - 2];
    final SignalType signal;
    if (prevMacd <= prevSig && currentMacd > currentSignal) {
      signal = SignalType.buy;
    } else if (prevMacd >= prevSig && currentMacd < currentSignal) {
      signal = SignalType.sell;
    } else {
      signal = currentMacd >= currentSignal ? SignalType.buy : SignalType.sell;
    }

    return MacdResult(
      macdLine: currentMacd,
      signalLine: currentSignal,
      histogram: histogram,
      signal: signal,
      signalAge: age,
    );
  }

  static bool matchesFilter(MacdResult result, MacdFilterParams params) {
    switch (params.signal) {
      case 'BUY':  return result.signal == SignalType.buy;
      case 'SELL': return result.signal == SignalType.sell;
      default:     return true;
    }
  }
}
