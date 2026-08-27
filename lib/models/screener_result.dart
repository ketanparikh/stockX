import 'candle_data.dart';
import 'indicator_result.dart';

class StockQuote {
  final String symbol;
  final String name;
  final String market;
  final String sector;
  final double price;
  final double change;
  final double changePercent;
  final double volume;
  final double? marketCap;
  final double? week52High;
  final double? week52Low;

  /// Timestamp of the last candle used for [price].
  final DateTime? asOf;

  const StockQuote({
    required this.symbol,
    required this.name,
    required this.market,
    required this.sector,
    required this.price,
    required this.change,
    required this.changePercent,
    required this.volume,
    this.marketCap,
    this.week52High,
    this.week52Low,
    this.asOf,
  });

  bool get isPositive => change >= 0;
}

class ScreenerResult {
  final StockQuote quote;
  final List<CandleData> candles;
  final List<IndicatorResult> indicators;
  final int matchingFilters;
  final int totalFilters;

  const ScreenerResult({
    required this.quote,
    required this.candles,
    required this.indicators,
    required this.matchingFilters,
    required this.totalFilters,
  });

  bool get allFiltersMatch => matchingFilters == totalFilters;
  double get matchScore => totalFilters > 0 ? matchingFilters / totalFilters : 0;

  IndicatorResult? getIndicator(String name) {
    try {
      return indicators.firstWhere((i) => i.name == name);
    } catch (_) {
      return null;
    }
  }
}
