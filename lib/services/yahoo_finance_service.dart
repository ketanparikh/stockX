import 'package:dio/dio.dart';
import '../models/candle_data.dart';
import '../models/screener_result.dart';
import '../utils/constants.dart';
import '../utils/stock_symbols.dart';

class YahooFinanceException implements Exception {
  final String message;
  const YahooFinanceException(this.message);
  @override
  String toString() => 'YahooFinanceException: $message';
}

class YahooFinanceService {
  late final Dio _dio;

  YahooFinanceService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.yahooFinanceBaseUrl,
      connectTimeout: AppConstants.requestTimeout,
      receiveTimeout: AppConstants.requestTimeout,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Origin': 'https://finance.yahoo.com',
        'Referer': 'https://finance.yahoo.com/',
      },
    ));
  }

  Future<List<CandleData>> fetchCandles(
    String yahooSymbol,
    String interval, {
    String range = '1y',
  }) async {
    try {
      final response = await _dio.get(
        '${AppConstants.yahooFinanceChartPath}/$yahooSymbol',
        queryParameters: {
          'interval': interval,
          'range': range,
          'includePrePost': false,
        },
      );

      final body = response.data;
      final chart = body['chart'];
      if (chart == null) throw const YahooFinanceException('No chart data');

      final result = chart['result'];
      if (result == null || (result as List).isEmpty) {
        throw const YahooFinanceException('No result data');
      }

      final data = result[0];
      final timestamps = List<int>.from(data['timestamp'] ?? []);
      final quote = data['indicators']['quote'][0];
      final opens = _toDoubleList(quote['open']);
      final highs = _toDoubleList(quote['high']);
      final lows = _toDoubleList(quote['low']);
      final closes = _toDoubleList(quote['close']);
      final volumes = _toDoubleList(quote['volume']);

      if (timestamps.isEmpty) throw const YahooFinanceException('Empty data');

      final candles = <CandleData>[];
      for (int i = 0; i < timestamps.length; i++) {
        if (opens[i] == null || highs[i] == null || lows[i] == null || closes[i] == null) {
          continue;
        }
        candles.add(CandleData(
          timestamp: DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000),
          open: opens[i]!,
          high: highs[i]!,
          low: lows[i]!,
          close: closes[i]!,
          volume: volumes[i] ?? 0,
        ));
      }

      return candles;
    } on DioException catch (e) {
      throw YahooFinanceException('Network error: ${e.message}');
    }
  }

  Future<StockQuote> fetchQuote(StockSymbol stock) async {
    final yahooSymbol = stock.yahooSymbol;
    try {
      final response = await _dio.get(
        AppConstants.yahooFinanceQuotePath,
        queryParameters: {
          'symbols': yahooSymbol,
          'fields':
              'regularMarketPrice,regularMarketChange,regularMarketChangePercent,regularMarketVolume,marketCap,fiftyTwoWeekHigh,fiftyTwoWeekLow,shortName,longName',
        },
      );

      final quoteResponse = response.data['quoteResponse'];
      if (quoteResponse == null) throw const YahooFinanceException('No quote response');

      final results = quoteResponse['result'];
      if (results == null || (results as List).isEmpty) {
        throw YahooFinanceException('No quote for $yahooSymbol');
      }

      final q = results[0];
      return StockQuote(
        symbol: stock.symbol,
        name: q['shortName'] ?? q['longName'] ?? stock.name,
        market: stock.market,
        sector: stock.sector,
        price: (q['regularMarketPrice'] ?? 0).toDouble(),
        change: (q['regularMarketChange'] ?? 0).toDouble(),
        changePercent: (q['regularMarketChangePercent'] ?? 0).toDouble(),
        volume: (q['regularMarketVolume'] ?? 0).toDouble(),
        marketCap: q['marketCap']?.toDouble(),
        week52High: q['fiftyTwoWeekHigh']?.toDouble(),
        week52Low: q['fiftyTwoWeekLow']?.toDouble(),
      );
    } on DioException catch (_) {
      // Return a basic quote with just symbol info on error
      return StockQuote(
        symbol: stock.symbol,
        name: stock.name,
        market: stock.market,
        sector: stock.sector,
        price: 0,
        change: 0,
        changePercent: 0,
        volume: 0,
      );
    }
  }

  Future<Map<String, StockQuote>> fetchBatchQuotes(
    List<StockSymbol> stocks,
  ) async {
    if (stocks.isEmpty) return {};

    final symbols = stocks.map((s) => s.yahooSymbol).join(',');
    try {
      final response = await _dio.get(
        AppConstants.yahooFinanceQuotePath,
        queryParameters: {
          'symbols': symbols,
          'fields':
              'regularMarketPrice,regularMarketChange,regularMarketChangePercent,regularMarketVolume,marketCap,fiftyTwoWeekHigh,fiftyTwoWeekLow,shortName,symbol',
        },
      );

      final quoteResponse = response.data['quoteResponse'];
      if (quoteResponse == null) return {};

      final results = quoteResponse['result'] as List? ?? [];
      final map = <String, StockQuote>{};

      for (final q in results) {
        final yahooSym = q['symbol'] as String? ?? '';
        // Find matching StockSymbol
        StockSymbol? stock;
        try {
          stock = stocks.firstWhere((s) => s.yahooSymbol == yahooSym);
        } catch (_) {}

        if (stock == null) continue;

        map[stock.symbol] = StockQuote(
          symbol: stock.symbol,
          name: q['shortName'] ?? stock.name,
          market: stock.market,
          sector: stock.sector,
          price: (q['regularMarketPrice'] ?? 0).toDouble(),
          change: (q['regularMarketChange'] ?? 0).toDouble(),
          changePercent: (q['regularMarketChangePercent'] ?? 0).toDouble(),
          volume: (q['regularMarketVolume'] ?? 0).toDouble(),
          marketCap: q['marketCap']?.toDouble(),
          week52High: q['fiftyTwoWeekHigh']?.toDouble(),
          week52Low: q['fiftyTwoWeekLow']?.toDouble(),
        );
      }

      return map;
    } on DioException catch (e) {
      throw YahooFinanceException('Batch quote error: ${e.message}');
    }
  }

  List<double?> _toDoubleList(dynamic list) {
    if (list == null) return [];
    return (list as List).map<double?>((v) => v == null ? null : (v as num).toDouble()).toList();
  }
}
