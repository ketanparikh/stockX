import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/screener_filter.dart';
import '../models/screener_result.dart';
import '../models/stock_search_analysis.dart';
import '../providers/screener_provider.dart';
import '../providers/watchlist_provider.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';
import '../utils/stock_symbols.dart';
import '../widgets/indicator_tile.dart';
import '../widgets/signal_badge.dart';

class StockSearchScreen extends ConsumerStatefulWidget {
  const StockSearchScreen({super.key});

  @override
  ConsumerState<StockSearchScreen> createState() => _StockSearchScreenState();
}

class _StockSearchScreenState extends ConsumerState<StockSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  List<StockSymbol> _suggestions = [];
  StockSearchAnalysis? _analysis;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    setState(() {
      _suggestions = StockUniverse.search(_controller.text);
    });
  }

  Future<void> _analyze(StockSymbol stock) async {
    _controller.text = stock.symbol;
    _focusNode.unfocus();
    setState(() {
      _suggestions = [];
      _isLoading = true;
      _error = null;
      _analysis = null;
    });

    final filter = ref.read(screenerFilterProvider);
    try {
      final analysis = await ref
          .read(screenerServiceProvider)
          .analyzeStockSearch(stock, filter);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (analysis == null) {
          _error = 'Could not load price data for ${stock.symbol}. '
              'Try syncing data first.';
        } else {
          _analysis = analysis;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _submitQuery() {
    final stock = StockUniverse.resolve(_controller.text);
    if (stock == null) {
      setState(() {
        _error = 'Symbol not found. Pick from suggestions or check spelling.';
      });
      return;
    }
    _analyze(stock);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final filter = ref.watch(screenerFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Stock'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submitQuery(),
              decoration: InputDecoration(
                hintText: 'Symbol or name (e.g. BEPL, Reliance)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _controller.clear();
                          setState(() {
                            _analysis = null;
                            _error = null;
                            _suggestions = [];
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_suggestions.isNotEmpty && _analysis == null && !_isLoading)
            Flexible(
              flex: 0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final stock = _suggestions[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        stock.symbol,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${stock.name} · ${stock.market}',
                        style: TextStyle(color: c.textMuted, fontSize: 12),
                      ),
                      onTap: () => _analyze(stock),
                    );
                  },
                ),
              ),
            ),
          Expanded(
            child: _buildBody(c, filter),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppSurfaces c, ScreenerFilter filter) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Computing indicators…',
              style: TextStyle(color: c.textMuted),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary),
          ),
        ),
      );
    }

    if (_analysis == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.manage_search_rounded, size: 48, color: c.textMuted),
              const SizedBox(height: 12),
              Text(
                'Search a stock to see which screener filters apply',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Uses your current filter settings (${Timeframe.label(filter.timeframe)} chart)',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return _buildAnalysis(c, _analysis!, filter);
  }

  Widget _buildAnalysis(
    AppSurfaces c,
    StockSearchAnalysis analysis,
    ScreenerFilter filter,
  ) {
    final quote = analysis.result.quote;
    final isPositive = quote.isPositive;
    final scheme = Theme.of(context).colorScheme;

    final applicable = analysis.statuses
        .where((s) => s.isFilterEnabled && s.matchesFilter)
        .toList();
    final notApplicable = analysis.statuses
        .where((s) => s.isFilterEnabled && !s.matchesFilter)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _buildQuoteCard(c, quote, isPositive, analysis, filter),
        const SizedBox(height: 16),
        if (analysis.hasActiveFilters) ...[
          _buildVerdictBanner(c, analysis, filter),
          const SizedBox(height: 16),
          if (applicable.isNotEmpty) ...[
            _sectionTitle(c, 'Matching filters (${applicable.length})'),
            const SizedBox(height: 8),
            ...applicable.map((s) => _FilterStatusTile(status: s)),
            const SizedBox(height: 16),
          ],
          if (notApplicable.isNotEmpty) ...[
            _sectionTitle(c, 'Not matching (${notApplicable.length})'),
            const SizedBox(height: 8),
            ...notApplicable.map((s) => _FilterStatusTile(status: s)),
            const SizedBox(height: 16),
          ],
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child: Text(
              'No screener filters are enabled. Showing all indicator signals below.',
              style: TextStyle(color: c.textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/detail', extra: analysis.result),
                icon: const Icon(Icons.candlestick_chart_outlined, size: 18),
                label: const Text('Full chart'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => context.pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                ),
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Adjust filters'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionTitle(c, 'All indicators'),
        const SizedBox(height: 8),
        ...analysis.result.indicators.map(
          (ind) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: IndicatorTile(indicator: ind),
          ),
        ),
      ],
    );
  }

  Widget _buildQuoteCard(
    AppSurfaces c,
    StockQuote quote,
    bool isPositive,
    StockSearchAnalysis analysis,
    ScreenerFilter filter,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isWatched = ref.watch(watchlistProvider).contains(quote.symbol);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quote.symbol,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      quote.name,
                      style: TextStyle(color: c.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  final wasWatched = isWatched;
                  ref.read(watchlistEntriesProvider.notifier).toggle(
                        quote.symbol,
                        analysis.result.indicators,
                        quote.price,
                      );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        wasWatched
                            ? '${quote.symbol} removed from watchlist'
                            : '${quote.symbol} added to watchlist',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: Icon(
                  isWatched ? Icons.bookmark : Icons.bookmark_outline,
                  color: isWatched ? scheme.primary : c.textMuted,
                ),
                tooltip: isWatched ? 'Remove from watchlist' : 'Add to watchlist',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatPrice(quote.price, quote.market),
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${isPositive ? '+' : ''}${quote.changePercent.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: isPositive ? AppColors.bullish : AppColors.bearish,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${quote.market} · ${Timeframe.label(filter.timeframe)}',
            style: TextStyle(color: c.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildVerdictBanner(
    AppSurfaces c,
    StockSearchAnalysis analysis,
    ScreenerFilter filter,
  ) {
    final pass = analysis.passesScreener;
    final color = pass ? AppColors.bullish : AppColors.bearish;
    final mode = filter.requireAllFilters ? 'ALL filters' : 'ANY filter';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(
            pass ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pass ? 'Passes screener' : 'Does not pass screener',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${analysis.matchingCount} of ${analysis.activeFilterCount} active filters match ($mode)',
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
                if (filter.requireFreshSignal)
                  Text(
                    'Fresh signal required (≤${filter.freshSignalMaxBars} bars)',
                    style: TextStyle(color: c.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(AppSurfaces c, String title) {
    return Text(
      title,
      style: TextStyle(
        color: c.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  String _formatPrice(double price, String market) {
    if (market == 'NSE' || market == 'BSE') {
      return '₹${price.toStringAsFixed(price >= 1000 ? 0 : 2)}';
    }
    return '\$${price.toStringAsFixed(2)}';
  }
}

class _FilterStatusTile extends StatelessWidget {
  const _FilterStatusTile({required this.status});

  final IndicatorFilterStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final ind = status.indicator;
    final matchColor =
        status.matchesFilter ? AppColors.bullish : AppColors.bearish;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status.matchesFilter
              ? AppColors.bullish.withValues(alpha: 0.4)
              : c.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            status.matchesFilter ? Icons.check_circle : Icons.remove_circle_outline,
            color: matchColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ind.name,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  status.criteriaLabel,
                  style: TextStyle(color: c.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  ind.description,
                  style: TextStyle(color: c.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SignalBadge(signal: ind.signal, fontSize: 10),
              const SizedBox(height: 6),
              _AgeChip(age: ind.signalAge),
            ],
          ),
        ],
      ),
    );
  }
}

class _AgeChip extends StatelessWidget {
  const _AgeChip({required this.age});

  final int age;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final label = age == 0 ? 'Today' : age == 1 ? '1 day' : '$age days';
    final color = age == 0
        ? AppColors.bullish
        : age <= 3
            ? AppColors.neutral
            : c.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
