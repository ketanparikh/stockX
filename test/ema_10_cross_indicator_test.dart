import 'package:flutter_test/flutter_test.dart';
import 'package:stockx/indicators/ema_10_cross_indicator.dart';
import 'package:stockx/indicators/indicator_utils.dart';
import 'package:stockx/models/candle_data.dart';
import 'package:stockx/models/indicator_result.dart';
import 'package:stockx/models/screener_filter.dart';

List<CandleData> _candles(List<double> closes, {double volume = 1000}) {
  return [
    for (var i = 0; i < closes.length; i++)
      CandleData(
        timestamp: DateTime(2024, 1, 1).add(Duration(days: i)),
        open: closes[i],
        high: closes[i],
        low: closes[i],
        close: closes[i],
        volume: volume,
      ),
  ];
}

/// Tape gates off so price-path tests isolate the EMA stack.
const _stackOnly = Ema10CrossFilterParams(
  requireSupertrend: false,
  skipIlliquid: false,
  skipClimaxVolume: false,
  skipDefensive: false,
  crossLookback: 5,
);

/// Base at 50, grind up, pull back under 10/30 & 10/48, then recross.
List<double> _pullbackRecrossCloses({int extraHoldBars = 0}) {
  final closes = <double>[];
  for (var i = 0; i < 220; i++) {
    closes.add(50);
  }
  for (var i = 1; i <= 80; i++) {
    closes.add(50 + i * 1.4); // 51.4 .. 162
  }
  for (var i = 1; i <= 18; i++) {
    closes.add(162 - i * 3.2); // down to ~104.4
  }
  for (var i = 1; i <= 4; i++) {
    closes.add(104.4 + i * 8); // bounce to 136.4 — 10 recrosses 30/48
  }
  for (var i = 0; i < extraHoldBars; i++) {
    closes.add(136.4 + i * 0.2);
  }
  return closes;
}

List<double> _exitDumpCloses({required int dumpBars}) {
  final closes = _pullbackRecrossCloses(extraHoldBars: 6);
  final last = closes.last;
  for (var i = 1; i <= dumpBars; i++) {
    closes.add(last - i * 6);
  }
  return closes;
}

