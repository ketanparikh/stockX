import 'package:shared_preferences/shared_preferences.dart';
import '../models/candle_data.dart';

/// In-memory store for candle data, keyed by "${symbol}_${timeframe}".
///
/// Candles live only for the current app session (memory is cleared on hot
/// reload / restart).  Metadata (last sync timestamp + count) is persisted
/// in SharedPreferences so the UI can show staleness information across
/// restarts without requiring a re-sync.
class CacheService {
  static const _kLastSyncMs = 'stockx_last_sync_ms';
  static const _kSyncCount = 'stockx_sync_count';

  final Map<String, List<CandleData>> _store = {};
  SharedPreferences? _prefs;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Read ─────────────────────────────────────────────────────────────────

  bool isCached(String symbol, String timeframe) =>
      _store.containsKey(_key(symbol, timeframe));

  List<CandleData>? get(String symbol, String timeframe) =>
      _store[_key(symbol, timeframe)];

  int get count => _store.length;

  /// Timestamp of the last completed sync, or null if never synced.
  DateTime? get lastSyncTime {
    final ms = _prefs?.getInt(_kLastSyncMs);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  /// Number of stocks successfully fetched during the last sync.
  int get lastSyncCount => _prefs?.getInt(_kSyncCount) ?? 0;

  // ── Write ────────────────────────────────────────────────────────────────

  void store(String symbol, String timeframe, List<CandleData> candles) {
    _store[_key(symbol, timeframe)] = candles;
  }

  /// Persist sync statistics so the UI shows freshness info after restarts.
  Future<void> markSynced(int stockCount) async {
    await _prefs?.setInt(_kLastSyncMs, DateTime.now().millisecondsSinceEpoch);
    await _prefs?.setInt(_kSyncCount, stockCount);
  }

  // ── Clear ────────────────────────────────────────────────────────────────

  Future<void> clear() async {
    _store.clear();
    await _prefs?.remove(_kLastSyncMs);
    await _prefs?.remove(_kSyncCount);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String _key(String symbol, String timeframe) =>
      '${symbol}_$timeframe';

  /// Returns true when the last sync was more than [hours] ago (or never).
  bool isStale({int hours = 20}) {
    final t = lastSyncTime;
    if (t == null) return true;
    return DateTime.now().difference(t).inHours >= hours;
  }

  /// Human-readable summary for the UI.
  String get statusSummary {
    final t = lastSyncTime;
    if (t == null) return 'No data cached yet';
    final ago = _formatAgo(DateTime.now().difference(t));
    return '$count stocks in memory · synced $ago';
  }

  static String _formatAgo(Duration d) {
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
