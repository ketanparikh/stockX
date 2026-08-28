import 'package:flutter_test/flutter_test.dart';
import 'package:stockx/indicators/approaching_ema200_indicator.dart';
import 'package:stockx/indicators/ema_10_cross_indicator.dart';
import 'package:stockx/indicators/indicator_utils.dart';
import 'package:stockx/models/candle_data.dart';
import 'package:stockx/models/indicator_result.dart';
import 'package:stockx/models/screener_filter.dart';

List<CandleData> _candles(List<double> closes, {double volume = 1e6}) {
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

const _watchOnly = ApproachingEma200FilterParams(
  skipIlliquid: false,
  skipClimaxVolume: false,
  skipDefensive: false,
  crossLookback: 5,
  maxPctBelow: 8,
  minEma200SlopePct: -2,
);

/// Seed EMAs at 100, grind down, base, then bounce so 10 recrosses 30/48
/// while close is still a few percent under EMA 200.
List<double> _approachCloses() {
  final closes = <double>[];
  for (var i = 0; i < 220; i++) {
    closes.add(100);
  }
  for (var i = 1; i <= 50; i++) {
    closes.add(100 - i * 0.12); // down to 94
  }
  for (var i = 0; i < 30; i++) {
    closes.add(94); // base — 200 flattens, 10/30/48 sit under it
  }
  // Bounce: 10 crosses back through 30/48 without reclaiming 200.
  const bounce = [94.8, 95.6, 96.4, 97.0, 97.2];
  closes.addAll(bounce);
  return closes;
}

void main() {
  test('returns null when there are fewer than 221 bars', () {
    final result = ApproachingEma200Indicator.calculate(
      _candles(List<double>.filled(200, 100)),
      _watchOnly,
    );
    expect(result, isNull);
  });

  test('flat market is not a watchlist flag', () {
    final result = ApproachingEma200Indicator.calculate(
      _candles(List<double>.filled(260, 100)),
      _watchOnly,
    );
    expect(result, isNotNull);
    expect(result!.watchlistActive, isFalse);
    expect(result.signal, SignalType.neutral);
  });

  test('10/30/48 recross under flattening 200 flags WATCH', () {
    final closes = _approachCloses();
    final candles = _candles(closes);
    final result = ApproachingEma200Indicator.calculate(candles, _watchOnly);
    expect(result, isNotNull, reason: 'need 221+ bars');

    final ema = IndicatorUtils.emaAligned(closes, 200);
    final e200 = ema.last!;
    final close = closes.last;
    expect(close < e200, isTrue, reason: 'still below 200 ($close vs $e200)');
    final pctBelow = (e200 - close) / e200 * 100;
    expect(pctBelow, lessThanOrEqualTo(8), reason: '$pctBelow% below');
    expect(pctBelow, greaterThan(0));

    expect(result!.signal, SignalType.watch);
    expect(result.watchlistActive, isTrue);
    expect(result.pctBelow200, greaterThan(0));
    expect(result.pctBelow200, lessThanOrEqualTo(8));
    expect(result.ema200SlopePct, greaterThanOrEqualTo(-2));
    expect(
      ApproachingEma200Indicator.matchesFilter(result, _watchOnly),
      isTrue,
    );
  });

  test('close already above EMA 200 is not WATCH (that is EMA 10 Cross BUY)', () {
    final closes = _approachCloses();
    // Lift the last bars through 200 so this becomes a reclaim, not a watch.
    for (var i = closes.length - 5; i < closes.length; i++) {
      closes[i] = 110;
    }
    final result = ApproachingEma200Indicator.calculate(
      _candles(closes),
      _watchOnly,
    );
    expect(result, isNotNull);
    expect(result!.watchlistActive, isFalse);
    expect(result.signal, SignalType.neutral);
  });

  test('deep discount under 200 is not WATCH', () {
    final closes = <double>[];
    for (var i = 0; i < 220; i++) {
      closes.add(100);
    }
    for (var i = 1; i <= 80; i++) {
      closes.add(100 - i * 0.45); // down to 64
    }
    for (var i = 0; i < 20; i++) {
      closes.add(64);
    }
    closes.addAll([65.5, 67.0, 68.5, 69.5, 70.0]);
    final result = ApproachingEma200Indicator.calculate(
      _candles(closes),
      _watchOnly,
    );
    expect(result, isNotNull);
    expect(result!.watchlistActive, isFalse);
    expect(result.pctBelow200, greaterThan(8));
  });

  test('steeply falling EMA 200 is not WATCH', () {
    final result = ApproachingEma200Indicator.calculate(
      _candles(_approachCloses()),
      _watchOnly.copyWith(minEma200SlopePct: 0),
    );
    // After a 50-bar grind down, 20-bar 200 slope is still slightly negative.
    // Requiring flat-or-rising should reject unless 200 has already turned.
    if (result != null && result.ema200SlopePct < 0) {
      expect(result.watchlistActive, isFalse);
    }
  });

  test('illiquid names are skipped', () {
    final result = ApproachingEma200Indicator.calculate(
      _candles(_approachCloses(), volume: 1),
      const ApproachingEma200FilterParams(
        skipIlliquid: true,
        skipClimaxVolume: false,
        skipDefensive: false,
        minAdvInr: 1e6,
      ),
    );
    expect(result, isNotNull);
    expect(result!.watchlistActive, isFalse);
    expect(result.skipReason, isNotNull);
    expect(result.skipReason!, contains('illiquid'));
  });

  test('WATCH and EMA 10 Cross BUY are mutually exclusive on the same bar', () {
    final candles = _candles(_approachCloses());
    final watch = ApproachingEma200Indicator.calculate(candles, _watchOnly);
    final buy = Ema10CrossIndicator.calculate(
      candles,
      const Ema10CrossFilterParams(
        requireSupertrend: false,
        skipIlliquid: false,
        skipClimaxVolume: false,
        skipDefensive: false,
      ),
    );
    expect(watch!.watchlistActive, isTrue);
    expect(buy!.setupActive, isFalse);
  });
}
