import 'package:flutter/material.dart';
import '../utils/constants.dart';

enum IndicatorType {
  rsi,
  supertrend,
  chandelierExit,
  macd,
  emaCrossover,
  ema10Cross,
  approachingEma200,
  bollingerBands,
  adx,
  sethi,
}

extension IndicatorTypeExt on IndicatorType {
  String get displayName {
    switch (this) {
      case IndicatorType.rsi:
        return 'RSI';
      case IndicatorType.supertrend:
        return 'Supertrend';
      case IndicatorType.chandelierExit:
        return 'Chandelier Exit';
      case IndicatorType.macd:
        return 'MACD';
      case IndicatorType.emaCrossover:
        return 'EMA Crossover';
      case IndicatorType.ema10Cross:
        return 'EMA 10 Cross';
      case IndicatorType.approachingEma200:
        return 'Approaching EMA 200';
      case IndicatorType.bollingerBands:
        return 'Bollinger Bands';
      case IndicatorType.adx:
        return 'ADX';
      case IndicatorType.sethi:
        return 'Sethi';
    }
  }

  String get description {
    switch (this) {
      case IndicatorType.rsi:
        return 'Momentum oscillator measuring speed of price change';
      case IndicatorType.supertrend:
        return 'ATR-based trend-following indicator';
      case IndicatorType.chandelierExit:
        return 'Volatility-based stop-loss levels using ATR';
      case IndicatorType.macd:
        return 'Trend-following momentum indicator using EMAs';
      case IndicatorType.emaCrossover:
        return 'Fast and slow EMA crossover signals';
      case IndicatorType.ema10Cross:
        return 'Close above EMA 10 and 200, 10 crossed 30 & 48; skip illiquid, climax volume, and defensive names';
      case IndicatorType.approachingEma200:
        return 'Watchlist: 10 crossed 30 & 48, close 0–8% below a flattening EMA 200. Do not buy until close reclaims 200';
      case IndicatorType.bollingerBands:
        return 'Volatility bands around a moving average';
      case IndicatorType.adx:
        return 'Average Directional Index measuring trend strength';
      case IndicatorType.sethi:
        return '20-day breakout with trend, volume surge, and RSI confirmation';
    }
  }

  IconData get icon {
    switch (this) {
      case IndicatorType.rsi:
        return Icons.show_chart;
      case IndicatorType.supertrend:
        return Icons.trending_up;
      case IndicatorType.chandelierExit:
        return Icons.candlestick_chart;
      case IndicatorType.macd:
        return Icons.bar_chart;
      case IndicatorType.emaCrossover:
        return Icons.swap_vert;
      case IndicatorType.ema10Cross:
        return Icons.timeline;
      case IndicatorType.approachingEma200:
        return Icons.visibility_outlined;
      case IndicatorType.bollingerBands:
        return Icons.compress;
      case IndicatorType.adx:
        return Icons.speed;
      case IndicatorType.sethi:
        return Icons.rocket_launch_outlined;
    }
  }
}

/// Direction for the dual-RSI crossover condition.
class RsiCrossover {
  static const String fastAboveSlow = 'FAST_ABOVE_SLOW';
  static const String fastBelowSlow = 'FAST_BELOW_SLOW';
  static const String any = 'ANY';
}

class RsiFilterParams {
  final int period;
  final double oversoldLevel;
  final double overboughtLevel;
  final String signal;

  /// Dual-RSI: compare a short-period RSI against a long-period RSI.
  final bool useDualRsi;

  /// The "slow" RSI period used for comparison (default 100).
  /// The "fast" RSI still uses [period] above.
  final int slowPeriod;

  /// [RsiCrossover.fastAboveSlow], [RsiCrossover.fastBelowSlow], or [RsiCrossover.any].
  final String crossover;

  const RsiFilterParams({
    this.period = AppConstants.defaultRsiPeriod,
    this.oversoldLevel = 30.0,
    this.overboughtLevel = 70.0,
    this.signal = FilterSignal.any,
    this.useDualRsi = false,
    this.slowPeriod = AppConstants.defaultRsiSlowPeriod,
    this.crossover = RsiCrossover.fastAboveSlow,
  });

