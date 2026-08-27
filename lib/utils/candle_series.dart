import '../models/candle_data.dart';
import '../models/screener_result.dart';
import 'constants.dart';
import 'stock_symbols.dart';

/// Last-bar recency and quote built from the latest candle (not a stale cache).
class CandleSeries {
  CandleSeries._();

  static List<CandleData> sorted(List<CandleData> candles) {
    if (candles.length < 2) return candles;
    var ordered = true;
    for (var i = 1; i < candles.length; i++) {
      if (candles[i].timestamp.isBefore(candles[i - 1].timestamp)) {
        ordered = false;
        break;
      }
    }
    if (ordered) return candles;
    final copy = List<CandleData>.from(candles)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return copy;
  }

  /// True when the last candle is from the latest market session (with slack
  /// for weekends / holidays). Fresh-signal age is measured from this bar.
  static bool isCurrent(
    List<CandleData> candles,
    String timeframe, {
    DateTime? now,
  }) {
    if (candles.length < 2) return false;
    final last = candles.last.timestamp;
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final lastDay = DateTime(last.year, last.month, last.day);
    final lag = today.difference(lastDay).inDays;
    if (lag < 0) return true;
    switch (timeframe) {
      case Timeframe.weekly:
        return lag <= 10;
      case Timeframe.monthly:
        return lag <= 40;
      default:
        // Daily: Friday close is still current on Monday (lag 3); +1 for a holiday.
        return lag <= 4;
    }
  }

  static StockQuote quoteFromCandles(StockSymbol stock, List<CandleData> candles) {
    final last = candles.last;
    final prev = candles[candles.length - 2];
    final change = last.close - prev.close;
    final changePct = prev.close != 0 ? (change / prev.close) * 100 : 0.0;

    var week52High = candles.first.high;
    var week52Low = candles.first.low;
    for (final c in candles) {
      if (c.high > week52High) week52High = c.high;
      if (c.low < week52Low) week52Low = c.low;
    }

    return StockQuote(
      symbol: stock.symbol,
      name: stock.name,
      market: stock.market,
      sector: stock.sector,
      price: last.close,
      change: change,
      changePercent: changePct,
      volume: last.volume,
      week52High: week52High,
      week52Low: week52Low,
      asOf: last.timestamp,
    );
  }
}
