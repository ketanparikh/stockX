import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/watchlist_entry.dart';

/// Supabase CRUD for per-user watchlist rows.
///
/// Table: user_watchlist
///   id           uuid  PK
///   user_id      uuid  FK auth.users
///   symbol       text
///   added_at     timestamptz
///   saved_signals jsonb
class WatchlistDbService {
  final SupabaseClient _client;
  static const _table = 'user_watchlist';

  WatchlistDbService(this._client);

  /// Load all watchlist entries for the current user.
  Future<Map<String, WatchlistEntry>> loadForUser(String userId) async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('user_id', userId);

      final entries = <String, WatchlistEntry>{};
      for (final row in rows as List) {
        final entry = _fromRow(row as Map<String, dynamic>);
        entries[entry.symbol] = entry;
      }
      return entries;
    } catch (e) {
      return {};
    }
  }

  /// Upsert a single entry (insert or update).
  Future<void> upsert(String userId, WatchlistEntry entry) async {
    await _client.from(_table).upsert({
      'user_id': userId,
      'symbol': entry.symbol,
      'added_at': entry.addedAt.toIso8601String(),
      'saved_signals': entry.savedSignals.map((s) => s.toJson()).toList(),
      if (entry.addedPrice != null) 'added_price': entry.addedPrice,
    });
  }

  /// Delete a symbol from the user's watchlist.
  Future<void> delete(String userId, String symbol) async {
    await _client
        .from(_table)
        .delete()
        .eq('user_id', userId)
        .eq('symbol', symbol);
  }

  WatchlistEntry _fromRow(Map<String, dynamic> row) {
    final signals = (row['saved_signals'] as List? ?? [])
        .map((s) => SavedSignal.fromJson(s as Map<String, dynamic>))
        .toList();

    return WatchlistEntry(
      symbol: row['symbol'] as String,
      addedAt: DateTime.parse(row['added_at'] as String),
      savedSignals: signals,
      addedPrice: (row['added_price'] as num?)?.toDouble(),
    );
  }
}
