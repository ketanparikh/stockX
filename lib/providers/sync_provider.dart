import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/cache_service.dart';
import '../services/data_sync_service.dart';
import '../services/supabase_service.dart';
import '../services/yahoo_finance_service.dart';
import '../utils/constants.dart';
import '../utils/stock_symbols.dart';

// ── Singleton providers ───────────────────────────────────────────────────────

/// Pre-initialised CacheService injected via ProviderScope.overrides in main.dart.
final cacheServiceProvider = Provider<CacheService>((_) => CacheService());

/// Whether Supabase.initialize() succeeded (set via main.dart overrides).
final supabaseReadyProvider = Provider<bool>((_) => false);

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  final svc = SupabaseService();
  if (ref.watch(supabaseReadyProvider)) svc.markReady();
  return svc;
});

/// Shared Yahoo Finance client used by both sync and screener.
final yahooFinanceServiceProvider =
    Provider<YahooFinanceService>((_) => YahooFinanceService());

final dataSyncServiceProvider = Provider<DataSyncService>((ref) {
  return DataSyncService(
    ref.watch(yahooFinanceServiceProvider),
    ref.watch(cacheServiceProvider),
    ref.watch(supabaseServiceProvider),
  );
});

// ── Sync state ────────────────────────────────────────────────────────────────

enum SyncStatus { idle, syncing, loadingCloud, success, error, cancelled }

class SyncState {
  final SyncStatus status;
  final int processed;
  final int total;
  final String currentSymbol;
  final int successCount;
  final int failCount;
  final String? message;
  final String timeframe;

  const SyncState({
    this.status = SyncStatus.idle,
    this.processed = 0,
    this.total = 0,
    this.currentSymbol = '',
    this.successCount = 0,
    this.failCount = 0,
    this.message,
    this.timeframe = Timeframe.daily,
  });

  bool get isRunning =>
      status == SyncStatus.syncing || status == SyncStatus.loadingCloud;

  double get progress => total > 0 ? processed / total : 0.0;

  SyncState copyWith({
    SyncStatus? status,
    int? processed,
    int? total,
    String? currentSymbol,
    int? successCount,
    int? failCount,
    String? message,
    String? timeframe,
  }) =>
      SyncState(
        status: status ?? this.status,
        processed: processed ?? this.processed,
        total: total ?? this.total,
        currentSymbol: currentSymbol ?? this.currentSymbol,
        successCount: successCount ?? this.successCount,
        failCount: failCount ?? this.failCount,
        message: message,
        timeframe: timeframe ?? this.timeframe,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class SyncNotifier extends StateNotifier<SyncState> {
  final DataSyncService _sync;
  final CacheService _cache;

  bool _cancelled = false;

  SyncNotifier(this._sync, this._cache) : super(const SyncState());

  // ── Full sync from Yahoo Finance ──────────────────────────────────────────

  Future<void> startSync(String timeframe) async {
    if (state.isRunning) return;
    _cancelled = false;

    final stocks = StockUniverse.nse;
    state = SyncState(
      status: SyncStatus.syncing,
      total: stocks.length,
      timeframe: timeframe,
    );

    final result = await _sync.syncAll(
      stocks,
      timeframe,
      cancelFlag: () => _cancelled,
      onProgress: (done, tot, symbol) {
        if (!mounted) return;
        state = state.copyWith(
          processed: done,
          total: tot,
          currentSymbol: symbol,
          successCount: state.successCount + 1,
        );
      },
    );

    if (!mounted) return;

    if (result.cancelled) {
      state = state.copyWith(
        status: SyncStatus.cancelled,
        message: 'Sync cancelled — ${result.success} stocks cached',
      );
    } else {
      state = state.copyWith(
        status: SyncStatus.success,
        message: '${result.success} stocks cached · ${result.failed} failed',
        successCount: result.success,
        failCount: result.failed,
      );
    }
  }

  // ── Load from Supabase ────────────────────────────────────────────────────

  Future<void> loadFromCloud(String timeframe) async {
    if (state.isRunning) return;

    final stocks = StockUniverse.nse;
    state = SyncState(
      status: SyncStatus.loadingCloud,
      total: stocks.length,
      timeframe: timeframe,
    );

    final loaded = await _sync.loadFromCloud(
      stocks,
      timeframe,
      onProgress: (done, tot) {
        if (!mounted) return;
        state = state.copyWith(processed: done, total: tot);
      },
    );

    if (!mounted) return;

    state = state.copyWith(
      status: loaded > 0 ? SyncStatus.success : SyncStatus.error,
      message: loaded > 0
          ? '$loaded stocks loaded from Supabase'
          : 'No data found in Supabase — run a full Sync first',
    );
  }

  // ── Cancel ────────────────────────────────────────────────────────────────

  void cancel() => _cancelled = true;

  // ── Clear cache ───────────────────────────────────────────────────────────

  Future<void> clearCache() async {
    await _cache.clear();
    state = const SyncState(message: 'Cache cleared');
  }

  void dismissMessage() => state = state.copyWith(message: null);

  // ── Auto-load on startup ──────────────────────────────────────────────────
  /// Called once on app launch. Silently loads data from Supabase if available
  /// and the local cache is empty. No-op if a sync is already in progress.
  Future<void> autoLoadIfEmpty(String timeframe) async {
    if (state.isRunning) return;
    if (_cache.count > 0) return; // cache already warm
    await loadFromCloud(timeframe);
  }
}

final syncProvider =
    StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(
    ref.watch(dataSyncServiceProvider),
    ref.watch(cacheServiceProvider),
  );
});
