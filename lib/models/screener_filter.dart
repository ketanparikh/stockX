import 'package:flutter/material.dart';
import '../utils/constants.dart';

enum IndicatorType {
  rsi,
  supertrend,
  chandelierExit,
  macd,
  emaCrossover,
  bollingerBands,
  adx,
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
      case IndicatorType.bollingerBands:
        return 'Bollinger Bands';
      case IndicatorType.adx:
        return 'ADX';
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
      case IndicatorType.bollingerBands:
        return 'Volatility bands around a moving average';
      case IndicatorType.adx:
        return 'Average Directional Index measuring trend strength';
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
      case IndicatorType.bollingerBands:
        return Icons.compress;
      case IndicatorType.adx:
        return Icons.speed;
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
  final bool useBollinger;
  final BollingerFilterParams bollingerParams;
  final bool useAdx;
  final AdxFilterParams adxParams;
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
    this.useBollinger = false,
    this.bollingerParams = const BollingerFilterParams(),
    this.useAdx = false,
    this.adxParams = const AdxFilterParams(),
    this.requireAllFilters = true,
    this.requireFreshSignal = false,
    this.freshSignalMaxBars = 3,
    this.maxResults = AppConstants.defaultMaxResults,
  });

  bool get hasAnyFilter =>
      useRsi || useSupertrend || useChandelier || useMacd || useEma || useBollinger || useAdx;

  int get activeFilterCount {
    int count = 0;
    if (useRsi) count++;
    if (useSupertrend) count++;
    if (useChandelier) count++;
    if (useMacd) count++;
    if (useEma) count++;
    if (useBollinger) count++;
    if (useAdx) count++;
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
    bool? useBollinger,
    BollingerFilterParams? bollingerParams,
    bool? useAdx,
    AdxFilterParams? adxParams,
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
        useBollinger: useBollinger ?? this.useBollinger,
        bollingerParams: bollingerParams ?? this.bollingerParams,
        useAdx: useAdx ?? this.useAdx,
        adxParams: adxParams ?? this.adxParams,
        requireAllFilters: requireAllFilters ?? this.requireAllFilters,
        requireFreshSignal: requireFreshSignal ?? this.requireFreshSignal,
        freshSignalMaxBars: freshSignalMaxBars ?? this.freshSignalMaxBars,
        maxResults: maxResults ?? this.maxResults,
      );
}
