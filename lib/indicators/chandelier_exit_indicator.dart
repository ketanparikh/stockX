import 'dart:math' as math;

import '../models/candle_data.dart';
import '../models/indicator_result.dart';
import '../models/screener_filter.dart';
import 'indicator_utils.dart';

/// Chandelier Exit — matches `calculate_ce_signals()` in Screener/new_combined_strategy.py.
///
///   • ATR: Pine RMA on true range (same index as each candle)
///   • Stops: rolling max/min of **close** over the ATR period (not high/low)
///   • Trailing: long stop ratchets up, short stop ratchets down
///   • Direction: BUY when close > prev short stop; SELL when close < prev long stop
///   • Period: 14 when fewer than 100 bars, else filter period (default 22)
class ChandelierExitIndicator {
  static const int _kHistoryLen = 50;
  static const int _kShortDataPeriod = 14;
  static const int _kMinBarsForDefaultPeriod = 100;

  static ChandelierResult? calculate(
    List<CandleData> candles,
    ChandelierFilterParams params,
  ) {
    final n = candles.length;
    final period = n < _kMinBarsForDefaultPeriod
        ? _kShortDataPeriod
        : params.period;
    final multiplier = params.multiplier;

    if (n < period + 2) return null;

    final tr = IndicatorUtils.trueRangeFull(candles);
    final atr = IndicatorUtils.pineRmaSeries(tr, period);

    final rawLongStop = List<double?>.filled(n, null);
    final rawShortStop = List<double?>.filled(n, null);

    for (var i = period - 1; i < n; i++) {
      final atrValue = atr[i];
      if (atrValue == null) continue;

      final windowStart = i - period + 1;
      var highestClose = candles[windowStart].close;
      var lowestClose = candles[windowStart].close;
      for (var j = windowStart + 1; j <= i; j++) {
        highestClose = math.max(highestClose, candles[j].close);
        lowestClose = math.min(lowestClose, candles[j].close);
      }

      rawLongStop[i] = highestClose - multiplier * atrValue;
      rawShortStop[i] = lowestClose + multiplier * atrValue;
    }

    final trailLong = List<double?>.filled(n, null);
    final trailShort = List<double?>.filled(n, null);
    final dirList = <int>[1]; // uptrend default — matches Screener

    trailLong[0] = rawLongStop[0];
    trailShort[0] = rawShortStop[0];

    for (var i = 1; i < n; i++) {
      final prevClose = candles[i - 1].close;
      final prevLong = trailLong[i - 1];
      final prevShort = trailShort[i - 1];
      final rawLong = rawLongStop[i];
      final rawShort = rawShortStop[i];

      if (prevLong != null && rawLong != null) {
        trailLong[i] = prevClose > prevLong
            ? math.max(rawLong, prevLong)
            : rawLong;
      } else {
        trailLong[i] = rawLong ?? prevLong;
      }

      if (prevShort != null && rawShort != null) {
        trailShort[i] = prevClose < prevShort
            ? math.min(rawShort, prevShort)
            : rawShort;
      } else {
        trailShort[i] = rawShort ?? prevShort;
      }

      final close = candles[i].close;
      final prevDir = dirList.last;
      final priorShort = trailShort[i - 1];
      final priorLong = trailLong[i - 1];

      if (priorShort != null && close > priorShort) {
        dirList.add(1);
      } else if (priorLong != null && close < priorLong) {
        dirList.add(-1);
      } else {
        dirList.add(prevDir);
      }
    }

    final histStart =
        dirList.length > _kHistoryLen ? dirList.length - _kHistoryLen : 0;
    final signalHistory = dirList.sublist(histStart).map((d) {
      if (d == 1) return SignalType.buy;
      if (d == -1) return SignalType.sell;
      return SignalType.neutral;
    }).toList();

    if (signalHistory.isEmpty) return null;

    final currentDir = dirList.last;
    final currentSignal = currentDir == 1
        ? SignalType.buy
        : currentDir == -1
            ? SignalType.sell
            : SignalType.neutral;

    final age = IndicatorUtils.signalAge(
      signalHistory,
      maxLookback: signalHistory.length,
    );

    return ChandelierResult(
      longStop: trailLong.last ?? 0,
      shortStop: trailShort.last ?? 0,
      signal: currentSignal,
      signalAge: age,
    );
  }

  static bool matchesFilter(
    ChandelierResult result,
    ChandelierFilterParams params,
  ) {
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
