import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/watchlist_entry.dart';
import '../services/alert_service.dart';
import 'sync_provider.dart';
import 'watchlist_provider.dart';

// ── Provider for the AlertService singleton ────────────────────────────────────

final alertServiceProvider = Provider<AlertService>((ref) => AlertService());

// ── Alert state ────────────────────────────────────────────────────────────────

class AlertState {
  final List<WatchlistAlert> alerts;
  final bool isChecking;

  const AlertState({this.alerts = const [], this.isChecking = false});

  int get count => alerts.length;
  bool get hasAlerts => alerts.isNotEmpty;

  /// Alerts grouped by symbol for easy display.
  Map<String, List<WatchlistAlert>> get bySymbol {
    final map = <String, List<WatchlistAlert>>{};
    for (final a in alerts) {
      map.putIfAbsent(a.symbol, () => []).add(a);
    }
    return map;
  }

  AlertState copyWith({List<WatchlistAlert>? alerts, bool? isChecking}) =>
      AlertState(
        alerts: alerts ?? this.alerts,
        isChecking: isChecking ?? this.isChecking,
      );
}

class AlertNotifier extends StateNotifier<AlertState> {
  final Ref _ref;

  AlertNotifier(this._ref) : super(const AlertState());

  /// Run alert check for all watchlist entries.
  Future<void> refresh() async {
    state = state.copyWith(isChecking: true);
    final entries = _ref.read(watchlistEntriesProvider);
    final cache = _ref.read(cacheServiceProvider);
    final service = _ref.read(alertServiceProvider);
    final alerts = service.checkAlerts(entries, cache);
    state = AlertState(alerts: alerts, isChecking: false);
  }

  /// Dismiss a specific alert.
  void dismiss(WatchlistAlert alert) {
    state = state.copyWith(
      alerts: state.alerts
          .where((a) => !(a.symbol == alert.symbol && a.indicatorName == alert.indicatorName))
          .toList(),
    );
  }

  /// Dismiss all alerts for a symbol.
  void dismissForSymbol(String symbol) {
    state = state.copyWith(
      alerts: state.alerts.where((a) => a.symbol != symbol).toList(),
    );
  }

  void dismissAll() => state = state.copyWith(alerts: []);
}

final alertProvider =
    StateNotifierProvider<AlertNotifier, AlertState>(
  (ref) => AlertNotifier(ref),
);
