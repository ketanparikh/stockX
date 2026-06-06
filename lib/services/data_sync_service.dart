import '../models/candle_data.dart';
import '../utils/constants.dart';
import '../utils/stock_symbols.dart';
import 'cache_service.dart';
import 'supabase_service.dart';
import 'yahoo_finance_service.dart';

/// Result of a completed (or cancelled) sync run.
class SyncResult {
  final int success;
  final int failed;
  final bool cancelled;

  const SyncResult({
    required this.success,
    required this.failed,
    this.cancelled = false,
  });

  int get total => success + failed;
}

/// Orchestrates the "fetch → cache → Firestore" pipeline.
///
/// The high-level flow:
///   1. [syncAll]         — fetch from Yahoo Finance → store in [CacheService]
///                          → fire-and-forget write to [FirestoreService]
///   2. [loadFromCloud]   — read from Firestore → populate [CacheService]
///                          (fast second-device or post-restart load)
class DataSyncService {
  final YahooFinanceService _finance;
  final CacheService _cache;
  final SupabaseService _supabase;

  DataSyncService(this._finance, this._cache, this._supabase);

  // ── Sync from Yahoo Finance ──────────────────────────────────────────────

  /// Fetches candles for every stock in [stocks] and stores them in the cache.
  /// Writes to Firestore in the background (non-blocking).
  ///
  /// [onProgress] is called after each batch with
  ///   (processed, total, lastSymbol).
  /// Pass a [cancelFlag] closure that returns `true` when the user cancels.
  Future<SyncResult> syncAll(
    List<StockSymbol> stocks,
    String timeframe, {
    void Function(int done, int total, String symbol)? onProgress,
    bool Function()? cancelFlag,
  }) async {
    int success = 0;
    int failed = 0;

    final range = _rangeFor(timeframe);
    const batchSize = 10;

    for (int i = 0; i < stocks.length; i += batchSize) {
      if (cancelFlag?.call() ?? false) {
        return SyncResult(success: success, failed: failed, cancelled: true);
      }

      final end = (i + batchSize).clamp(0, stocks.length);
      final batch = stocks.sublist(i, end);

      final futures = batch.map((stock) async {
        try {
          final candles = await _finance.fetchCandles(
            stock.yahooSymbol,
            timeframe,
            range: range,
          );
          if (candles.length >= 2) {
            _cache.store(stock.symbol, timeframe, candles);
            // Non-blocking Firestore write — errors are swallowed inside the
            // service so a Supabase failure never breaks the sync run.
            _supabase
                .writeCandles(stock.symbol, timeframe, candles)
                .ignore();
            return true;
          }
          return false;
        } catch (_) {
          return false;
        }
      });

      final results = await Future.wait(futures);
      success += results.where((r) => r).length;
      failed += results.where((r) => !r).length;

      onProgress?.call(
        (i + batch.length).clamp(0, stocks.length),
        stocks.length,
        batch.last.symbol,
      );

      if (i + batchSize < stocks.length) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }

    if (success > 0) await _cache.markSynced(success);
    return SyncResult(success: success, failed: failed);
  }

  // ── Load from Firestore ──────────────────────────────────────────────────

  /// Bulk-loads candle data from Firestore into the in-memory cache.
  /// Returns the number of stocks loaded (0 if Firebase is unavailable).
  ///
  /// This is fast (no Yahoo Finance calls) and is the recommended path for
  /// subsequent app sessions after an initial full sync.
  Future<int> loadFromCloud(
    List<StockSymbol> stocks,
    String timeframe, {
    void Function(int done, int total)? onProgress,
  }) async {
    if (!_supabase.isAvailable) return 0;

    final symbols = stocks.map((s) => s.symbol).toList();
    int loaded = 0;

    final data = await _supabase.readBatch(
      symbols,
      timeframe,
      onProgress: onProgress,
    );

    for (final entry in data.entries) {
      _cache.store(entry.key, timeframe, entry.value);
      loaded++;
    }

    if (loaded > 0) await _cache.markSynced(loaded);
    return loaded;
  }

  // ── Cache warm-up for a single stock (used by ScreenerService) ───────────

  /// Fetches candles for one stock and places them in the cache.
  /// Called by [ScreenerService] when a cache miss occurs at screen time.
  Future<List<CandleData>?> fetchAndCache(
    StockSymbol stock,
    String timeframe,
  ) async {
    try {
      final candles = await _finance.fetchCandles(
        stock.yahooSymbol,
        timeframe,
        range: _rangeFor(timeframe),
      );
      if (candles.length >= 2) {
        _cache.store(stock.symbol, timeframe, candles);
        _supabase.writeCandles(stock.symbol, timeframe, candles).ignore();
        return candles;
      }
    } catch (_) {}
    return null;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String _rangeFor(String timeframe) {
    if (timeframe == Timeframe.weekly) return '2y';
    if (timeframe == Timeframe.monthly) return '5y';
    return '2y'; // daily: 200 DMA + Sethi breakout needs 201+ bars
  }
}
