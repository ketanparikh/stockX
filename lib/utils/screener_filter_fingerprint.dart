import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/screener_filter.dart';

/// Stable SHA-256 over a canonical JSON view of [filter].
///
/// Used as the primary key for `screener_filter_cache` in Supabase. We cannot
/// pre-enumerate “all” filter combinations (numeric params are continuous); we
/// cache each distinct fingerprint that users actually run.
String screenerFilterCacheHash(ScreenerFilter f) {
  final bytes = utf8.encode(jsonEncode(_fingerprintMap(f)));
  return sha256.convert(bytes).toString();
}

Map<String, dynamic> _fingerprintMap(ScreenerFilter f) {
  final markets = f.markets.toList()..sort();
  final sectors = f.sectors.toList()..sort();
  final p = f.rsiParams;
  final st = f.supertrendParams;
  final ch = f.chandelierParams;
  final macd = f.macdParams;
  final ema = f.emaParams;
  final bb = f.bollingerParams;
  final adx = f.adxParams;
  final sethi = f.sethiParams;

  return {
    'markets': markets,
    'sectors': sectors,
    'timeframe': f.timeframe,
    'useRsi': f.useRsi,
    'rsi': {
      'period': p.period,
      'oversold': p.oversoldLevel,
      'overbought': p.overboughtLevel,
      'signal': p.signal,
      'useDualRsi': p.useDualRsi,
      'slowPeriod': p.slowPeriod,
      'crossover': p.crossover,
    },
    'useSupertrend': f.useSupertrend,
    'supertrend': {
      'period': st.period,
      'multiplier': st.multiplier,
      'signal': st.signal,
    },
    'useChandelier': f.useChandelier,
    'chandelier': {
      'period': ch.period,
      'multiplier': ch.multiplier,
      'signal': ch.signal,
    },
    'useMacd': f.useMacd,
    'macd': {
      'fast': macd.fastPeriod,
      'slow': macd.slowPeriod,
      'signal': macd.signalPeriod,
      'sig': macd.signal,
    },
    'useEma': f.useEma,
    'ema': {
      'fast': ema.fastPeriod,
      'slow': ema.slowPeriod,
      'signal': ema.signal,
    },
    'useBollinger': f.useBollinger,
    'bollinger': {
      'period': bb.period,
      'stdDev': bb.stdDev,
      'signal': bb.signal,
    },
    'useAdx': f.useAdx,
    'adx': {
      'period': adx.period,
      'minAdx': adx.minAdx,
      'signal': adx.signal,
    },
    'useSethi': f.useSethi,
    'sethi': {
      'high': sethi.highLookback,
      'dmaFast': sethi.dmaFastPeriod,
      'dmaSlow': sethi.dmaSlowPeriod,
      'volLb': sethi.volumeLookback,
      'volMult': sethi.volumeMultiplier,
      'rsiPeriod': sethi.rsiPeriod,
      'rsiMin': sethi.rsiMin,
      'rsiMax': sethi.rsiMax,
      'minPrice': sethi.minPrice,
      'minAvgValue': sethi.minAvgValue,
      'signal': sethi.signal,
    },
    'requireAll': f.requireAllFilters,
    'requireFresh': f.requireFreshSignal,
    'freshBars': f.freshSignalMaxBars,
    'maxResults': f.maxResults,
  };
}
