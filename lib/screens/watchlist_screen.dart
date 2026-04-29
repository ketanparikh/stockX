import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/watchlist_provider.dart';
import '../theme/app_colors.dart';
import '../utils/stock_symbols.dart';

class WatchlistScreen extends ConsumerWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchlist = ref.watch(watchlistProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watchlist'),
        actions: [
          if (watchlist.isNotEmpty)
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.card,
                    title: const Text(
                      'Clear Watchlist',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    content: const Text(
                      'Remove all stocks from your watchlist?',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          for (final sym in watchlist.toList()) {
                            ref.read(watchlistProvider.notifier).remove(sym);
                          }
                          Navigator.pop(ctx);
                        },
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.bearish),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Clear All'),
            ),
        ],
      ),
      body: watchlist.isEmpty
          ? _buildEmpty()
          : _buildWatchlist(context, ref, watchlist.toList()),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bookmark_outline,
              color: AppColors.textMuted,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Your watchlist is empty',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bookmark stocks from the screener results\nto track them here',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchlist(
    BuildContext context,
    WidgetRef ref,
    List<String> symbols,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: symbols.length,
      itemBuilder: (context, index) {
        final symbol = symbols[index];
        // Find stock info
        StockSymbol? stock;
        try {
          stock = StockUniverse.getAll().firstWhere((s) => s.symbol == symbol);
        } catch (_) {}

        return Dismissible(
          key: Key(symbol),
          direction: DismissDirection.endToStart,
          onDismissed: (_) {
            ref.read(watchlistProvider.notifier).remove(symbol);
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: AppColors.bearish.withOpacity(0.15),
            child: const Icon(Icons.delete_outline, color: AppColors.bearish),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  symbol.substring(0, symbol.length > 2 ? 2 : symbol.length),
                  style: const TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            title: Text(
              symbol,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              stock?.name ?? '',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (stock != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      stock.market,
                      style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.bookmark,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  onPressed: () {
                    ref.read(watchlistProvider.notifier).remove(symbol);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