  RsiFilterParams copyWith({
    int? period,
    double? oversoldLevel,
    double? overboughtLevel,
    String? signal,
    bool? useDualRsi,
    int? slowPeriod,
    String? crossover,
  }) =>
      RsiFilterParams(
        period: period ?? this.period,
        oversoldLevel: oversoldLevel ?? this.oversoldLevel,
        overboughtLevel: overboughtLevel ?? this.overboughtLevel,
        signal: signal ?? this.signal,
        useDualRsi: useDualRsi ?? this.useDualRsi,
        slowPeriod: slowPeriod ?? this.slowPeriod,
        crossover: crossover ?? this.crossover,
      );
}

class SupertrendFilterParams {
  final int period;
  final double multiplier;
  final String signal;

  const SupertrendFilterParams({
    this.period = AppConstants.defaultSupertrendPeriod,
    this.multiplier = AppConstants.defaultSupertrendMultiplier,
    this.signal = FilterSignal.any,
  });

  SupertrendFilterParams copyWith({
    int? period,
    double? multiplier,
    String? signal,
  }) =>
      SupertrendFilterParams(
        period: period ?? this.period,
        multiplier: multiplier ?? this.multiplier,
        signal: signal ?? this.signal,
      );
}

class ChandelierFilterParams {
  final int period;
  final double multiplier;
  final String signal;

  const ChandelierFilterParams({
    this.period = AppConstants.defaultChandelierPeriod,
    this.multiplier = AppConstants.defaultChandelierMultiplier,
    this.signal = FilterSignal.any,
  });

  ChandelierFilterParams copyWith({
    int? period,
    double? multiplier,
    String? signal,
  }) =>
      ChandelierFilterParams(
        period: period ?? this.period,
        multiplier: multiplier ?? this.multiplier,
        signal: signal ?? this.signal,
      );
}

class MacdFilterParams {
  final int fastPeriod;
  final int slowPeriod;
  final int signalPeriod;
  final String signal;

  const MacdFilterParams({
    this.fastPeriod = AppConstants.defaultMacdFastPeriod,
    this.slowPeriod = AppConstants.defaultMacdSlowPeriod,
    this.signalPeriod = AppConstants.defaultMacdSignalPeriod,
    this.signal = FilterSignal.any,
  });

  MacdFilterParams copyWith({
    int? fastPeriod,
    int? slowPeriod,
    int? signalPeriod,
    String? signal,
  }) =>
      MacdFilterParams(
        fastPeriod: fastPeriod ?? this.fastPeriod,
        slowPeriod: slowPeriod ?? this.slowPeriod,
        signalPeriod: signalPeriod ?? this.signalPeriod,
        signal: signal ?? this.signal,
      );
}

class Ema10CrossFilterParams {
  final int fastPeriod;
  final int midFastPeriod;
  final int midSlowPeriod;
  final int trendPeriod;

  /// The later of the 10/30 and 10/48 crosses (up for entry, down for exit)
  /// must fall within this many bars. 0 = completing cross on the latest bar.
  final int crossLookback;

  /// When true, BUY also requires Supertrend BUY; SELL if Supertrend SELL
  /// or EMA 10 is below 30 and 48.
  final bool requireSupertrend;

  /// Skip BUY when 20-day rupee ADV is below [minAdvInr].
  final bool skipIlliquid;
  final int volumeLookback;
  final double minAdvInr;

  /// Skip BUY when signal-day volume exceeds [maxVolumeMultiplier] × 20D avg.
  final bool skipClimaxVolume;
  final double maxVolumeMultiplier;

  /// Skip BUY on FMCG, insurance, OMCs, defence PSUs, and large IT.
  final bool skipDefensive;

  final String signal;

  const Ema10CrossFilterParams({
    this.fastPeriod = AppConstants.defaultEma10Period,
    this.midFastPeriod = AppConstants.defaultEma10MidFastPeriod,
    this.midSlowPeriod = AppConstants.defaultEma10MidSlowPeriod,
    this.trendPeriod = AppConstants.defaultEma10TrendPeriod,
    this.crossLookback = AppConstants.defaultEma10CrossLookback,
    this.requireSupertrend = false,
    this.skipIlliquid = true,
    this.volumeLookback = AppConstants.defaultEma10VolumeLookback,
    this.minAdvInr = AppConstants.defaultEma10MinAdvInr,
    this.skipClimaxVolume = true,
    this.maxVolumeMultiplier = AppConstants.defaultEma10MaxVolumeMultiplier,
    this.skipDefensive = true,
    this.signal = FilterSignal.buy,
  });

