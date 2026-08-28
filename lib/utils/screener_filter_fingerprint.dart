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
    'useEma10Cross': f.useEma10Cross,
    'ema10Cross': {
      'fast': f.ema10CrossParams.fastPeriod,
      'midFast': f.ema10CrossParams.midFastPeriod,
      'midSlow': f.ema10CrossParams.midSlowPeriod,
      'trend': f.ema10CrossParams.trendPeriod,
      'lookback': f.ema10CrossParams.crossLookback,
      'requireST': f.ema10CrossParams.requireSupertrend,
      'skipIlliquid': f.ema10CrossParams.skipIlliquid,
      'volLb': f.ema10CrossParams.volumeLookback,
      'minAdv': f.ema10CrossParams.minAdvInr,
      'skipClimax': f.ema10CrossParams.skipClimaxVolume,
      'maxVolMult': f.ema10CrossParams.maxVolumeMultiplier,
      'skipDefensive': f.ema10CrossParams.skipDefensive,
      'signal': f.ema10CrossParams.signal,
    },
    'useApproachingEma200': f.useApproachingEma200,
    'approachingEma200': {
      'fast': f.approachingEma200Params.fastPeriod,
      'midFast': f.approachingEma200Params.midFastPeriod,
      'midSlow': f.approachingEma200Params.midSlowPeriod,
      'trend': f.approachingEma200Params.trendPeriod,
      'lookback': f.approachingEma200Params.crossLookback,
      'maxPctBelow': f.approachingEma200Params.maxPctBelow,
      'slopeLb': f.approachingEma200Params.slopeLookback,
      'minSlope': f.approachingEma200Params.minEma200SlopePct,
      'skipIlliquid': f.approachingEma200Params.skipIlliquid,
      'volLb': f.approachingEma200Params.volumeLookback,
      'minAdv': f.approachingEma200Params.minAdvInr,
      'skipClimax': f.approachingEma200Params.skipClimaxVolume,
      'maxVolMult': f.approachingEma200Params.maxVolumeMultiplier,
      'skipDefensive': f.approachingEma200Params.skipDefensive,
      'signal': f.approachingEma200Params.signal,
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
    'useQuality': f.useQualityFilter,
    'quality': {
      'minMcapCr': f.qualityParams.minMarketCapCrore,
      'volLb': f.qualityParams.volumeLookback,
      'volMult': f.qualityParams.volumeMultiplier,
      'ema20': f.qualityParams.ema20Period,
      'ema50': f.qualityParams.ema50Period,
      'aboveEma20': f.qualityParams.requireAboveEma20,
      'aboveEma50': f.qualityParams.requireAboveEma50,
    },
    'requireAll': f.requireAllFilters,
    'requireFresh': f.requireFreshSignal,
    'freshBars': f.freshSignalMaxBars,
    'maxResults': f.maxResults,
  };
}
