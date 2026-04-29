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
                    color: AppColors.bullish.withOpacity(0.15),
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
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, ScreenerState state) {
    switch (state.status) {
      case ScreenerStatus.running:
        return _buildProgress(state);
      case ScreenerStatus.success:
        return state.results.isEmpty
            ? _buildEmpty()
            : _buildResults(context, state.results);
      case ScreenerStatus.error:
        return _buildError(state.errorMessage);
      case ScreenerStatus.idle:
        return _buildIdle(context);
    }
  }

  Widget _buildProgress(ScreenerState state) {
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
                    backgroundColor: AppColors.border,
                    color: AppColors.primary,
                  ),
                  if (state.total > 0)
                    Text(
                      '${(state.progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Scanning stocks...',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.total > 0
                  ? 'Analyzed ${state.processed} of ${state.total} stocks'
                  : 'Fetching stock data...',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Computing RSI, Supertrend, Chandelier Exit\nand other indicators...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context, List<ScreenerResult> results) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                const Icon(Icons.filter_list, color: AppColors.textMuted, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Sorted by match score',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
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

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
                Icons.search_off,
                color: AppColors.textMuted,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No stocks matched',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try relaxing your filter conditions\nor switching to "ANY" match mode',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String? message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.bearish, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Screener Error',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdle(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search, color: AppColors.textMuted, size: 56),
          const SizedBox(height: 16),
          const Text(
            'Set your filters and run the screener',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