  Ema10CrossFilterParams copyWith({
    int? fastPeriod,
    int? midFastPeriod,
    int? midSlowPeriod,
    int? trendPeriod,
    int? crossLookback,
    bool? requireSupertrend,
    bool? skipIlliquid,
    int? volumeLookback,
    double? minAdvInr,
    bool? skipClimaxVolume,
    double? maxVolumeMultiplier,
    bool? skipDefensive,
    String? signal,
  }) =>
      Ema10CrossFilterParams(
        fastPeriod: fastPeriod ?? this.fastPeriod,
        midFastPeriod: midFastPeriod ?? this.midFastPeriod,
        midSlowPeriod: midSlowPeriod ?? this.midSlowPeriod,
        trendPeriod: trendPeriod ?? this.trendPeriod,
        crossLookback: crossLookback ?? this.crossLookback,
        requireSupertrend: requireSupertrend ?? this.requireSupertrend,
        skipIlliquid: skipIlliquid ?? this.skipIlliquid,
        volumeLookback: volumeLookback ?? this.volumeLookback,
        minAdvInr: minAdvInr ?? this.minAdvInr,
        skipClimaxVolume: skipClimaxVolume ?? this.skipClimaxVolume,
        maxVolumeMultiplier: maxVolumeMultiplier ?? this.maxVolumeMultiplier,
        skipDefensive: skipDefensive ?? this.skipDefensive,
        signal: signal ?? this.signal,
      );
}

/// Watchlist-only: 10/30/48 just crossed while close is still under a
/// flattening EMA 200. Not a BUY — wait for close to reclaim 200.
class ApproachingEma200FilterParams {
  final int fastPeriod;
  final int midFastPeriod;
  final int midSlowPeriod;
  final int trendPeriod;
  final int crossLookback;

  /// Close must be at most this percent below EMA 200 (and still below).
  final double maxPctBelow;

  final int slopeLookback;

  /// 20-bar EMA 200 percent change must be >= this (e.g. -2 = not falling
  /// more than 2%).
  final double minEma200SlopePct;

  final bool skipIlliquid;
  final int volumeLookback;
  final double minAdvInr;
  final bool skipClimaxVolume;
  final double maxVolumeMultiplier;
  final bool skipDefensive;
  final String signal;

  const ApproachingEma200FilterParams({
    this.fastPeriod = AppConstants.defaultEma10Period,
    this.midFastPeriod = AppConstants.defaultEma10MidFastPeriod,
    this.midSlowPeriod = AppConstants.defaultEma10MidSlowPeriod,
    this.trendPeriod = AppConstants.defaultEma10TrendPeriod,
    this.crossLookback = AppConstants.defaultEma10CrossLookback,
    this.maxPctBelow = AppConstants.defaultApproachingEma200MaxPctBelow,
    this.slopeLookback = AppConstants.defaultApproachingEma200SlopeLookback,
    this.minEma200SlopePct = AppConstants.defaultApproachingEma200MinSlopePct,
    this.skipIlliquid = true,
    this.volumeLookback = AppConstants.defaultEma10VolumeLookback,
    this.minAdvInr = AppConstants.defaultEma10MinAdvInr,
    this.skipClimaxVolume = true,
    this.maxVolumeMultiplier = AppConstants.defaultEma10MaxVolumeMultiplier,
    this.skipDefensive = true,
    this.signal = FilterSignal.watch,
  });

  Ema10CrossFilterParams get gateParams => Ema10CrossFilterParams(
        skipIlliquid: skipIlliquid,
        volumeLookback: volumeLookback,
        minAdvInr: minAdvInr,
        skipClimaxVolume: skipClimaxVolume,
        maxVolumeMultiplier: maxVolumeMultiplier,
        skipDefensive: skipDefensive,
      );