void main() {
  test('returns null when there are fewer than 201 bars', () {
    final closes = List<double>.filled(100, 100);
    final result = Ema10CrossIndicator.calculate(
      _candles(closes),
      _stackOnly,
    );
    expect(result, isNull);
  });

  test('flat market does not fire the setup', () {
    final result = Ema10CrossIndicator.calculate(
      _candles(List<double>.filled(260, 100)),
      _stackOnly,
    );
    expect(result, isNotNull);
    expect(result!.setupActive, isFalse);
    expect(result.signal, SignalType.neutral);
    expect(
      Ema10CrossIndicator.matchesFilter(
        result,
        const Ema10CrossFilterParams(requireSupertrend: false, signal: 'BUY'),
      ),
      isFalse,
    );
  });

  test('downtrend below EMA 200 does not fire', () {
    final closes = <double>[];
    for (var i = 0; i < 260; i++) {
      closes.add(200 - i * 0.4);
    }
    final result = Ema10CrossIndicator.calculate(
      _candles(closes),
      _stackOnly,
    );
    expect(result, isNotNull);
    expect(result!.setupActive, isFalse);
    expect(result.ema10 < result.ema200, isTrue);
  });

  test('uptrend pullback then 10 recross of 30 and 48 fires BUY', () {
    final closes = _pullbackRecrossCloses(extraHoldBars: 6);
    final result = Ema10CrossIndicator.calculate(
      _candles(closes),
      _stackOnly,
    );
    expect(result, isNotNull, reason: 'need 201+ bars');
    final close = closes.last;
    expect(close > result!.ema10, isTrue, reason: 'close > EMA10');
    expect(close > result.ema200, isTrue, reason: 'close > EMA200');
    expect(result.ema10 > result.ema30, isTrue, reason: 'EMA10 > EMA30');
    expect(result.ema10 > result.ema48, isTrue, reason: 'EMA10 > EMA48');
    expect(result.setupActive, isTrue);
    expect(result.signal, SignalType.buy);
    expect(result.cross30Age <= 5 || result.cross48Age <= 5, isTrue);
    final completing =
        result.cross30Age < result.cross48Age ? result.cross30Age : result.cross48Age;
    expect(result.signalAge, completing,
        reason: 'fresh-signal age is the completing 10/30 or 10/48 cross');
    expect(
      Ema10CrossIndicator.matchesFilter(
        result,
        const Ema10CrossFilterParams(requireSupertrend: false, signal: 'BUY'),
      ),
      isTrue,
    );
  });

  test('stale 10/30/48 alignment does not fire with lookback 5', () {
    final closes = _pullbackRecrossCloses(extraHoldBars: 20);
    final fresh = Ema10CrossIndicator.calculate(
      _candles(closes),
      _stackOnly,
    );
    final loose = Ema10CrossIndicator.calculate(
      _candles(closes),
      const Ema10CrossFilterParams(
        requireSupertrend: false,
        skipIlliquid: false,
        skipClimaxVolume: false,
        skipDefensive: false,
        crossLookback: 50,
      ),
    );
    expect(loose, isNotNull);
    expect(loose!.ema10 > loose.ema30, isTrue);
    expect(loose.ema10 > loose.ema48, isTrue);
    expect(fresh!.setupActive, isFalse,
        reason: 'completing cross should be older than 5 bars');
    expect(loose.setupActive, isTrue,
        reason: 'wide lookback should still see the completed stack');
  });

  test('emaAligned indexes match IndicatorUtils.ema', () {
    final values = [for (var i = 1; i <= 30; i++) i.toDouble()];
    final raw = IndicatorUtils.ema(values, 10);
    final aligned = IndicatorUtils.emaAligned(values, 10);
    expect(aligned[8], isNull);
    expect(aligned[9], raw.first);
    expect(aligned.last, raw.last);
  });

  test('EMA 10 dropping below 30 and 48 fires SELL', () {
    final result = Ema10CrossIndicator.calculate(
      _candles(_exitDumpCloses(dumpBars: 4)),
      _stackOnly,
    );
    expect(result, isNotNull);
    expect(result!.ema10 < result.ema30, isTrue);
    expect(result.ema10 < result.ema48, isTrue);
    expect(result.exitActive, isTrue);
    expect(result.setupActive, isFalse);
    expect(result.signal, SignalType.sell);
    expect(result.cross30Age <= 5, isTrue);
    expect(result.cross48Age <= 5, isTrue);
    expect(
      Ema10CrossIndicator.matchesFilter(
        result,
        const Ema10CrossFilterParams(requireSupertrend: false, signal: 'SELL'),
      ),
      isTrue,
    );
    expect(
      Ema10CrossIndicator.matchesFilter(
        result,
        const Ema10CrossFilterParams(requireSupertrend: false, signal: 'BUY'),
      ),
      isFalse,
    );
  });

  test('stale 10-below-30/48 does not fire SELL with lookback 5', () {
    final closes = _exitDumpCloses(dumpBars: 15);
    final fresh = Ema10CrossIndicator.calculate(
      _candles(closes),
      _stackOnly,
    );
    final loose = Ema10CrossIndicator.calculate(
      _candles(closes),
      const Ema10CrossFilterParams(
        requireSupertrend: false,
        skipIlliquid: false,
        skipClimaxVolume: false,
        skipDefensive: false,
        crossLookback: 50,
      ),
    );
    expect(fresh!.ema10 < fresh.ema30, isTrue);
    expect(fresh.ema10 < fresh.ema48, isTrue);
    expect(fresh.exitActive, isFalse);
    expect(loose!.exitActive, isTrue);
    expect(loose.signal, SignalType.sell);
  });

  test('illiquid 20D ADV skips BUY', () {
    final result = Ema10CrossIndicator.calculate(
      _candles(_pullbackRecrossCloses(extraHoldBars: 6), volume: 1000),
      const Ema10CrossFilterParams(
        requireSupertrend: false,
        skipClimaxVolume: false,
        skipDefensive: false,
      ),
    );
    expect(result!.setupActive, isFalse);
    expect(result.signal, SignalType.neutral);
    expect(result.skipReason, contains('illiquid'));
  });

  test('liquid ADV still fires BUY with climax and illiquid gates on', () {
    final result = Ema10CrossIndicator.calculate(
      _candles(_pullbackRecrossCloses(extraHoldBars: 6), volume: 20000000),
      const Ema10CrossFilterParams(
        requireSupertrend: false,
        skipDefensive: false,
      ),
    );
    expect(result!.setupActive, isTrue);
    expect(result.signal, SignalType.buy);
    expect(result.skipReason, isNull);
  });

  test('climax volume skips BUY', () {
    final closes = _pullbackRecrossCloses(extraHoldBars: 6);
    final candles = _candles(closes, volume: 1000000);
    final spiked = [
      for (var i = 0; i < candles.length; i++)
        if (i >= candles.length - 8)
          CandleData(
            timestamp: candles[i].timestamp,
            open: candles[i].open,
            high: candles[i].high,
            low: candles[i].low,
            close: candles[i].close,
            volume: 5000000,
          )
        else
          candles[i],
    ];
    final result = Ema10CrossIndicator.calculate(
      spiked,
      const Ema10CrossFilterParams(
        requireSupertrend: false,
        skipIlliquid: false,
        skipDefensive: false,
      ),
    );
    expect(result!.setupActive, isFalse);
    expect(result.skipReason, contains('climax'));
  });

  test('defensive symbol skips BUY', () {
    final result = Ema10CrossIndicator.calculate(
      _candles(_pullbackRecrossCloses(extraHoldBars: 6), volume: 20000000),
      const Ema10CrossFilterParams(
        requireSupertrend: false,
        skipIlliquid: false,
        skipClimaxVolume: false,
      ),
      symbol: 'HDFCLIFE',
    );
    expect(result!.setupActive, isFalse);
    expect(result.skipReason, contains('defensive'));
  });

  test('SELL still fires when the name is illiquid', () {
    final result = Ema10CrossIndicator.calculate(
      _candles(_exitDumpCloses(dumpBars: 4), volume: 1000),
      const Ema10CrossFilterParams(requireSupertrend: false),
    );
    expect(result!.exitActive, isTrue);
    expect(result.signal, SignalType.sell);
  });
}
