import 'dart:convert';
import 'indicator_result.dart';

/// Snapshot of a single indicator's signal at the time a stock was watchlisted.
class SavedSignal {
  final String indicatorName;
  final String signal; // 'buy' | 'sell' | 'neutral'

  const SavedSignal({required this.indicatorName, required this.signal});

  Map<String, dynamic> toJson() => {'name': indicatorName, 'signal': signal};

  factory SavedSignal.fromJson(Map<String, dynamic> j) =>
      SavedSignal(indicatorName: j['name'] as String, signal: j['signal'] as String);

  factory SavedSignal.fromIndicator(IndicatorResult ind) =>
      SavedSignal(indicatorName: ind.name, signal: ind.signal.name);

  bool hasFlipped(SignalType current) => current.name != signal;
}

/// A watchlist item — symbol + the signals that were active when it was added.
class WatchlistEntry {
  final String symbol;
  final DateTime addedAt;
  final List<SavedSignal> savedSignals;
  /// Close price on the day the stock was added (for P&L since watchlist).
  final double? addedPrice;

  const WatchlistEntry({
    required this.symbol,
    required this.addedAt,
    required this.savedSignals,
    this.addedPrice,
  });

  /// Profit % from [addedPrice] to [currentPrice], or null if unavailable.
  double? profitPercent(double? currentPrice) {
    final base = addedPrice;
    if (base == null || base <= 0 || currentPrice == null) return null;
    return (currentPrice - base) / base * 100;
  }

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'addedAt': addedAt.toIso8601String(),
        'signals': savedSignals.map((s) => s.toJson()).toList(),
        if (addedPrice != null) 'addedPrice': addedPrice,
      };

  factory WatchlistEntry.fromJson(Map<String, dynamic> j) => WatchlistEntry(
        symbol: j['symbol'] as String,
        addedAt: DateTime.parse(j['addedAt'] as String),
        savedSignals: (j['signals'] as List)
            .map((s) => SavedSignal.fromJson(s as Map<String, dynamic>))
            .toList(),
        addedPrice: (j['addedPrice'] as num?)?.toDouble(),
      );
}

/// Represents a signal flip detected for a watchlist stock.
class WatchlistAlert {
  final String symbol;
  final String indicatorName;
  final String previousSignal; // signal at add time
  final String currentSignal;  // signal now
  final DateTime detectedAt;

  const WatchlistAlert({
    required this.symbol,
    required this.indicatorName,
    required this.previousSignal,
    required this.currentSignal,
    required this.detectedAt,
  });

  String get description =>
      '$indicatorName changed from ${_label(previousSignal)} → ${_label(currentSignal)}';

  String _label(String s) => s[0].toUpperCase() + s.substring(1);
}

// ── Helpers for JSON list persistence ─────────────────────────────────────────

String encodeEntries(Map<String, WatchlistEntry> entries) =>
    jsonEncode(entries.map((k, v) => MapEntry(k, v.toJson())));

Map<String, WatchlistEntry> decodeEntries(String json) {
  final map = jsonDecode(json) as Map<String, dynamic>;
  return map.map(
    (k, v) => MapEntry(k, WatchlistEntry.fromJson(v as Map<String, dynamic>)),
  );
}
