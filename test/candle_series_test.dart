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