  ApproachingEma200FilterParams copyWith({
    int? fastPeriod,
    int? midFastPeriod,
    int? midSlowPeriod,
    int? trendPeriod,
    int? crossLookback,
    double? maxPctBelow,
    int? slopeLookback,
    double? minEma200SlopePct,
    bool? skipIlliquid,
    int? volumeLookback,
    double? minAdvInr,
    bool? skipClimaxVolume,
    double? maxVolumeMultiplier,
    bool? skipDefensive,
    String? signal,
  }) =>
      ApproachingEma200FilterParams(
        fastPeriod: fastPeriod ?? this.fastPeriod,
        midFastPeriod: midFastPeriod ?? this.midFastPeriod,
        midSlowPeriod: midSlowPeriod ?? this.midSlowPeriod,
        trendPeriod: trendPeriod ?? this.trendPeriod,
        crossLookback: crossLookback ?? this.crossLookback,
        maxPctBelow: maxPctBelow ?? this.maxPctBelow,
        slopeLookback: slopeLookback ?? this.slopeLookback,
        minEma200SlopePct: minEma200SlopePct ?? this.minEma200SlopePct,
        skipIlliquid: skipIlliquid ?? this.skipIlliquid,
        volumeLookback: volumeLookback ?? this.volumeLookback,
        minAdvInr: minAdvInr ?? this.minAdvInr,
        skipClimaxVolume: skipClimaxVolume ?? this.skipClimaxVolume,
        maxVolumeMultiplier: maxVolumeMultiplier ?? this.maxVolumeMultiplier,
        skipDefensive: skipDefensive ?? this.skipDefensive,
        signal: signal ?? this.signal,
      );
}

class EmaFilterParams {
  final int fastPeriod;
  final int slowPeriod;
  final String signal;

  const EmaFilterParams({
    this.fastPeriod = 20,
    this.slowPeriod = 50,
    this.signal = FilterSignal.any,
  });

  EmaFilterParams copyWith({
    int? fastPeriod,
    int? slowPeriod,
    String? signal,
  }) =>
      EmaFilterParams(
        fastPeriod: fastPeriod ?? this.fastPeriod,
        slowPeriod: slowPeriod ?? this.slowPeriod,
        signal: signal ?? this.signal,
      );
}

class BollingerFilterParams {
  final int period;
  final double stdDev;
  final String signal;

  const BollingerFilterParams({
    this.period = AppConstants.defaultBollingerPeriod,
    this.stdDev = AppConstants.defaultBollingerStdDev,
    this.signal = FilterSignal.any,
  });

  BollingerFilterParams copyWith({
    int? period,
    double? stdDev,
    String? signal,
  }) =>
      BollingerFilterParams(
        period: period ?? this.period,
        stdDev: stdDev ?? this.stdDev,
        signal: signal ?? this.signal,
      );
}

class AdxFilterParams {
  final int period;
  final double minAdx;
  final String signal;

  const AdxFilterParams({
    this.period = AppConstants.defaultAdxPeriod,
    this.minAdx = 25.0,
    this.signal = FilterSignal.any,
  });

  AdxFilterParams copyWith({
    int? period,
    double? minAdx,
    String? signal,
  }) =>
      AdxFilterParams(
        period: period ?? this.period,
        minAdx: minAdx ?? this.minAdx,
        signal: signal ?? this.signal,
      );
}

class SethiFilterParams {
  final int highLookback;
  final int dmaFastPeriod;
  final int dmaSlowPeriod;
  final int volumeLookback;
  final double volumeMultiplier;
  final int rsiPeriod;
  final double rsiMin;
  final double rsiMax;
  final double minPrice;
  final double minAvgValue;
  final String signal;

  const SethiFilterParams({
    this.highLookback = AppConstants.defaultSethiHighLookback,
    this.dmaFastPeriod = AppConstants.defaultSethiDmaFast,
    this.dmaSlowPeriod = AppConstants.defaultSethiDmaSlow,
    this.volumeLookback = AppConstants.defaultSethiVolumeLookback,
    this.volumeMultiplier = AppConstants.defaultSethiVolumeMultiplier,
    this.rsiPeriod = AppConstants.defaultSethiRsiPeriod,
    this.rsiMin = AppConstants.defaultSethiRsiMin,
    this.rsiMax = AppConstants.defaultSethiRsiMax,
    this.minPrice = AppConstants.defaultSethiMinPrice,
    this.minAvgValue = AppConstants.defaultSethiMinAvgValue,
    this.signal = FilterSignal.buy,
  });

  SethiFilterParams copyWith({
    int? highLookback,
    int? dmaFastPeriod,
    int? dmaSlowPeriod,
    int? volumeLookback,
    double? volumeMultiplier,
    int? rsiPeriod,
    double? rsiMin,
    double? rsiMax,
    double? minPrice,
    double? minAvgValue,
    String? signal,
  }) =>
      SethiFilterParams(
        highLookback: highLookback ?? this.highLookback,
        dmaFastPeriod: dmaFastPeriod ?? this.dmaFastPeriod,
        dmaSlowPeriod: dmaSlowPeriod ?? this.dmaSlowPeriod,
        volumeLookback: volumeLookback ?? this.volumeLookback,
        volumeMultiplier: volumeMultiplier ?? this.volumeMultiplier,
        rsiPeriod: rsiPeriod ?? this.rsiPeriod,
        rsiMin: rsiMin ?? this.rsiMin,
        rsiMax: rsiMax ?? this.rsiMax,
        minPrice: minPrice ?? this.minPrice,
        minAvgValue: minAvgValue ?? this.minAvgValue,
        signal: signal ?? this.signal,
      );
}

