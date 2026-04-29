import '../models/candle_data.dart';
import '../models/indicator_result.dart';
import '../models/screener_filter.dart';
import 'indicator_utils.dart';

class ChandelierExitIndicator {
  static const int _kHistoryLen = 50;

  static ChandelierResult? calculate(
    List<CandleData> candles,
    ChandelierFilterParams params,
  ) {
    if (candles.length < params.period + 1) return null;

    final atrList = IndicatorUtils.simpleAtr(candles, params.period);
    if (atrList.isEmpty) return null;

    // Build signal series for the last _kHistoryLen bars
    final signalHistory = <SignalType>[];
    final histStart = atrList.length > _kHistoryLen
        ? atrList.length - _kHistoryLen
        : 0;

    // atrList[k] corresponds to candles[period + k]
    for (int k = histStart; k < atrList.length; k++) {
      final barIdx = params.period + k; // candle index
      if (barIdx >= candles.length) break;

      final atr = atrList[k];
      final close = candles[barIdx].close;

      // Window for highest high / lowest low: [barIdx-period+1 .. barIdx]
      final winStart = (barIdx - params.period + 1).clamp(0, candles.length - 1);
      final window = candles.sublist(winStart, barIdx + 1);
      final highestHigh = window.map((c) => c.high).reduce((a, b) => a > b ? a : b);
      final lowestLow   = window.map((c) => c.low ).reduce((a, b) => a < b ? a : b);

      final longStop  = highestHigh - params.multiplier * atr;
      final shortStop = lowestLow   + params.multiplier * atr;

      if (close > longStop) {
        signalHistory.add(SignalType.buy);
      } else if (close < shortStop) {
        signalHistory.add(SignalType.sell);
      } else {
        signalHistory.add(SignalType.neutral);
      }
    }

    if (signalHistory.isEmpty) return null;

    final age = IndicatorUtils.signalAge(signalHistory);
    final currentSignal = signalHistory.last;

    // For the result values use the last bar's stops
    final lastAtr = atrList.last;
    final lastBar = candles.length - 1;
    final winStart = (lastBar - params.period + 1).clamp(0, candles.length - 1);
    final lastWindow = candles.sublist(winStart);
    final hh = lastWindow.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    final ll = lastWindow.map((c) => c.low ).reduce((a, b) => a < b ? a : b);

    return ChandelierResult(
      longStop:  hh - params.multiplier * lastAtr,
      shortStop: ll + params.multiplier * lastAtr,
      signal: currentSignal,
      signalAge: age,
    );
  }

  static bool matchesFilter(ChandelierResult result, ChandelierFilterParams params) {
    switch (params.signal) {
      case 'BUY':     return result.signal == SignalType.buy;
      case 'SELL':    return result.signal == SignalType.sell;
      case 'NEUTRAL': return result.signal == SignalType.neutral;
      default:        return true;
    }
  }
}
