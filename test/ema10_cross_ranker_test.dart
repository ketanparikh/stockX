import 'package:flutter_test/flutter_test.dart';
import 'package:stockx/models/candle_data.dart';
import 'package:stockx/models/indicator_result.dart';
import 'package:stockx/models/screener_result.dart';
import 'package:stockx/utils/ema10_cross_ranker.dart';

ScreenerResult _row({
  required String symbol,
  required double vs200,
  SignalType signal = SignalType.buy,
}) {
  return ScreenerResult(
    quote: StockQuote(
      symbol: symbol,
      name: symbol,
      market: 'NSE',
      sector: 'Test',
      price: 400,
      change: 0,
      changePercent: 0,
      volume: 1,
    ),
    candles: [
      CandleData(
        timestamp: DateTime(2026, 1, 1),
        open: 400,
        high: 400,
        low: 400,
        close: 400,
        volume: 1,
      ),
    ],
    indicators: [
      Ema10CrossResult(
        ema10: 390,
        ema30: 380,
        ema48: 370,
        ema200: 350,
        cross30Age: 1,
        cross48Age: 1,
        setupActive: signal == SignalType.buy,
        pctAbove200: vs200,
        signal: signal,
      ),
    ],
    matchingFilters: 1,
    totalFilters: 1,
  );
}

void main() {
  test('ranks BUY names farthest above EMA 200 first and badges top 5', () {
    final rows = [
      _row(symbol: 'A', vs200: 4),
      _row(symbol: 'B', vs200: 22),
      _row(symbol: 'C', vs200: 9),
      _row(symbol: 'D', vs200: 31),
      _row(symbol: 'E', vs200: 12),
      _row(symbol: 'F', vs200: 7),
      _row(symbol: 'G', vs200: 18),
    ];
    final ranked = Ema10CrossRanker.rank(rows, enabled: true, topN: 5);
    expect(ranked.map((r) => r.quote.symbol).toList(), ['D', 'B', 'G', 'E', 'C', 'F', 'A']);
    expect(ranked.take(5).map((r) => r.priorityRank).toList(), [1, 2, 3, 4, 5]);
    expect(ranked[5].priorityRank, isNull);
    expect(ranked[6].priorityRank, isNull);
  });

  test('leaves order unchanged when EMA 10 Cross ranking is off', () {
    final rows = [
      _row(symbol: 'A', vs200: 4),
      _row(symbol: 'B', vs200: 22),
    ];
    final ranked = Ema10CrossRanker.rank(rows, enabled: false, topN: 5);
    expect(ranked.map((r) => r.quote.symbol).toList(), ['A', 'B']);
    expect(ranked.every((r) => r.priorityRank == null), isTrue);
  });

  test('SELL rows stay below BUY rows', () {
    final rows = [
      _row(symbol: 'SELL1', vs200: 50, signal: SignalType.sell),
      _row(symbol: 'BUY1', vs200: 8),
      _row(symbol: 'BUY2', vs200: 20),
    ];
    final ranked = Ema10CrossRanker.rank(rows, enabled: true, topN: 5);
    expect(ranked.map((r) => r.quote.symbol).toList(), ['BUY2', 'BUY1', 'SELL1']);
    expect(ranked[0].priorityRank, 1);
    expect(ranked[1].priorityRank, 2);
    expect(ranked.last.priorityRank, isNull);
  });
}
