import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/candle_data.dart';
import '../models/screener_result.dart';
import '../providers/watchlist_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/indicator_tile.dart';

class StockDetailScreen extends ConsumerWidget {
  final ScreenerResult result;

  const StockDetailScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quote = result.quote;
    final isWatched = ref.watch(watchlistProvider).contains(quote.symbol);
    final isPositive = quote.isPositive;

    return Scaffold(
      appBar: AppBar(
        title: Text(quote.symbol),
        actions: [
          IconButton(
            onPressed: () {
              ref.read(watchlistProvider.notifier).toggle(quote.symbol);
            },
            icon: Icon(
              isWatched ? Icons.bookmark : Icons.bookmark_outline,
              color: isWatched ? AppColors.primary : AppColors.textSecondary,
            ),
            tooltip: isWatched ? 'Remove from Watchlist' : 'Add to Watchlist',
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Price header
          SliverToBoxAdapter(
            child: _buildPriceHeader(quote, isPositive),
          ),
          // Chart
          if (result.candles.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildPriceChart(result.candles, isPositive),
            ),
          // Indicators
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: SliverToBoxAdapter(
              child: _buildSectionTitle('Technical Indicators'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: IndicatorTile(indicator: result.indicators[index]),
                ),
                childCount: result.indicators.length,
              ),
            ),
          ),
          // Market Details
          if (quote.marketCap != null || quote.week52High != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: _buildMarketDetails(quote),
              ),
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  Widget _buildPriceHeader(StockQuote quote, bool isPositive) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quote.name,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatPrice(quote.price, quote.market),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isPositive ? AppColors.bullish : AppColors.bearish,
                      size: 16,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${isPositive ? '+' : ''}${_formatPrice(quote.change, quote.market)} (${quote.changePercent.toStringAsFixed(2)}%)',
                      style: TextStyle(
                        color: isPositive ? AppColors.bullish : AppColors.bearish,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildTag(quote.market, AppColors.primary),
              const SizedBox(width: 6),
              _buildTag(quote.sector, AppColors.accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPriceChart(List<CandleData> candles, bool isPositive) {
    final chartCandles = candles.length > 90 ? candles.sublist(candles.length - 90) : candles;
    final prices = chartCandles.map((c) => c.close).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final color = isPositive ? AppColors.bullish : AppColors.bearish;

    final spots = List.generate(
      prices.length,
      (i) => FlSpot(i.toDouble(), prices[i]),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxPrice - minPrice) / 4,
            getDrawingHorizontalLine: (v) => const FlLine(
              color: AppColors.divider,
              strokeWidth: 0.5,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 56,
                getTitlesWidget: (value, meta) {
                  return Text(
                    _formatCompact(value),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          minY: minPrice * 0.995,
          maxY: maxPrice * 1.005,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withOpacity(0.25),
                    color.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.card,
              tooltipBorder: const BorderSide(color: AppColors.border),
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        _formatPrice(s.y, 'NSE'),
                        const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMarketDetails(StockQuote quote) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Market Details',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (quote.week52High != null)
                Expanded(
                  child: _buildDetailItem(
                    '52W High',
                    _formatPrice(quote.week52High!, quote.market),
                    AppColors.bullish,
                  ),
                ),
              if (quote.week52Low != null)
                Expanded(
                  child: _buildDetailItem(
                    '52W Low',
                    _formatPrice(quote.week52Low!, quote.market),
                    AppColors.bearish,
                  ),
                ),
              if (quote.marketCap != null)
                Expanded(
                  child: _buildDetailItem(
                    'Market Cap',
                    _formatMarketCap(quote.marketCap!),
                    AppColors.accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDetailItem(
            'Volume',
            _formatVolume(quote.volume),
            AppColors.textSecondary,
            isRow: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(
    String label,
    String value,
    Color color, {
    bool isRow = false,
  }) {
    if (isRow) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _formatPrice(double price, String market) {
    if (market == 'NSE' || market == 'BSE') {
      if (price >= 1000) return '₹${price.toStringAsFixed(0)}';
      return '₹${price.toStringAsFixed(2)}';
    }
    return '\$${price.toStringAsFixed(2)}';
  }

  String _formatCompact(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  String _formatMarketCap(double cap) {
    if (cap >= 1e12) return '₹${(cap / 1e12).toStringAsFixed(2)}T';
    if (cap >= 1e9) return '₹${(cap / 1e9).toStringAsFixed(2)}B';
    if (cap >= 1e6) return '₹${(cap / 1e6).toStringAsFixed(2)}M';
    return '₹${cap.toStringAsFixed(0)}';
  }

  String _formatVolume(double vol) {
    if (vol >= 1e7) return '${(vol / 1e7).toStringAsFixed(2)}Cr';
    if (vol >= 1e5) return '${(vol / 1e5).toStringAsFixed(2)}L';
    if (vol >= 1e3) return '${(vol / 1e3).toStringAsFixed(0)}K';
    return vol.toStringAsFixed(0);
  }
}
