import '../models/candle_data.dart';
import '../services/cache_service.dart';

/// Latest close from cached daily (or weekly) candles.
double? watchlistCurrentPrice(String symbol, CacheService cache) {
  final List<CandleData>? candles =
      cache.get(symbol, 'daily') ?? cache.get(symbol, 'weekly');
  if (candles == null || candles.isEmpty) return null;
  return candles.last.close;
}
