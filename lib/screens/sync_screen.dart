import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../providers/sync_provider.dart';
import '../services/cache_service.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';
import '../utils/stock_symbols.dart';

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  String _selectedTimeframe = Timeframe.daily;

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncProvider);
    final cache = ref.watch(cacheServiceProvider);
    final supabaseReady = ref.watch(supabaseReadyProvider);
    final scheme = Theme.of(context).colorScheme;

    // Show snack bar on status messages
    ref.listen(syncProvider, (prev, next) {
      if (next.message != null && next.message != prev?.message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message!),
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(syncProvider.notifier).dismissMessage();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Data Cache'),
        actions: [
          if (syncState.isRunning)
            TextButton.icon(
              onPressed: () => ref.read(syncProvider.notifier).cancel(),
              icon: Icon(Icons.stop_rounded, size: 16),
              label: Text('Cancel'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusCard(cache, supabaseReady, scheme),
          const SizedBox(height: 16),
          _buildTimeframeSelector(),
          const SizedBox(height: 16),
          _buildSyncButton(syncState),
          const SizedBox(height: 12),
          _buildLoadCloudButton(syncState, supabaseReady),
          const SizedBox(height: 20),
          if (syncState.isRunning || syncState.status == SyncStatus.success ||
              syncState.status == SyncStatus.cancelled)
            _buildProgressCard(syncState),
          if (syncState.isRunning || syncState.status == SyncStatus.success ||
              syncState.status == SyncStatus.cancelled)
            const SizedBox(height: 20),
          _buildSupabaseSetupCard(supabaseReady),
          const SizedBox(height: 20),
          _buildClearCacheButton(syncState, cache),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Status card ─────────────────────────────────────────────────────────────

  Widget _buildStatusCard(
      CacheService cache, bool supabaseReady, ColorScheme scheme) {
    final nseCount = StockUniverse.nseCount;
    final pct = nseCount > 0 ? (cache.count / nseCount * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: supabaseReady ? AppColors.bullish : Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                supabaseReady ? 'Supabase Connected' : 'Local Mode (no cloud)',
                style: TextStyle(
                  color: supabaseReady ? AppColors.bullish : Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statItem(
                  icon: Icons.storage_rounded,
                  label: 'Cached',
                  value: '${cache.count} stocks',
                  sub: '$pct% of NSE universe',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statItem(
                  icon: Icons.schedule_rounded,
                  label: 'Last Sync',
                  value: cache.lastSyncTime != null
                      ? _formatTime(cache.lastSyncTime!)
                      : 'Never',
                  sub: cache.isStale()
                      ? 'Data may be stale'
                      : 'Up to date',
                  valueColor:
                      cache.isStale() ? Colors.orange : AppColors.bullish,
                ),
              ),
            ],
          ),
          if (cache.count > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: nseCount > 0 ? cache.count / nseCount : 0,
                minHeight: 6,
                backgroundColor: context.appColors.border,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${cache.count} / $nseCount NSE stocks in memory',
              style: TextStyle(
                color: context.appColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required String label,
    required String value,
    required String sub,
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: context.appColors.textMuted),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: context.appColors.textMuted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? context.appColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(sub,
            style: TextStyle(
                color: context.appColors.textMuted, fontSize: 10)),
      ],
    );
  }

  // ── Timeframe selector ──────────────────────────────────────────────────────

  Widget _buildTimeframeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TIMEFRAME TO CACHE',
          style: TextStyle(
            color: context.appColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            (Timeframe.daily, 'Daily', '~1 year'),
            (Timeframe.weekly, 'Weekly', '~2 years'),
            (Timeframe.monthly, 'Monthly', '~5 years'),
          ].map(((String, String, String) tf) {
            final selected = _selectedTimeframe == tf.$1;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTimeframe = tf.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withOpacity(0.15)
                        : context.appColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          selected ? AppColors.primary : context.appColors.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        tf.$2,
                        style: TextStyle(
                          color: selected
                              ? AppColors.primaryLight
                              : context.appColors.textSecondary,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        tf.$3,
                        style: TextStyle(
                          color: context.appColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Sync button ─────────────────────────────────────────────────────────────

  Widget _buildSyncButton(SyncState syncState) {
    final nseCount = StockUniverse.nseCount;
    final isRunning = syncState.isRunning;
    final isSyncing = syncState.status == SyncStatus.syncing;

    return FilledButton.icon(
      onPressed: isRunning
          ? null
          : () => ref
              .read(syncProvider.notifier)
              .startSync(_selectedTimeframe),
      icon: isSyncing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(Icons.sync_rounded),
      label: Text(
        isSyncing
            ? 'Syncing…'
            : 'Sync All NSE  ($nseCount stocks)',
      ),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  // ── Load from cloud button ──────────────────────────────────────────────────

  Widget _buildLoadCloudButton(SyncState syncState, bool supabaseReady) {
    final isLoading = syncState.status == SyncStatus.loadingCloud;

    return OutlinedButton.icon(
      onPressed: (!supabaseReady || syncState.isRunning)
          ? null
          : () => ref
              .read(syncProvider.notifier)
              .loadFromCloud(_selectedTimeframe),
      icon: isLoading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.cloud_download_rounded, size: 18),
      label: Text(
        isLoading
            ? 'Loading from Supabase…'
            : supabaseReady
                ? 'Load from Supabase  (fast restore)'
                : 'Load from Supabase  (not connected)',
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        foregroundColor:
            supabaseReady ? AppColors.primary : context.appColors.textMuted,
        side: BorderSide(
          color: supabaseReady ? AppColors.primary : context.appColors.border,
        ),
      ),
    );
  }

  // ── Progress card ───────────────────────────────────────────────────────────

  Widget _buildProgressCard(SyncState syncState) {
    final pct = syncState.progress;
    final done = syncState.processed;
    final total = syncState.total;
    final isRunning = syncState.isRunning;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isRunning ? 'Syncing…' : 'Sync Complete',
                style: TextStyle(
                  color: context.appColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                '$done / $total',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: context.appColors.border,
              color: isRunning ? AppColors.primary : AppColors.bullish,
            ),
          ),
          const SizedBox(height: 8),
          if (syncState.currentSymbol.isNotEmpty && isRunning)
            Text(
              'Fetching: ${syncState.currentSymbol}',
              style: TextStyle(
                color: context.appColors.textMuted,
                fontSize: 11,
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              _countChip(
                '${syncState.successCount}',
                'cached',
                AppColors.bullish,
              ),
              const SizedBox(width: 8),
              _countChip(
                '${syncState.failCount}',
                'failed',
                AppColors.bearish,
              ),
              const SizedBox(width: 8),
              if (!isRunning)
                _countChip(
                  '${(pct * 100).round()}%',
                  'done',
                  AppColors.primary,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _countChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$value $label',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Supabase setup hint ──────────────────────────────────────────────────────

  Widget _buildSupabaseSetupCard(bool supabaseReady) {
    if (supabaseReady) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_off_rounded, size: 16, color: Colors.orange),
              SizedBox(width: 6),
              Text(
                'Supabase Not Connected',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Without Supabase, synced data is lost when the app is closed. '
            'Set it up once to persist data across sessions and devices.',
            style: TextStyle(color: context.appColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Text(
            'One-time setup:',
            style: TextStyle(
              color: context.appColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          ..._setupSteps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                step,
                style: TextStyle(
                  color: context.appColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppConfig.isSupabaseConfigured
                ? '✓ Credentials look set — restart the app'
                : 'Edit lib/config/app_config.dart with your URL + anon key',
            style: TextStyle(
              color: AppConfig.isSupabaseConfigured
                  ? AppColors.bullish
                  : AppColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static const _setupSteps = [
    '1. Go to supabase.com → New project (free tier is enough)',
    '2. Settings → API → copy Project URL + anon/public key',
    '3. Open lib/config/app_config.dart and paste both values',
    '4. SQL Editor → paste contents of supabase_schema.sql → Run',
    '5. Restart the app — badge will turn green',
  ];

  // ── Clear cache ─────────────────────────────────────────────────────────────

  Widget _buildClearCacheButton(SyncState syncState, CacheService cache) {
    if (cache.count == 0) return const SizedBox.shrink();

    return TextButton.icon(
      onPressed: syncState.isRunning
          ? null
          : () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Clear Cache?'),
                  content: Text(
                    'This will remove ${cache.count} stocks from memory. '
                    'You will need to re-sync before running the screener.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.red),
                      child: Text('Clear'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && mounted) {
                await ref.read(syncProvider.notifier).clearCache();
              }
            },
      icon: Icon(Icons.delete_outline_rounded, size: 16),
      label: Text('Clear Cache'),
      style: TextButton.styleFrom(foregroundColor: Colors.red),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}



