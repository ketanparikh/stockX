import '../models/candle_data.dart';
import '../models/indicator_result.dart';
import '../models/screener_filter.dart';
import 'indicator_utils.dart';

/// Chandelier Exit (Alex Elder).
///
/// Standard formula:
///   Long Stop  = Highest High(period) − multiplier × ATR(period)
///   Short Stop = Lowest  Low (period) + multiplier × ATR(period)
///
/// ATR here is a SIMPLE average of True Range over [period] bars — this
/// matches the original definition and avoids Wilder lag distorting the exit.
///
/// Signal:
///   close > Long Stop  → BUY  (price is above the long exit, trend intact)
///   close < Short Stop → SELL (price is below the short exit, trend intact)
///   otherwise          → NEUTRAL
///
/// Note: A full state-machine version would track the prior state and only
/// signal when a level is crossed. For a screener "current status" view, the
/// stateless version below is standard practice.
class ChandelierExitIndicator {
  static ChandelierResult? calculate(
    List<CandleData> candles,
    ChandelierFilterParams params,
  ) {
    if (candles.length < params.period + 1) return null;

    // Simple ATR over the lookback window
    final atrList = IndicatorUtils.simpleAtr(candles, params.period);
    if (atrList.isEmpty) return null;

    final currentAtr = atrList.last;
    final currentClose = candles.last.close;

    // Highest high and lowest low over the last [period] candles
    final window = candles.sublist(candles.length - params.period);
    final highestHigh = window.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    final lowestLow  = window.map((c) => c.low ).reduce((a, b) => a < b ? a : b);

    final longStop  = highestHigh - params.multiplier * currentAtr;
    final shortStop = lowestLow   + params.multiplier * currentAtr;

    final SignalType signal;
    if (currentClose > longStop) {
      signal = SignalType.buy;
    } else if (currentClose < shortStop) {
      signal = SignalType.sell;
    } else {
      signal = SignalType.neutral;
    }

    return ChandelierResult(
      longStop: longStop,
      shortStop: shortStop,
      signal: signal,
    );
  }

  static bool matchesFilter(ChandelierResult result, ChandelierFilterParams params) {
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
