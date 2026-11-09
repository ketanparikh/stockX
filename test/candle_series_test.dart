import 'package:flutter_test/flutter_test.dart';
import 'package:stockx/models/candle_data.dart';
import 'package:stockx/utils/candle_series.dart';
import 'package:stockx/utils/constants.dart';
import 'package:stockx/utils/stock_symbols.dart';

List<CandleData> _barsEnding(DateTime last, {int count = 5, double close = 100}) {
  return [
    for (var i = count - 1; i >= 0; i--)
      CandleData(
        timestamp: last.subtract(Duration(days: i)),
        open: close,
        high: close,
        low: close,
        close: close + (count - 1 - i).toDouble(),
        volume: 1000,
      ),
  ];
}

void main() {
  test('daily last bar from today is current', () {
    final now = DateTime(2026, 8, 27, 20, 0);
    final candles = _barsEnding(DateTime(2026, 8, 27), close: 50);
    expect(CandleSeries.isCurrent(candles, Timeframe.daily, now: now), isTrue);
  });

  test('daily Friday close is still current on Monday', () {
    final now = DateTime(2026, 8, 31, 10, 0); // Monday
    final candles = _barsEnding(DateTime(2026, 8, 28), close: 50); // Friday
    expect(CandleSeries.isCurrent(candles, Timeframe.daily, now: now), isTrue);
  });

  test('daily last bar a week ago is stale', () {
    final now = DateTime(2026, 8, 27, 20, 0);
    final candles = _barsEnding(DateTime(2026, 8, 20), close: 50);
    expect(CandleSeries.isCurrent(candles, Timeframe.daily, now: now), isFalse);
  });

  test('weeksEndingOnLatest buckets 7 calendar days ending on latest session', () {
    CandleData bar(int y, int m, int d,
        {required double open,
        required double high,
        required double low,
        required double close,
        required double volume}) {
      return CandleData(
        timestamp: DateTime.utc(y, m, d),
        open: open,
        high: high,
        low: low,
        close: close,
        volume: volume,
      );
    }

    // Latest session = 9 Nov 2026. Week 0 is 3–9 Nov; week 1 is 27 Oct–2 Nov.
    final weeks = CandleSeries.weeksEndingOnLatest([
      bar(2026, 10, 27, open: 100, high: 110, low: 90, close: 105, volume: 1),
      bar(2026, 10, 28, open: 105, high: 120, low: 95, close: 108, volume: 2),
      bar(2026, 11, 2, open: 108, high: 109, low: 100, close: 101, volume: 3),
      bar(2026, 11, 3, open: 101, high: 130, low: 99, close: 125, volume: 4),
      bar(2026, 11, 6, open: 125, high: 140, low: 120, close: 130, volume: 5),
      bar(2026, 11, 9, open: 130, high: 135, low: 128, close: 132, volume: 6),
    ]);

    expect(weeks, hasLength(2));
    expect(weeks.last.timestamp, DateTime.utc(2026, 11, 9));
    expect(weeks.last.open, 101);
    expect(weeks.last.high, 140);
    expect(weeks.last.low, 99);
    expect(weeks.last.close, 132);
    expect(weeks.last.volume, 15);
    expect(weeks.first.timestamp, DateTime.utc(2026, 11, 2));
    expect(weeks.first.open, 100);
    expect(weeks.first.close, 101);
  });

  test('quote uses the latest candle close', () {
    final last = DateTime(2026, 8, 27);
    final candles = _barsEnding(last, close: 100);
    final q = CandleSeries.quoteFromCandles(
      const StockSymbol(
        symbol: 'TEST',
        name: 'Test',
        market: 'NSE',
        sector: 'Metals',
      ),
      candles,
    );
    expect(q.price, candles.last.close);
    expect(q.asOf, last);
  });
}
