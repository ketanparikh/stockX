import '../models/candle_data.dart';
import '../models/indicator_result.dart';
import '../models/screener_filter.dart';

/// RSI — Relative Strength Index (J. Welles Wilder Jr.)
///
/// Standard mode (useDualRsi = false):
///   Computes a single RSI using [RsiFilterParams.period].
///   BUY     — RSI ≤ oversoldLevel  (default 30)
///   SELL    — RSI ≥ overboughtLevel (default 70)
///   NEUTRAL — between the two levels
///
/// Dual-RSI crossover mode (useDualRsi = true):
///   Computes a fast RSI ([period]) and a slow RSI ([slowPeriod]).
///   BUY     — fast RSI > slow RSI  (crossover = FAST_ABOVE_SLOW)
///   SELL    — fast RSI < slow RSI  (crossover = FAST_BELOW_SLOW)
///
///   The standard signal condition is evaluated independently and can be
///   combined with the crossover check in [matchesFilter].
///
/// Algorithm (Wilder's original Smoothed Moving Average method):
///   Seed avgGain / avgLoss = SMA of first [period] changes.
///   Then: avgGain = (avgGain × (period − 1) + gain) / period
///         avgLoss = (avgLoss × (period − 1) + loss) / period
///   RS = avgGain / avgLoss
///   RSI = 100 − 100 / (1 + RS)
class RsiIndicator {
  static RsiResult? calculate(
    List<CandleData> candles,
    RsiFilterParams params,
  ) {
    if (candles.length < params.period + 1) return null;

    final closes = candles.map((c) => c.close).toList();

    // Always compute the primary (fast) RSI
    final fastRsi = _computeRsi(closes, params.period);
    if (fastRsi == null) return null;

    // Compute slow RSI only when dual mode is enabled
    double? slowRsi;
    if (params.useDualRsi) {
      if (candles.length < params.slowPeriod + 1) return null;
      slowRsi = _computeRsi(closes, params.slowPeriod);
      if (slowRsi == null) return null;
    }

    final signal = _determineSignal(fastRsi, slowRsi, params);
    return RsiResult(fastRsi: fastRsi, slowRsi: slowRsi, signal: signal);
  }

  // ---------------------------------------------------------------------------
  // Core RSI computation (Wilder smoothing)
  // ---------------------------------------------------------------------------

  static double? _computeRsi(List<double> closes, int period) {
    if (closes.length < period + 1) return null;

    // Seed: plain average of first [period] up/down moves
    double avgGain = 0;
    double avgLoss = 0;
    for (int i = 1; i <= period; i++) {
      final delta = closes[i] - closes[i - 1];
      if (delta > 0) {
        avgGain += delta;
      } else {
        avgLoss += -delta;
      }
    }
    avgGain /= period;
    avgLoss /= period;

    // Wilder smoothing for all remaining bars
    for (int i = period + 1; i < closes.length; i++) {
      final delta = closes[i] - closes[i - 1];
      avgGain = (avgGain * (period - 1) + (delta > 0 ? delta : 0.0)) / period;
      avgLoss = (avgLoss * (period - 1) + (delta < 0 ? -delta : 0.0)) / period;
    }

    if (avgLoss == 0) return 100.0;
    final rs = avgGain / avgLoss;
    return 100.0 - (100.0 / (1.0 + rs));
  }

  // ---------------------------------------------------------------------------
  // Signal determination
  // ---------------------------------------------------------------------------

  static SignalType _determineSignal(
    double fastRsi,
    double? slowRsi,
    RsiFilterParams params,
  ) {
    // In dual mode the primary signal is the crossover direction
    if (params.useDualRsi && slowRsi != null) {
      return fastRsi > slowRsi ? SignalType.buy : SignalType.sell;
    }
    // Single-RSI: standard oversold / overbought zones
    if (fastRsi <= params.oversoldLevel)   return SignalType.buy;
    if (fastRsi >= params.overboughtLevel) return SignalType.sell;
    return SignalType.neutral;
  }

  // ---------------------------------------------------------------------------
  // Filter matching
  // ---------------------------------------------------------------------------

  /// Returns true when the result satisfies ALL active conditions in [params].
  ///
  /// Standard condition (checked when params.signal != 'ANY'):
  ///   The fast RSI must be in the oversold / overbought zone.
  ///
  /// Dual-RSI condition (checked when params.useDualRsi == true):
  ///   fastRsi vs slowRsi must satisfy params.crossover.
  ///
  /// Both conditions must pass when both are active (AND logic).
  static bool matchesFilter(RsiResult result, RsiFilterParams params) {
    // --- Standard zone check ---
    if (params.signal != 'ANY') {
      final standardOk = switch (params.signal) {
        'BUY'     => result.fastRsi <= params.oversoldLevel,
        'SELL'    => result.fastRsi >= params.overboughtLevel,
        'NEUTRAL' => result.fastRsi > params.oversoldLevel &&
                     result.fastRsi < params.overboughtLevel,
        _         => true,
      };
      if (!standardOk) return false;
    }

    // --- Dual RSI crossover check ---
    if (params.useDualRsi) {
      final slow = result.slowRsi;
      if (slow == null) return false; // slow RSI wasn't computed

      final crossoverOk = switch (params.crossover) {
        RsiCrossover.fastAboveSlow => result.fastRsi > slow,
        RsiCrossover.fastBelowSlow => result.fastRsi < slow,
        _                          => true,  // 'ANY'
      };
      if (!crossoverOk) return false;
    }

    return true;
  }
}
