enum SignalType { buy, sell, neutral }

class IndicatorResult {
  final String name;
  final double? value;
  final double? value2;
  final double? value3;
  final SignalType signal;
  final String description;

  const IndicatorResult({
    required this.name,
    this.value,
    this.value2,
    this.value3,
    required this.signal,
    required this.description,
  });

  bool get isBuy => signal == SignalType.buy;
  bool get isSell => signal == SignalType.sell;
  bool get isNeutral => signal == SignalType.neutral;
}

class RsiResult extends IndicatorResult {
  /// The fast (primary) RSI value, corresponding to [RsiFilterParams.period].
  final double fastRsi;

  /// The slow RSI value when dual-RSI mode is active; null otherwise.
  final double? slowRsi;

  RsiResult({
    required this.fastRsi,
    this.slowRsi,
    required SignalType signal,
  }) : super(
          name: 'RSI',
          value: fastRsi,
          value2: slowRsi,
          signal: signal,
          description: _buildDescription(fastRsi, slowRsi, signal),
        );

  static String _buildDescription(
    double fast,
    double? slow,
    SignalType signal,
  ) {
    final fastStr = fast.toStringAsFixed(1);
    if (slow != null) {
      final slowStr = slow.toStringAsFixed(1);
      final rel = fast > slow ? 'Fast > Slow' : 'Fast < Slow';
      return '$rel  (RSI $fastStr vs $slowStr)';
    }
    if (fast <= 30) return 'Oversold ($fastStr)';
    if (fast >= 70) return 'Overbought ($fastStr)';
    return 'Neutral ($fastStr)';
  }
}

class SupertrendResult extends IndicatorResult {
  final bool isBullish;

  SupertrendResult({
    required double supertrendValue,
    required this.isBullish,
    required SignalType signal,
  }) : super(
          name: 'Supertrend',
          value: supertrendValue,
          signal: signal,
          description: isBullish ? 'Bullish Trend' : 'Bearish Trend',
        );
}

class ChandelierResult extends IndicatorResult {
  ChandelierResult({
    required double longStop,
    required double shortStop,
    required SignalType signal,
  }) : super(
          name: 'Chandelier Exit',
          value: longStop,
          value2: shortStop,
          signal: signal,
          description: signal == SignalType.buy
              ? 'Above Long Stop'
              : signal == SignalType.sell
                  ? 'Below Short Stop'
                  : 'Between Stops',
        );
}

class MacdResult extends IndicatorResult {
  MacdResult({
    required double macdLine,
    required double signalLine,
    required double histogram,
    required SignalType signal,
  }) : super(
          name: 'MACD',
          value: macdLine,
          value2: signalLine,
          value3: histogram,
          signal: signal,
          description: signal == SignalType.buy
              ? 'Bullish Crossover'
              : signal == SignalType.sell
                  ? 'Bearish Crossover'
                  : 'No Crossover',
        );
}

class EmaResult extends IndicatorResult {
  EmaResult({
    required String label,
    required double fastEma,
    required double slowEma,
    required SignalType signal,
  }) : super(
          name: label,
          value: fastEma,
          value2: slowEma,
          signal: signal,
          description: signal == SignalType.buy
              ? 'Fast > Slow (Bullish)'
              : signal == SignalType.sell
                  ? 'Fast < Slow (Bearish)'
                  : 'Converging',
        );
}

class BollingerResult extends IndicatorResult {
  BollingerResult({
    required double upper,
    required double middle,
    required double lower,
    required double close,
    required SignalType signal,
  }) : super(
          name: 'Bollinger Bands',
          value: upper,
          value2: middle,
          value3: lower,
          signal: signal,
          description: signal == SignalType.buy
              ? 'Near Lower Band (Potential Reversal)'
              : signal == SignalType.sell
                  ? 'Near Upper Band (Potential Reversal)'
                  : 'Within Bands',
        );
}

class AdxResult extends IndicatorResult {
  AdxResult({
    required double adx,
    required double plusDi,
    required double minusDi,
    required SignalType signal,
  }) : super(
          name: 'ADX',
          value: adx,
          value2: plusDi,
          value3: minusDi,
          signal: signal,
          description: adx > 25
              ? signal == SignalType.buy
                  ? 'Strong Uptrend (ADX: ${adx.toStringAsFixed(1)})'
                  : 'Strong Downtrend (ADX: ${adx.toStringAsFixed(1)})'
              : 'Weak Trend (ADX: ${adx.toStringAsFixed(1)})',
        );
}
