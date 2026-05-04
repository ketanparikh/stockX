import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../models/indicator_result.dart';
import '../models/watchlist_entry.dart';
import '../services/watchlist_db_service.dart';

// ── DB service provider ───────────────────────────────────────────────────────

final watchlistDbServiceProvider = Provider<WatchlistDbService?>((ref) {
  if (!AppConfig.isSupabaseConfigured) return null;
  try {
    return WatchlistDbService(Supabase.instance.client);
  } catch (_) {
    return null;
  }
});

// ── Main notifier ─────────────────────────────────────────────────────────────

class WatchlistNotifier extends StateNotifier<Map<String, WatchlistEntry>> {
  static const _localKey = 'watchlist_v2';

  final WatchlistDbService? _db;

  WatchlistNotifier(this._db) : super(const {});

  // ── Load ──────────────────────────────────────────────────────────────────

  /// Called after login with the current user's id.
  /// Prefers Supabase; falls back to SharedPreferences if DB unavailable.
  Future<void> loadForUser(String userId) async {
    final db = _db;
    if (db != null) {
      final entries = await db.loadForUser(userId);
      if (entries.isNotEmpty) {
        state = entries;
        return;
      }
    }
    // Fallback: local SharedPreferences (migrate to DB on next change)
    await _loadLocal();
  }

  /// Load from SharedPreferences only (used when not logged in / no Supabase).
  Future<void> loadLocal() => _loadLocal();

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final json  = prefs.getString(_localKey);
    if (json != null) {
      try {
        state = decodeEntries(json);
        return;
      } catch (_) {}
    }
    // Migrate from old plain-symbol list
    const legacyKey = 'watchlist';
    final old = prefs.getStringList(legacyKey) ?? [];
    if (old.isNotEmpty) {
      state = {
        for (final sym in old)
          sym: WatchlistEntry(symbol: sym, addedAt: DateTime.now(), savedSignals: const []),
      };
      _saveLocal();
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localKey, encodeEntries(state));
  }

  String? get _userId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  // ── Public mutations ──────────────────────────────────────────────────────

  void add(String symbol, List<IndicatorResult> indicators) {
    final entry = WatchlistEntry(
      symbol:       state[symbol]?.symbol ?? symbol,
      addedAt:      state[symbol]?.addedAt ?? DateTime.now(),
      savedSignals: indicators.map(SavedSignal.fromIndicator).toList(),
    );
    state = {...state, symbol: entry};

    _saveLocal();
    final uid = _userId;
    final db  = _db;
    if (db != null && uid != null) db.upsert(uid, entry);
  }

  void remove(String symbol) {
    state = Map.from(state)..remove(symbol);

    _saveLocal();
    final uid = _userId;
    final db  = _db;
    if (db != null && uid != null) db.delete(uid, symbol);
  }

  void toggle(String symbol, [List<IndicatorResult> indicators = const []]) {
    state.containsKey(symbol) ? remove(symbol) : add(symbol, indicators);
  }

  bool isWatched(String symbol) => state.containsKey(symbol);

  /// Wipe local state on logout.
  void clear() => state = {};
}

// ── Providers ─────────────────────────────────────────────────────────────────

final watchlistEntriesProvider =
    StateNotifierProvider<WatchlistNotifier, Map<String, WatchlistEntry>>(
  (ref) {
    final db = ref.watch(watchlistDbServiceProvider);
    return WatchlistNotifier(db);
  },
);

/// Backward-compatible set of watched symbols.
final watchlistProvider = Provider<Set<String>>(
  (ref) => ref.watch(watchlistEntriesProvider).keys.toSet(),
);
