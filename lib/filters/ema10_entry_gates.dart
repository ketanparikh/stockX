import '../models/candle_data.dart';
import '../models/screener_filter.dart';

/// Point-in-time entry gates for EMA 10 Cross BUY.
///
/// Live EMA 10 Cross only skips illiquid names and the price band.
/// Climax volume and defensive skips remain available for Approaching EMA 200.
class Ema10EntryGates {
  Ema10EntryGates._();

  /// NSE tickers that mean-revert on EMA 10/30/48 (FMCG, paints, insurance,
  /// OMCs / city gas, defence PSUs, large IT).
  static const Set<String> defensiveSymbols = {
    // FMCG / staples / QSR
    'HINDUNILVR', 'ITC', 'NESTLEIND', 'BRITANNIA', 'DABUR', 'MARICO', 'COLPAL',
    'TATACONSUM', 'GODREJCP', 'EMAMILTD', 'VBL', 'UBL', 'RADICO', 'UNITDSPR',
    'HATSUN', 'BECTORFOOD', 'BIKAJI', 'DEVYANI', 'JUBLFOOD', 'WESTLIFE',
    'SAPPHIRE',
    // Paints
    'ASIANPAINT', 'BERGEPAINT', 'KANSAINER', 'INDIGOPNTS', 'AKZOINDIA',
    // Insurance
    'SBILIFE', 'HDFCLIFE', 'ICICIPRULI', 'ICICIGI', 'GODIGIT', 'NIACL', 'GICRE',
    'STARHEALTH', 'LICI',
    // Large IT
    'TCS', 'INFY', 'WIPRO', 'HCLTECH', 'TECHM', 'LTIM', 'PERSISTENT', 'COFORGE',
    'MPHASIS', 'LTTS', 'OFSS', 'TATAELXSI',
    // Energy / OMCs / city gas
    'RELIANCE', 'ONGC', 'BPCL', 'IOC', 'HINDPETRO', 'PETRONET', 'GAIL', 'OIL',
    'MGL', 'IGL', 'GUJGASLTD', 'ATGL',
    // Defence PSUs
    'HAL', 'BEL', 'BDL', 'MAZDOCK', 'GRSE', 'COCHINSHIP', 'PARAS', 'DATAPATTNS',
    'ZENTEC',
  };

  static bool isDefensive(String? symbol) {
    if (symbol == null || symbol.isEmpty) return false;
    final ticker = symbol.toUpperCase().replaceAll('.NS', '').replaceAll('.BO', '');
    return defensiveSymbols.contains(ticker);
  }

  /// Why a BUY should be suppressed at bar [i], or null if the tape is fine.
  static String? buySkipReason({
    required List<CandleData> candles,
    required int i,
    required Ema10CrossFilterParams params,
    String? symbol,
  }) {
    if (params.skipDefensive && isDefensive(symbol)) {
      return 'defensive (FMCG / ins / OMC / defence / large IT)';
    }

    if (params.applyPriceBand) {
      final px = candles[i].close;
      if (px < params.minPrice || px > params.maxPrice) {
        return 'price outside ₹${params.minPrice.toStringAsFixed(0)}–${params.maxPrice.toStringAsFixed(0)}';
      }
    }

    if (!params.skipIlliquid && !params.skipClimaxVolume) return null;

    final lb = params.volumeLookback;
    if (i < lb) return 'not enough volume history';

    var sumVol = 0.0;
    var sumVal = 0.0;
    for (var j = i - lb; j < i; j++) {
      final vol = candles[j].volume;
      sumVol += vol;
      sumVal += vol * candles[j].close;
    }
    final avgVol = sumVol / lb;
    final advInr = sumVal / lb;

    if (params.skipIlliquid && advInr < params.minAdvInr) {
      return 'illiquid (20-bar ADV < ₹10 lakh)';
    }
    if (params.skipClimaxVolume) {
      if (avgVol <= 0) return 'no volume';
      final ratio = candles[i].volume / avgVol;
      if (ratio > params.maxVolumeMultiplier) {
        return 'climax volume (>${params.maxVolumeMultiplier.toStringAsFixed(1)}× 20-bar)';
      }
    }
    return null;
  }
}
