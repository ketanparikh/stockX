import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/watchlist_entry.dart';
import '../providers/alert_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/watchlist_provider.dart';
import '../theme/app_colors.dart';
import '../utils/stock_symbols.dart';
import '../utils/watchlist_price_utils.dart';

class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh alerts whenever screen is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(alertProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final entries = ref.watch(watchlistEntriesProvider);
    final alertState = ref.watch(alertProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Watchlist'),
            if (alertState.hasAlerts) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.bearish.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.notifications_active_rounded, color: AppColors.bearish, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '${alertState.count} alert${alertState.count > 1 ? 's' : ''}',
                      style: const TextStyle(color: AppColors.bearish, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (alertState.hasAlerts)
            IconButton(
              icon: const Icon(Icons.notifications_off_outlined),
              tooltip: 'Dismiss all alerts',
              onPressed: () => ref.read(alertProvider.notifier).dismissAll(),
            ),
          IconButton(
            icon: alertState.isChecking
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh alerts',
            onPressed: () => ref.read(alertProvider.notifier).refresh(),
          ),
          if (entries.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClearAll(context, entries.keys.toList()),
              child: const Text('Clear All'),
            ),
        ],
      ),
      body: entries.isEmpty
          ? _buildEmpty(c)
          : _buildList(context, entries, alertState.bySymbol, c, scheme),
    );
  }

  void _confirmClearAll(BuildContext context, List<String> symbols) {
    final c = context.appColors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        title: Text('Clear Watchlist', style: TextStyle(color: c.textPrimary)),
        content: Text('Remove all stocks from your watchlist?', style: TextStyle(color: c.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              for (final sym in symbols) {
                ref.read(watchlistEntriesProvider.notifier).remove(sym);
              }
              ref.read(alertProvider.notifier).dismissAll();
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.bearish),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(AppSurfaces c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: c.surfaceVariant, shape: BoxShape.circle),
            child: Icon(Icons.bookmark_outline, color: c.textMuted, size: 48),
          ),
          const SizedBox(height: 24),
          Text('Your watchlist is empty',
              style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Bookmark stocks from search, screener results,\nor stock detail to track them here',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    Map<String, WatchlistEntry> entries,
    Map<String, List<WatchlistAlert>> alertsBySymbol,
    AppSurfaces c,
    ColorScheme scheme,
  ) {
    final symbols = entries.keys.toList();
    final cache = ref.watch(cacheServiceProvider);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: symbols.length,
      itemBuilder: (context, index) {
        final symbol = symbols[index];
        final entry = entries[symbol]!;
        final alerts = alertsBySymbol[symbol] ?? [];
        final currentPrice = watchlistCurrentPrice(symbol, cache);

        StockSymbol? stock;
        try {
          stock = StockUniverse.getAll().firstWhere((s) => s.symbol == symbol);
        } catch (_) {}

        return _WatchlistTile(
          symbol: symbol,
          entry: entry,
          stock: stock,
          alerts: alerts,
          currentPrice: currentPrice,
          onRemove: () {
            ref.read(watchlistEntriesProvider.notifier).remove(symbol);
            ref.read(alertProvider.notifier).dismissForSymbol(symbol);
          },
          onDismissAlerts: () => ref.read(alertProvider.notifier).dismissForSymbol(symbol),
        );
      },
    );
  }
}

// ── Individual tile ────────────────────────────────────────────────────────────

class _WatchlistTile extends StatelessWidget {
  final String symbol;
  final WatchlistEntry entry;
  final StockSymbol? stock;
  final List<WatchlistAlert> alerts;
  final double? currentPrice;
  final VoidCallback onRemove;
  final VoidCallback onDismissAlerts;

