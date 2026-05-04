import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/screener_result.dart';
import '../providers/watchlist_provider.dart';
import '../theme/app_colors.dart';

class StockResultCard extends ConsumerWidget {
  final ScreenerResult result;
  final VoidCallback? onTap;

  const StockResultCard({
    super.key,
    required this.result,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final quote = result.quote;
    final isWatched = ref.watch(watchlistProvider).contains(quote.symbol);
    final isPositive = quote.isPositive;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              quote.symbol,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                quote.market,
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          quote.name,
                          style: TextStyle(color: c.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(quote.sector, style: TextStyle(color: c.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              ref
                                  .read(watchlistEntriesProvider.notifier)
                                  .toggle(quote.symbol, result.indicators);
                            },
                            icon: Icon(
                              isWatched ? Icons.bookmark : Icons.bookmark_outline,
                              color: isWatched ? scheme.primary : c.textMuted,
                              size: 18,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          ),
                        ],
                      ),
                      Text(
                        _formatPrice(quote.price, quote.market),
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                            color: isPositive ? AppColors.bullish : AppColors.bearish,
                            size: 16,
                          ),
                          Text(
                            '${isPositive ? '+' : ''}${quote.changePercent.toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: isPositive ? AppColors.bullish : AppColors.bearish,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildMatchScore(),
                      const Spacer(),
                      Text(
                        '${result.matchingFilters}/${result.totalFilters} filters match',
                        style: TextStyle(color: c.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                  if (result.indicators.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: result.indicators.map((ind) => _buildIndicatorChip(ind)).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchScore() {
    final score = result.matchScore;
    final color = score >= 0.8
        ? AppColors.bullish
        : score >= 0.5
            ? AppColors.neutral
            : AppColors.bearish;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(
            '${(score * 100).toInt()}% match',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorChip(indicator) {
    final Color chipColor;
    if (indicator.isBuy) {
      chipColor = AppColors.bullish;
    } else if (indicator.isSell) {
      chipColor = AppColors.bearish;
    } else {
      chipColor = AppColors.neutral;
    }

    final int age = indicator.signalAge;
    final String ageLabel = age == 0 ? '⚡ Today' : '${age}d';
    final Color ageColor = age == 0
        ? AppColors.bullish
        : age <= 3
            ? AppColors.neutral
            : const Color(0xFF8888A0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: age == 0 ? chipColor.withValues(alpha: 0.6) : chipColor.withValues(alpha: 0.3),
          width: age == 0 ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            indicator.name,
            style: TextStyle(color: chipColor, fontSize: 11, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          Text(
            ageLabel,
            style: TextStyle(
              color: ageColor,
              fontSize: 9,
              fontWeight: age == 0 ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price, String market) {
    if (market == 'NSE' || market == 'BSE') return '₹${price.toStringAsFixed(2)}';
    return '\$${price.toStringAsFixed(2)}';
  }
}
