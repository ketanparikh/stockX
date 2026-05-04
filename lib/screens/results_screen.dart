import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/screener_result.dart';
import '../providers/screener_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/stock_result_card.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final state = ref.watch(screenerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Results'),
            if (state.status == ScreenerStatus.success && state.results.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.bullish.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${state.results.length}',
                    style: const TextStyle(
                      color: AppColors.bullish,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          if (state.status == ScreenerStatus.success)
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => context.pop(),
              tooltip: 'Modify Filters',
            ),
        ],
      ),
      body: _buildBody(context, state, c),
    );
  }

  Widget _buildBody(BuildContext context, ScreenerState state, AppSurfaces c) {
    switch (state.status) {
      case ScreenerStatus.running:
        return _buildProgress(state, c);
      case ScreenerStatus.success:
        return state.results.isEmpty
            ? _buildEmpty(c)
            : _buildResults(context, state.results, c);
      case ScreenerStatus.error:
        return _buildError(state.errorMessage, c);
      case ScreenerStatus.idle:
        return _buildIdle(context, c);
    }
  }

  Widget _buildProgress(ScreenerState state, AppSurfaces c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: state.total > 0 ? state.progress : null,
                    strokeWidth: 4,
                    backgroundColor: c.border,
                    color: AppColors.primary,
                  ),
                  if (state.total > 0)
                    Text(
                      '${(state.progress * 100).toInt()}%',
                      style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Scanning stocks...',
              style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              state.total > 0
                  ? 'Analyzed ${state.processed} of ${state.total} stocks'
                  : 'Fetching stock data...',
              style: TextStyle(color: c.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Text(
              'Computing RSI, Supertrend, Chandelier Exit\nand other indicators...',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context, List<ScreenerResult> results, AppSurfaces c) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Icon(Icons.filter_list, color: c.textMuted, size: 16),
                const SizedBox(width: 6),
                Text('Sorted by match score', style: TextStyle(color: c.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => StockResultCard(
              result: results[index],
              onTap: () => context.push('/detail', extra: results[index]),
            ),
            childCount: results.length,
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }

  Widget _buildEmpty(AppSurfaces c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: c.surfaceVariant, shape: BoxShape.circle),
              child: Icon(Icons.search_off, color: c.textMuted, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              'No stocks matched',
              style: TextStyle(color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Try relaxing your filter conditions\nor switching to "ANY" match mode',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String? message, AppSurfaces c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.bearish, size: 56),
            const SizedBox(height: 16),
            Text(
              'Screener Error',
              style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdle(BuildContext context, AppSurfaces c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, color: c.textMuted, size: 56),
          const SizedBox(height: 16),
          Text(
            'Set your filters and run the screener',
            style: TextStyle(color: c.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Go to Screener'),
          ),
        ],
      ),
    );
  }
}