  const _WatchlistTile({
    required this.symbol,
    required this.entry,
    required this.stock,
    required this.alerts,
    required this.currentPrice,
    required this.onRemove,
    required this.onDismissAlerts,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final hasAlerts = alerts.isNotEmpty;
    final profitPct = entry.profitPercent(currentPrice);
    final profitColor = profitPct == null
        ? c.textMuted
        : profitPct >= 0
            ? AppColors.bullish
            : AppColors.bearish;

    return Column(
      children: [
        Dismissible(
          key: Key(symbol),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => onRemove(),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: AppColors.bearish.withValues(alpha: 0.15),
            child: const Icon(Icons.delete_outline, color: AppColors.bearish),
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: hasAlerts ? AppColors.bearish.withValues(alpha: 0.05) : c.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasAlerts ? AppColors.bearish.withValues(alpha: 0.4) : c.border,
                width: hasAlerts ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: hasAlerts
                          ? AppColors.bearish.withValues(alpha: 0.12)
                          : scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        symbol.substring(0, symbol.length > 2 ? 2 : symbol.length),
                        style: TextStyle(
                          color: hasAlerts ? AppColors.bearish : scheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(symbol, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                      if (hasAlerts) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.warning_amber_rounded, color: AppColors.bearish, size: 14),
                      ],
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (stock?.name != null)
                        Text(stock!.name, style: TextStyle(color: c.textMuted, fontSize: 12)),
                      Text(
                        'Added ${_formatDate(entry.addedAt)}'
                        '${entry.addedPrice != null ? ' @ ${_formatAddedPrice(entry.addedPrice!, stock?.market)}' : ''}',
                        style: TextStyle(color: c.textMuted, fontSize: 11),
                      ),
                      if (profitPct != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${profitPct >= 0 ? '+' : ''}${profitPct.toStringAsFixed(2)}% since added',
                          style: TextStyle(
                            color: profitColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ] else if (entry.addedPrice != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Sync data to see profit %',
                          style: TextStyle(color: c.textMuted, fontSize: 11),
                        ),
                      ],
                      if (entry.savedSignals.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          children: entry.savedSignals.map((s) => _SignalChip(saved: s)).toList(),
                        ),
                      ],
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (profitPct != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            '${profitPct >= 0 ? '+' : ''}${profitPct.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: profitColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (stock != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(stock!.market,
                              style: TextStyle(color: scheme.primary, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                      IconButton(
                        icon: Icon(Icons.bookmark, color: scheme.primary, size: 20),
                        onPressed: onRemove,
                        tooltip: 'Remove from watchlist',
                      ),
                    ],
                  ),
                ),
                // Alert detail rows
                if (hasAlerts)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Column(
                      children: [
                        Divider(height: 1, color: AppColors.bearish.withValues(alpha: 0.2)),
                        const SizedBox(height: 8),
                        ...alerts.map((a) => _AlertRow(alert: a, onDismiss: onDismissAlerts)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatAddedPrice(double price, String? market) {
    if (market == 'NSE' || market == 'BSE') {
      return '₹${price.toStringAsFixed(price >= 1000 ? 0 : 2)}';
    }
    return '\$${price.toStringAsFixed(2)}';
  }
}

// ── Small chips showing saved signals ─────────────────────────────────────────

class _SignalChip extends StatelessWidget {
  final SavedSignal saved;
  const _SignalChip({required this.saved});

  @override
  Widget build(BuildContext context) {
    final color = saved.signal == 'buy'
        ? AppColors.bullish
        : saved.signal == 'sell'
            ? AppColors.bearish
            : AppColors.neutral;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        saved.indicatorName,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Single alert row ───────────────────────────────────────────────────────────

class _AlertRow extends StatelessWidget {
  final WatchlistAlert alert;
  final VoidCallback onDismiss;
  const _AlertRow({required this.alert, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz_rounded, color: AppColors.bearish, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              alert.description,
              style: const TextStyle(color: AppColors.bearish, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close_rounded, color: c.textMuted, size: 14),
          ),
        ],
      ),
    );
  }
}
