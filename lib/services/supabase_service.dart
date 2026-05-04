import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/candle_data.dart';

/// Reads and writes candle data to the Supabase `stock_candles` table.
///
/// All public methods are no-ops (return null / empty) when Supabase has not
/// been configured — [isAvailable] must be checked by callers that render UI.
///
/// Table schema (see supabase_schema.sql):
///   symbol TEXT, timeframe TEXT, t BIGINT[], o/h/l/c/v FLOAT8[]
///   UNIQUE(symbol, timeframe)
class SupabaseService {
  static const _table = 'stock_candles';

  bool _ready = false;

  void markReady() => _ready = true;

  bool get isAvailable => _ready;

  SupabaseClient get _db => Supabase.instance.client;

  // ── Write (upsert) ───────────────────────────────────────────────────────

  /// Upserts candle data for one stock. Non-fatal on error.
  Future<void> writeCandles(
    String symbol,
    String timeframe,
    List<CandleData> candles,
  ) async {
    if (!isAvailable) return;
    try {
      await _db.from(_table).upsert(
        {
          'symbol': symbol,
          'timeframe': timeframe,
          'last_updated': DateTime.now().toUtc().toIso8601String(),
          't': candles.map((c) => c.timestamp.millisecondsSinceEpoch).toList(),
          'o': candles.map((c) => c.open).toList(),
          'h': candles.map((c) => c.high).toList(),
          'l': candles.map((c) => c.low).toList(),
          'c': candles.map((c) => c.close).toList(),
          'v': candles.map((c) => c.volume).toList(),
        },
        onConflict: 'symbol,timeframe',
      );
    } catch (_) {
      // Non-fatal — local cache already has the data
    }
  }

  // ── Read single ──────────────────────────────────────────────────────────

  Future<List<CandleData>?> readCandles(
    String symbol,
    String timeframe,
  ) async {
    if (!isAvailable) return null;
    try {
      final row = await _db
          .from(_table)
          .select('t,o,h,l,c,v')
          .eq('symbol', symbol)
          .eq('timeframe', timeframe)
          .maybeSingle();
      return row != null ? _decode(row) : null;
    } catch (_) {
      return null;
    }
  }

  // ── Bulk read ────────────────────────────────────────────────────────────

  /// Reads all cached stocks for [timeframe] in chunks and returns a map of
  /// symbol → candle list.  Supabase supports large IN filters (no 30-item
  /// limit like Firestore), so we use 200-symbol chunks.
  Future<Map<String, List<CandleData>>> readBatch(
    List<String> symbols,
    String timeframe, {
    void Function(int done, int total)? onProgress,
  }) async {
    if (!isAvailable || symbols.isEmpty) return {};

    final result = <String, List<CandleData>>{};
    const chunkSize = 200;

    for (int i = 0; i < symbols.length; i += chunkSize) {
      final chunk =
          symbols.sublist(i, (i + chunkSize).clamp(0, symbols.length));
      try {
        final rows = await _db
            .from(_table)
            .select('symbol,t,o,h,l,c,v')
            .eq('timeframe', timeframe)
            .inFilter('symbol', chunk);

        for (final row in (rows as List)) {
          final sym = row['symbol'] as String? ?? '';
          if (sym.isEmpty) continue;
          final candles = _decode(row as Map<String, dynamic>);
          if (candles != null) result[sym] = candles;
        }
      } catch (_) {
        // Skip failed chunks — partial results are acceptable
      }

      onProgress?.call(
        (i + chunk.length).clamp(0, symbols.length),
        symbols.length,
      );
    }
    return result;
  }

  // ── Decode ───────────────────────────────────────────────────────────────

  static List<CandleData>? _decode(Map<String, dynamic> row) {
    try {
      final t = (row['t'] as List).map((v) => v as int).toList();
      final o = _doubles(row['o'] as List);
      final h = _doubles(row['h'] as List);
      final l = _doubles(row['l'] as List);
      final c = _doubles(row['c'] as List);
      final v = _doubles(row['v'] as List);
      return List.generate(
        t.length,
        (i) => CandleData(
          timestamp: DateTime.fromMillisecondsSinceEpoch(t[i]),
          open: o[i],
          high: h[i],
          low: l[i],
          close: c[i],
          volume: v[i],
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static List<double> _doubles(List raw) =>
      raw.map((v) => (v as num).toDouble()).toList();
}