/// Size, liquidity, and price-vs-EMA gates (no UI display of raw mcap/volume).
class QualityFilterParams {
  /// Minimum market cap in INR crore (NSE/BSE only). 0 = skip mcap check.
  final double minMarketCapCrore;
  final int volumeLookback;
  final double volumeMultiplier;
  final int ema20Period;
  final int ema50Period;
  final bool requireAboveEma20;
  final bool requireAboveEma50;

  const QualityFilterParams({
    this.minMarketCapCrore = AppConstants.defaultMinMarketCapCrore,
    this.volumeLookback = AppConstants.defaultSethiVolumeLookback,
    this.volumeMultiplier = AppConstants.defaultQualityVolumeMultiplier,
    this.ema20Period = 20,
    this.ema50Period = 50,
    this.requireAboveEma20 = true,
    this.requireAboveEma50 = true,
  });

  QualityFilterParams copyWith({
    double? minMarketCapCrore,
    int? volumeLookback,
    double? volumeMultiplier,
    int? ema20Period,
    int? ema50Period,
    bool? requireAboveEma20,
    bool? requireAboveEma50,
  }) =>
      QualityFilterParams(
        minMarketCapCrore: minMarketCapCrore ?? this.minMarketCapCrore,
        volumeLookback: volumeLookback ?? this.volumeLookback,
        volumeMultiplier: volumeMultiplier ?? this.volumeMultiplier,
        ema20Period: ema20Period ?? this.ema20Period,
        ema50Period: ema50Period ?? this.ema50Period,
        requireAboveEma20: requireAboveEma20 ?? this.requireAboveEma20,
        requireAboveEma50: requireAboveEma50 ?? this.requireAboveEma50,
      );
}

class ScreenerFilter {
  final Set<String> markets;
  final Set<String> sectors;
  final String timeframe;
  final bool useRsi;
  final RsiFilterParams rsiParams;
  final bool useSupertrend;
  final SupertrendFilterParams supertrendParams;
  final bool useChandelier;
  final ChandelierFilterParams chandelierParams;
  final bool useMacd;
  final MacdFilterParams macdParams;
  final bool useEma;
  final EmaFilterParams emaParams;
  final bool useEma10Cross;
  final Ema10CrossFilterParams ema10CrossParams;
  final bool useApproachingEma200;
  final ApproachingEma200FilterParams approachingEma200Params;
  final bool useBollinger;
  final BollingerFilterParams bollingerParams;
  final bool useAdx;
  final AdxFilterParams adxParams;
  final bool useSethi;
  final SethiFilterParams sethiParams;
  final bool useQualityFilter;
  final QualityFilterParams qualityParams;
  final bool requireAllFilters;

  /// When true, only include stocks where ALL matching indicators
  /// triggered within the last [freshSignalMaxBars] bars.
  final bool requireFreshSignal;

  /// Maximum signal age (in bars) for fresh signal mode.
  /// 0 = only today's new signals, 3 = triggered within last 3 bars, etc.
  final int freshSignalMaxBars;

  /// Maximum number of results to return (sorted by match score). 0 = unlimited.
  final int maxResults;

  const ScreenerFilter({
    this.markets = const {'NSE'},
    this.sectors = const {},
    this.timeframe = Timeframe.daily,
    this.useRsi = false,
    this.rsiParams = const RsiFilterParams(),
    this.useSupertrend = false,
    this.supertrendParams = const SupertrendFilterParams(),
    this.useChandelier = false,
    this.chandelierParams = const ChandelierFilterParams(),
    this.useMacd = false,
    this.macdParams = const MacdFilterParams(),
    this.useEma = false,
    this.emaParams = const EmaFilterParams(),
    this.useEma10Cross = false,
    this.ema10CrossParams = const Ema10CrossFilterParams(),
    this.useApproachingEma200 = false,
    this.approachingEma200Params = const ApproachingEma200FilterParams(),
    this.useBollinger = false,
    this.bollingerParams = const BollingerFilterParams(),
    this.useAdx = false,
    this.adxParams = const AdxFilterParams(),
    this.useSethi = false,
    this.sethiParams = const SethiFilterParams(),
    this.useQualityFilter = false,
    this.qualityParams = const QualityFilterParams(),
    this.requireAllFilters = true,
    this.requireFreshSignal = false,
    this.freshSignalMaxBars = 3,
    this.maxResults = AppConstants.defaultMaxResults,
  });

