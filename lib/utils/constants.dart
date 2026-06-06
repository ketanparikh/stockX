class AppConstants {
  static const String appName = 'StockX Screener';
  static const String yahooFinanceBaseUrl = 'https://query1.finance.yahoo.com';
  static const String yahooFinanceChartPath = '/v8/finance/chart';
  static const String yahooFinanceQuotePath = '/v7/finance/quote';

  static const Duration requestTimeout = Duration(seconds: 15);
  static const int defaultRsiPeriod = 25;
  static const int defaultRsiSlowPeriod = 100;
  static const int defaultEmaPeriod = 20;
  static const int defaultMacdFastPeriod = 12;
  static const int defaultMacdSlowPeriod = 26;
  static const int defaultMacdSignalPeriod = 9;
  static const int defaultSupertrendPeriod = 22;
  static const double defaultSupertrendMultiplier = 3.0;
  static const int defaultChandelierPeriod = 22;
  static const double defaultChandelierMultiplier = 3.0;
  static const int defaultAtrPeriod = 22;
  static const int defaultMaxResults = 100;
  static const int defaultBollingerPeriod = 20;
  static const double defaultBollingerStdDev = 2.0;
  static const int defaultAdxPeriod = 14;

  // Sethi breakout strategy (matches nse_full_market_backtest.py entry rules)
  static const int defaultSethiHighLookback = 20;
  static const int defaultSethiDmaFast = 50;
  static const int defaultSethiDmaSlow = 200;
  static const int defaultSethiVolumeLookback = 20;
  static const double defaultSethiVolumeMultiplier = 1.5;
  static const int defaultSethiRsiPeriod = 14;
  static const double defaultSethiRsiMin = 60.0;
  static const double defaultSethiRsiMax = 80.0;
  static const double defaultSethiMinPrice = 50.0;
  static const double defaultSethiMinAvgValue = 10000000.0; // INR 1 crore

  static const int maxCandlesForIndicators = 300;

  /// Supabase `screener_filter_cache` rows older than this are ignored; a new
  /// full screener run refreshes the cache.
  static const Duration screenerFilterCacheTtl = Duration(hours: 4);
}

class StockMarket {
  static const String nse = 'NSE';
  static const String bse = 'BSE';
  static const String us = 'US';
}

class Timeframe {
  static const String daily = '1d';
  static const String weekly = '1wk';
  static const String monthly = '1mo';

  static String label(String tf) {
    switch (tf) {
      case daily:
        return 'Daily';
      case weekly:
        return 'Weekly';
      case monthly:
        return 'Monthly';
      default:
        return tf;
    }
  }
}

class FilterSignal {
  static const String buy = 'BUY';
  static const String sell = 'SELL';
  static const String neutral = 'NEUTRAL';
  static const String any = 'ANY';
}
