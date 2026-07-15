import '../indicators/indicator_utils.dart';
import '../models/candle_data.dart';
import '../models/screener_filter.dart';

/// Liquidity / size / trend filters using candles and optional Yahoo market cap.
class StockQualityFilter {
  /// 1 crore INR = 10 million.
  static double croreToInr(double crore) => crore * 1e7;

  static bool passes(
    List<CandleData> candles,
    QualityFilterParams params, {
    double? marketCapInr,
    required String market,
  }) {
    if (params.minMarketCapCrore > 0 &&
        (market == 'NSE' || market == 'BSE')) {
      final minInr = croreToInr(params.minMarketCapCrore);
      if (marketCapInr == null || marketCapInr < minInr) return false;
    }

    final needEma50 = params.requireAboveEma50;
    final minLen = [
      params.volumeLookback + 1,
      if (params.requireAboveEma20) params.ema20Period,
      if (needEma50) params.ema50Period,
    ].fold<int>(0, (a, b) => a > b ? a : b);

    if (candles.length < minLen) return false;

    final last = candles.last;
    final close = last.close;
    final volume = last.volume;

    if (params.volumeMultiplier > 0) {
      final lb = params.volumeLookback;
      final prior = candles.sublist(candles.length - lb - 1, candles.length - 1);
      if (prior.isEmpty) return false;
      final avgVol =
          prior.map((c) => c.volume).reduce((a, b) => a + b) / prior.length;
      if (avgVol <= 0 || volume < params.volumeMultiplier * avgVol) {
        return false;
      }
    }

    final closes = candles.map((c) => c.close).toList();

    if (params.requireAboveEma20) {
      final ema20 = IndicatorUtils.ema(closes, params.ema20Period);
      if (ema20.isEmpty || close <= ema20.last) return false;
    }

    if (params.requireAboveEma50) {
      final ema50 = IndicatorUtils.ema(closes, params.ema50Period);
      if (ema50.isEmpty || close <= ema50.last) return false;
    }

    return true;
  }

  static String criteriaLabel(QualityFilterParams params) {
    final parts = <String>[];
    if (params.minMarketCapCrore > 0) {
      parts.add('Mcap > ${params.minMarketCapCrore.toStringAsFixed(0)} Cr');
    }
    if (params.volumeMultiplier > 0) {
      parts.add(
        'Vol > ${params.volumeMultiplier.toStringAsFixed(1)}× ${params.volumeLookback}D avg',
      );
    }
    if (params.requireAboveEma20) parts.add('Close > EMA ${params.ema20Period}');
    if (params.requireAboveEma50) parts.add('Close > EMA ${params.ema50Period}');
    return parts.join(' · ');
  }
}