  bool get hasAnyFilter =>
      useQualityFilter ||
      useRsi ||
      useSupertrend ||
      useChandelier ||
      useMacd ||
      useEma ||
      useEma10Cross ||
      useApproachingEma200 ||
      useBollinger ||
      useAdx ||
      useSethi;

  bool get hasIndicatorFilters =>
      useRsi ||
      useSupertrend ||
      useChandelier ||
      useMacd ||
      useEma ||
      useEma10Cross ||
      useApproachingEma200 ||
      useBollinger ||
      useAdx ||
      useSethi;

  int get activeFilterCount {
    int count = 0;
    if (useQualityFilter) count++;
    if (useRsi) count++;
    if (useSupertrend) count++;
    if (useChandelier) count++;
    if (useMacd) count++;
    if (useEma) count++;
    if (useEma10Cross) count++;
    if (useApproachingEma200) count++;
    if (useBollinger) count++;
    if (useAdx) count++;
    if (useSethi) count++;
    return count;
  }

  ScreenerFilter copyWith({
    Set<String>? markets,
    Set<String>? sectors,
    String? timeframe,
    bool? useRsi,
    RsiFilterParams? rsiParams,
    bool? useSupertrend,
    SupertrendFilterParams? supertrendParams,
    bool? useChandelier,
    ChandelierFilterParams? chandelierParams,
    bool? useMacd,
    MacdFilterParams? macdParams,
    bool? useEma,
    EmaFilterParams? emaParams,
    bool? useEma10Cross,
    Ema10CrossFilterParams? ema10CrossParams,
    bool? useApproachingEma200,
    ApproachingEma200FilterParams? approachingEma200Params,
    bool? useBollinger,
    BollingerFilterParams? bollingerParams,
    bool? useAdx,
    AdxFilterParams? adxParams,
    bool? useSethi,
    SethiFilterParams? sethiParams,
    bool? useQualityFilter,
    QualityFilterParams? qualityParams,
    bool? requireAllFilters,
    bool? requireFreshSignal,
    int? freshSignalMaxBars,
    int? maxResults,
  }) =>
      ScreenerFilter(
        markets: markets ?? this.markets,
        sectors: sectors ?? this.sectors,
        timeframe: timeframe ?? this.timeframe,
        useRsi: useRsi ?? this.useRsi,
        rsiParams: rsiParams ?? this.rsiParams,
        useSupertrend: useSupertrend ?? this.useSupertrend,
        supertrendParams: supertrendParams ?? this.supertrendParams,
        useChandelier: useChandelier ?? this.useChandelier,
        chandelierParams: chandelierParams ?? this.chandelierParams,
        useMacd: useMacd ?? this.useMacd,
        macdParams: macdParams ?? this.macdParams,
        useEma: useEma ?? this.useEma,
        emaParams: emaParams ?? this.emaParams,
        useEma10Cross: useEma10Cross ?? this.useEma10Cross,
        ema10CrossParams: ema10CrossParams ?? this.ema10CrossParams,
        useApproachingEma200:
            useApproachingEma200 ?? this.useApproachingEma200,
        approachingEma200Params:
            approachingEma200Params ?? this.approachingEma200Params,
        useBollinger: useBollinger ?? this.useBollinger,
        bollingerParams: bollingerParams ?? this.bollingerParams,
        useAdx: useAdx ?? this.useAdx,
        adxParams: adxParams ?? this.adxParams,
        useSethi: useSethi ?? this.useSethi,
        sethiParams: sethiParams ?? this.sethiParams,
        useQualityFilter: useQualityFilter ?? this.useQualityFilter,
        qualityParams: qualityParams ?? this.qualityParams,
        requireAllFilters: requireAllFilters ?? this.requireAllFilters,
        requireFreshSignal: requireFreshSignal ?? this.requireFreshSignal,
        freshSignalMaxBars: freshSignalMaxBars ?? this.freshSignalMaxBars,
        maxResults: maxResults ?? this.maxResults,
      );
}
