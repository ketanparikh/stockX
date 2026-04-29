import '../models/candle_data.dart';
import '../models/indicator_result.dart';
import '../models/screener_filter.dart';

/// ADX — Average Directional Index (J. Welles Wilder Jr.).
///
/// Steps:
///   1. Compute True Range (TR), +DM, −DM for each bar.
///   2. Wilder-smooth TR, +DM, −DM over [period] bars.
///      Seed = plain sum of first [period] values.
///      Subsequent: smoothed = smoothed − smoothed/period + current
///   3. +DI = 100 × smoothed(+DM) / smoothed(TR)
///      −DI = 100 × smoothed(−DM) / smoothed(TR)
///   4. DX  = 100 × |+DI − −DI| / (+DI + −DI)
///   5. ADX = Wilder-smoothed DX over [period] bars.
///
/// Signal:
///   ADX >= minAdx AND +DI > −DI → BUY  (strong uptrend)
///   ADX >= minAdx AND −DI > +DI → SELL (strong downtrend)
///   ADX <  minAdx               → NEUTRAL (weak / no trend)
class AdxIndicator {
  static AdxResult? calculate(
    List<CandleData> candles,
    AdxFilterParams params,
  ) {
    // Need at least 2×period candles to have enough DX values to smooth ADX
    if (candles.length < params.period * 2 + 1) return null;

    final n = candles.length;

    // Step 1 — compute TR, +DM, −DM for bars 1..n-1
    final tr     = <double>[];
    final plusDm  = <double>[];
    final minusDm = <double>[];

    for (int i = 1; i < n; i++) {
      final high      = candles[i].high;
      final low       = candles[i].low;
      final prevHigh  = candles[i - 1].high;
      final prevLow   = candles[i - 1].low;
      final prevClose = candles[i - 1].close;

      final upMove   = high - prevHigh;
      final downMove = prevLow - low;

      plusDm .add(upMove   > downMove && upMove   > 0 ? upMove   : 0.0);
      minusDm.add(downMove > upMove   && downMove > 0 ? downMove : 0.0);

      final t1 = high - low;
      final t2 = (high - prevClose).abs();
      final t3 = (low  - prevClose).abs();
      tr.add(t1 > t2 ? (t1 > t3 ? t1 : t3) : (t2 > t3 ? t2 : t3));
    }

    // Step 2 & 3 — Wilder-smooth TR/+DM/−DM and compute DX in a single pass
    // Seed from first [period] bars
    double smoothTr     = 0, smoothPlus = 0, smoothMinus = 0;
    for (int i = 0; i < params.period; i++) {
      smoothTr    += tr[i];
      smoothPlus  += plusDm[i];
      smoothMinus += minusDm[i];
    }

    final dx        = <double>[];
    double plusDi   = 0;
    double minusDi  = 0;

    // First DX value from the seeded sums
    if (smoothTr > 0) {
      plusDi  = 100 * smoothPlus  / smoothTr;
      minusDi = 100 * smoothMinus / smoothTr;
      final diSum = plusDi + minusDi;
      dx.add(diSum > 0 ? 100 * (plusDi - minusDi).abs() / diSum : 0.0);
    } else {
      dx.add(0.0);
    }

    // Subsequent bars: Wilder smoothing (smoothed = smoothed − smoothed/period + current)
    for (int i = params.period; i < tr.length; i++) {
      smoothTr    = smoothTr    - smoothTr    / params.period + tr[i];
      smoothPlus  = smoothPlus  - smoothPlus  / params.period + plusDm[i];
      smoothMinus = smoothMinus - smoothMinus / params.period + minusDm[i];

      if (smoothTr > 0) {
        plusDi  = 100 * smoothPlus  / smoothTr;
        minusDi = 100 * smoothMinus / smoothTr;
        final diSum = plusDi + minusDi;
        dx.add(diSum > 0 ? 100 * (plusDi - minusDi).abs() / diSum : 0.0);
      } else {
        dx.add(0.0);
      }
    }

    // Step 5 — Wilder-smooth DX → ADX
    if (dx.length < params.period) return null;

    double adx = 0;
    for (int i = 0; i < params.period; i++) {
      adx += dx[i];
    }
    adx /= params.period;

    for (int i = params.period; i < dx.length; i++) {
      adx = adx - adx / params.period + dx[i] / params.period;
    }

    // plusDi / minusDi now hold the LAST smoothed values from the single pass above
    final SignalType signal;
    if (adx >= params.minAdx) {
      signal = plusDi > minusDi ? SignalType.buy : SignalType.sell;
    } else {
      signal = SignalType.neutral;
    }

    return AdxResult(
      adx: adx,
      plusDi: plusDi,
      minusDi: minusDi,
      signal: signal,
    );
  }

  static bool matchesFilter(AdxResult result, AdxFilterParams params) {
    switch (params.signal) {
      case 'BUY':
        return result.signal == SignalType.buy;
      case 'SELL':
        return result.signal == SignalType.sell;
      case 'NEUTRAL':
        return result.signal == SignalType.neutral;
      default:
        return true;
    }
  }
}
