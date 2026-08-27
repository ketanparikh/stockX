import '../models/candle_data.dart';
import '../models/screener_filter.dart';

/// Point-in-time entry gates for EMA 10 Cross BUY.
///
/// From the 2y NSE book: skip illiquid names (20D ADV < ₹10 lakh), skip climax
/// volume (>2× prior 20D avg), and skip low-beta businesses that do not trend
/// on this stack. Volume *surge* as a confirmation filter lost money here.
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
      return 'illiquid (20D ADV < ₹10 lakh)';
    }
    if (params.skipClimaxVolume) {
      if (avgVol <= 0) return 'no volume';
      final ratio = candles[i].volume / avgVol;
      if (ratio > params.maxVolumeMultiplier) {
        return 'climax volume (>${params.maxVolumeMultiplier.toStringAsFixed(1)}× 20D)';
      }
    }
    return null;
  }
}
