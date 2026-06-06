enum SignalType { buy, sell, neutral }

class IndicatorResult {
  final String name;
  final double? value;
  final double? value2;
  final double? value3;
  final SignalType signal;
  final String description;

  /// How many bars ago this signal was first triggered.
  /// 0 = triggered on the most recent (today's) bar.
  /// 1 = triggered yesterday, still active today.
  /// N = has been continuously active for N+1 bars.
  final int signalAge;

  const IndicatorResult({
    required this.name,
    this.value,
    this.value2,
    this.value3,
    required this.signal,
    required this.description,
    this.signalAge = 0,
  });

  bool get isBuy => signal == SignalType.buy;
  bool get isSell => signal == SignalType.sell;
  bool get isNeutral => signal == SignalType.neutral;

  /// Human-readable age label, e.g. "Today", "1 bar ago", "3 bars ago".
  String get signalAgeLabel {
    if (signalAge == 0) return 'Today';
    if (signalAge == 1) return '1 bar ago';
    return '$signalAge bars ago';
  }

  bool isFresh(int maxBars) => signalAge <= maxBars;
}

class RsiResult extends IndicatorResult {
  final double fastRsi;
  final double? slowRsi;

  RsiResult({
    required this.fastRsi,
    this.slowRsi,
    required SignalType signal,
    int signalAge = 0,
  }) : super(
          name: 'RSI',
          value: fastRsi,
          value2: slowRsi,
          signal: signal,
          description: _buildDescription(fastRsi, slowRsi, signal),
          signalAge: signalAge,
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
    int signalAge = 0,
  }) : super(
          name: 'Supertrend',
          value: supertrendValue,
          signal: signal,
          description: isBullish ? 'Bullish Trend' : 'Bearish Trend',
          signalAge: signalAge,
        );
}

class ChandelierResult extends IndicatorResult {
  ChandelierResult({
    required double longStop,
    required double shortStop,
    required SignalType signal,
    int signalAge = 0,
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
          signalAge: signalAge,
        );
}

class MacdResult extends IndicatorResult {
  MacdResult({
    required double macdLine,
    required double signalLine,
    required double histogram,
    required SignalType signal,
    int signalAge = 0,
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
          signalAge: signalAge,
        );
}

class EmaResult extends IndicatorResult {
  EmaResult({
    required String label,
    required double fastEma,
    required double slowEma,
    required SignalType signal,
    int signalAge = 0,
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
          signalAge: signalAge,
        );
}

class BollingerResult extends IndicatorResult {
  BollingerResult({
    required double upper,
    required double middle,
    required double lower,
    required double close,
    required SignalType signal,
    int signalAge = 0,
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
          signalAge: signalAge,
        );
}

class AdxResult extends IndicatorResult {
  AdxResult({
    required double adx,
    required double plusDi,
    required double minusDi,
    required SignalType signal,
    int signalAge = 0,
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
          signalAge: signalAge,
        );
}

class SethiResult extends IndicatorResult {
  final bool setupActive;

  SethiResult({
    required double rsi,
    required double priorHigh20,
    required double dma50,
    required double dma200,
    required SignalType signal,
    required this.setupActive,
    int signalAge = 0,
  }) : super(
          name: 'Sethi',
          value: rsi,
          value2: priorHigh20,
          value3: dma50,
          signal: signal,
          description: setupActive
              ? 'Breakout setup (RSI ${rsi.toStringAsFixed(1)}, >20D high, 50>200 DMA)'
              : 'No setup (RSI ${rsi.toStringAsFixed(1)})',
          signalAge: signalAge,
        );
}
