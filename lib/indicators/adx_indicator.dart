import '../models/candle_data.dart';
import '../models/indicator_result.dart';
import '../models/screener_filter.dart';

class AdxIndicator {
  static AdxResult? calculate(
    List<CandleData> candles,
    AdxFilterParams params,
  ) {
    if (candles.length < params.period * 2 + 1) return null;

    final n = candles.length;
    final tr = <double>[];
    final plusDm = <double>[];
    final minusDm = <double>[];

    for (int i = 1; i < n; i++) {
      final h = candles[i].high, l = candles[i].low;
      final ph = candles[i-1].high, pl = candles[i-1].low, pc = candles[i-1].close;
      final up = h - ph, dn = pl - l;
      plusDm .add(up > dn && up > 0 ? up : 0.0);
      minusDm.add(dn > up && dn > 0 ? dn : 0.0);
      final t1 = h - l, t2 = (h - pc).abs(), t3 = (l - pc).abs();
      tr.add(t1 > t2 ? (t1 > t3 ? t1 : t3) : (t2 > t3 ? t2 : t3));
    }

    // Wilder-smooth TR/+DM/-DM and build the DX series in a single pass
    double smoothTr = 0, smoothPlus = 0, smoothMinus = 0;
    for (int i = 0; i < params.period; i++) {
      smoothTr    += tr[i];
      smoothPlus  += plusDm[i];
      smoothMinus += minusDm[i];
    }

    final dxSeries    = <double>[];
    final plusDiSeries  = <double>[];
    final minusDiSeries = <double>[];

    void _pushDi() {
      final pdi = smoothTr > 0 ? 100 * smoothPlus  / smoothTr : 0.0;
      final mdi = smoothTr > 0 ? 100 * smoothMinus / smoothTr : 0.0;
      plusDiSeries .add(pdi);
      minusDiSeries.add(mdi);
      final s = pdi + mdi;
      dxSeries.add(s > 0 ? 100 * (pdi - mdi).abs() / s : 0.0);
    }

    _pushDi(); // first DX from seed sums

    for (int i = params.period; i < tr.length; i++) {
      smoothTr    = smoothTr    - smoothTr    / params.period + tr[i];
      smoothPlus  = smoothPlus  - smoothPlus  / params.period + plusDm[i];
      smoothMinus = smoothMinus - smoothMinus / params.period + minusDm[i];
      _pushDi();
    }

    if (dxSeries.length < params.period) return null;

    // Wilder-smooth DX → ADX series
    double adxVal = 0;
    for (int i = 0; i < params.period; i++) adxVal += dxSeries[i];
    adxVal /= params.period;
    final adxSeries = <double>[adxVal];
    for (int i = params.period; i < dxSeries.length; i++) {
      adxVal = adxVal - adxVal / params.period + dxSeries[i] / params.period;
      adxSeries.add(adxVal);
    }

    // Build signal history aligned to adxSeries end
    // adxSeries[k] aligns with plusDiSeries[period-1+k]
    final diOffset = params.period - 1;
    final signalHistory = List.generate(adxSeries.length, (k) {
      final adx  = adxSeries[k];
      final pdi  = plusDiSeries [diOffset + k];
      final mdi  = minusDiSeries[diOffset + k];
      if (adx >= params.minAdx) {
        return pdi > mdi ? SignalType.buy : SignalType.sell;
      }
      return SignalType.neutral;
    });

    final age    = _signalAge(signalHistory);
    final curAdx = adxSeries.last;
    final curPdi = plusDiSeries.last;
    final curMdi = minusDiSeries.last;

    final SignalType signal;
    if (curAdx >= params.minAdx) {
      signal = curPdi > curMdi ? SignalType.buy : SignalType.sell;
    } else {
      signal = SignalType.neutral;
    }

    return AdxResult(
      adx: curAdx,
      plusDi: curPdi,
      minusDi: curMdi,
      signal: signal,
      signalAge: age,
    );
  }

  static int _signalAge(List<SignalType> history) {
    if (history.isEmpty) return 0;
    final cur = history.last;
    int age = 0;
    for (int i = history.length - 2; i >= 0 && age < 50; i--) {
      if (history[i] == cur) age++; else break;
    }
    return age;
  }

  static bool matchesFilter(AdxResult result, AdxFilterParams params) {
    switch (params.signal) {
      case 'BUY':     return result.signal == SignalType.buy;
      case 'SELL':    return result.signal == SignalType.sell;
      case 'NEUTRAL': return result.signal == SignalType.neutral;
      default:        return true;
    }
  }
}
