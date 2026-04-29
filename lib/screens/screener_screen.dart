import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/screener_filter.dart';
import '../providers/screener_provider.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';
import '../utils/stock_symbols.dart';
import '../widgets/filter_section.dart';

class ScreenerScreen extends ConsumerStatefulWidget {
  const ScreenerScreen({super.key});

  @override
  ConsumerState<ScreenerScreen> createState() => _ScreenerScreenState();
}

class _ScreenerScreenState extends ConsumerState<ScreenerScreen> {
  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(screenerFilterProvider);
    final screenerState = ref.watch(screenerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Screener'),
        actions: [
          TextButton.icon(
            onPressed: () {
              ref.read(screenerFilterProvider.notifier).reset();
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reset'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _buildMarketSection(filter),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _buildTimeframeSection(filter),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _buildSectorSection(filter),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _buildFilterMatchMode(filter),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _buildFreshSignalSection(filter),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _buildSectionHeader('Technical Indicators'),
                ),
              ),
              // RSI Filter
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                sliver: SliverToBoxAdapter(child: _buildRsiFilter(filter)),
              ),
              // Supertrend Filter
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                sliver: SliverToBoxAdapter(child: _buildSupertrendFilter(filter)),
              ),
              // Chandelier Exit Filter
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                sliver: SliverToBoxAdapter(child: _buildChandelierFilter(filter)),
              ),
              // MACD Filter
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                sliver: SliverToBoxAdapter(child: _buildMacdFilter(filter)),
              ),
              // EMA Crossover Filter
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                sliver: SliverToBoxAdapter(child: _buildEmaFilter(filter)),
              ),
              // Bollinger Bands Filter
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                sliver: SliverToBoxAdapter(child: _buildBollingerFilter(filter)),
              ),
              // ADX Filter
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                sliver: SliverToBoxAdapter(child: _buildAdxFilter(filter)),
              ),
              const SliverPadding(
                padding: EdgeInsets.only(bottom: 120),
                sliver: SliverToBoxAdapter(child: SizedBox()),
              ),
            ],
          ),
          // Run screener button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildRunButton(filter, screenerState),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMarketSection(ScreenerFilter filter) {
    const markets = ['NSE', 'BSE', 'US'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('MARKET'),
        const SizedBox(height: 6),
        Row(
          children: markets.map((market) {
            final selected = filter.markets.contains(market);
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  ref.read(screenerFilterProvider.notifier).toggleMarket(market);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withOpacity(0.15)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    market,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? AppColors.primaryLight : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTimeframeSection(ScreenerFilter filter) {
    final timeframes = [
      (Timeframe.daily, 'Daily'),
      (Timeframe.weekly, 'Weekly'),
      (Timeframe.monthly, 'Monthly'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('TIMEFRAME'),
        const SizedBox(height: 6),
        Row(
          children: timeframes.map(((String, String) tf) {
            final selected = filter.timeframe == tf.$1;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  ref.read(screenerFilterProvider.notifier).setTimeframe(tf.$1);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accent.withOpacity(0.12)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppColors.accent : AppColors.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    tf.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? AppColors.accent : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSectorSection(ScreenerFilter filter) {
    // Get sectors relevant to selected markets
    final availableStocks = StockUniverse.getAll().where(
      (s) => filter.markets.contains(s.market),
    );
    final sectors = availableStocks.map((s) => s.sector).toSet().toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('SECTOR (optional)'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            GestureDetector(
              onTap: () {
                ref.read(screenerFilterProvider.notifier).updateSectors({});
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: filter.sectors.isEmpty
                      ? AppColors.primary.withOpacity(0.15)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: filter.sectors.isEmpty
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  'All',
                  style: TextStyle(
                    color: filter.sectors.isEmpty
                        ? AppColors.primaryLight
                        : AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: filter.sectors.isEmpty
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            ),
            ...sectors.map((sector) {
              final selected = filter.sectors.contains(sector);
              return GestureDetector(
                onTap: () {
                  ref.read(screenerFilterProvider.notifier).toggleSector(sector);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withOpacity(0.15)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    sector,
                    style: TextStyle(
                      color: selected
                          ? AppColors.primaryLight
                          : AppColors.textMuted,
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterMatchMode(ScreenerFilter filter) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter Match Mode',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Require all filters or any single filter to match',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: true,
                label: Text('ALL', style: TextStyle(fontSize: 11)),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text('ANY', style: TextStyle(fontSize: 11)),
              ),
            ],
            selected: {filter.requireAllFilters},
            onSelectionChanged: (sel) {
              ref
                  .read(screenerFilterProvider.notifier)
                  .setRequireAllFilters(sel.first);
            },
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Fresh Signals ──────────────────────────────────────────────────────────

  Widget _buildFreshSignalSection(ScreenerFilter filter) {
    final notifier = ref.read(screenerFilterProvider.notifier);
    final active = filter.requireFreshSignal;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: active ? AppColors.card : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? AppColors.accent.withOpacity(0.5) : AppColors.border,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.accent.withOpacity(0.15)
                        : AppColors.border.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.bolt_rounded,
                    size: 18,
                    color: active ? AppColors.accent : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fresh Signals Only',
                        style: TextStyle(
                          color: active
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        active
                            ? 'Signal must have triggered within ${filter.freshSignalMaxBars} bar${filter.freshSignalMaxBars == 1 ? '' : 's'}'
                            : 'Find stocks where conditions just triggered',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: active,
                  onChanged: notifier.setRequireFreshSignal,
                  activeColor: AppColors.accent,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
          if (active) ...[
            const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Signal triggered within',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          filter.freshSignalMaxBars == 0
                              ? 'Today only'
                              : '${filter.freshSignalMaxBars} bar${filter.freshSignalMaxBars == 1 ? '' : 's'} ago',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(trackHeight: 3),
                    child: Slider(
                      value: filter.freshSignalMaxBars.toDouble(),
                      min: 0,
                      max: 10,
                      divisions: 10,
                      activeColor: AppColors.accent,
                      onChanged: (v) =>
                          notifier.setFreshSignalMaxBars(v.toInt()),
                    ),
                  ),
                  // Quick-select chips
                  Wrap(
                    spacing: 6,
                    children: [0, 1, 3, 5, 10].map((days) {
                      final sel = filter.freshSignalMaxBars == days;
                      return GestureDetector(
                        onTap: () => notifier.setFreshSignalMaxBars(days),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.accent.withOpacity(0.15)
                                : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: sel ? AppColors.accent : AppColors.border,
                            ),
                          ),
                          child: Text(
                            days == 0 ? 'Today' : '≤ $days bar${days == 1 ? '' : 's'}',
                            style: TextStyle(
                              color:
                                  sel ? AppColors.accent : AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: sel
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRsiFilter(ScreenerFilter filter) {
    final p = filter.rsiParams;
    final notifier = ref.read(screenerFilterProvider.notifier);

    return FilterSection(
      title: 'RSI',
      icon: Icons.show_chart,
      description: 'Relative Strength Index (momentum oscillator)',
      enabled: filter.useRsi,
      onToggle: (v) => notifier.toggleRsi(v),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Standard signal ──────────────────────────────────────────────
          _buildSubLabel('Signal Zone'),
          const SizedBox(height: 6),
          SignalSelector(
            value: p.signal,
            onChanged: (s) => notifier.updateRsiParams(p.copyWith(signal: s)),
            options: const ['ANY', 'BUY', 'SELL', 'NEUTRAL'],
          ),
          const SizedBox(height: 10),
          LabeledSlider(
            label: p.useDualRsi ? 'Fast RSI Period' : 'Period',
            value: p.period.toDouble(),
            min: 5,
            max: 50,
            divisions: 45,
            onChanged: (v) =>
                notifier.updateRsiParams(p.copyWith(period: v.toInt())),
          ),
          LabeledSlider(
            label: 'Oversold Level',
            value: p.oversoldLevel,
            min: 10,
            max: 40,
            divisions: 30,
            onChanged: (v) =>
                notifier.updateRsiParams(p.copyWith(oversoldLevel: v)),
          ),
          LabeledSlider(
            label: 'Overbought Level',
            value: p.overboughtLevel,
            min: 60,
            max: 90,
            divisions: 30,
            onChanged: (v) =>
                notifier.updateRsiParams(p.copyWith(overboughtLevel: v)),
          ),

          // ── Dual RSI crossover ────────────────────────────────────────────
          const SizedBox(height: 12),
          _buildDualRsiToggle(p, notifier),

          if (p.useDualRsi) ...[
            const SizedBox(height: 12),
            _buildSubLabel('Crossover Direction'),
            const SizedBox(height: 6),
            _buildCrossoverSelector(p, notifier),
            const SizedBox(height: 10),
            LabeledSlider(
              label: 'Slow RSI Period',
              value: p.slowPeriod.toDouble(),
              min: 20,
              max: 200,
              divisions: 36,
              formatter: (v) => v.toInt().toString(),
              onChanged: (v) =>
                  notifier.updateRsiParams(p.copyWith(slowPeriod: v.toInt())),
            ),
            _buildDualRsiHint(p),
          ],
        ],
      ),
    );
  }

  Widget _buildSubLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _buildDualRsiToggle(
    RsiFilterParams p,
    ScreenerFilterNotifier notifier,
  ) {
    return GestureDetector(
      onTap: () => notifier.updateRsiParams(p.copyWith(useDualRsi: !p.useDualRsi)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: p.useDualRsi
              ? AppColors.accent.withOpacity(0.1)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: p.useDualRsi ? AppColors.accent : AppColors.border,
            width: p.useDualRsi ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.compare_arrows_rounded,
              size: 18,
              color: p.useDualRsi ? AppColors.accent : AppColors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compare RSI Periods',
                    style: TextStyle(
                      color: p.useDualRsi
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Filter by fast RSI vs slow RSI crossover',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: p.useDualRsi,
              onChanged: (v) =>
                  notifier.updateRsiParams(p.copyWith(useDualRsi: v)),
              activeColor: AppColors.accent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrossoverSelector(
    RsiFilterParams p,
    ScreenerFilterNotifier notifier,
  ) {
    const options = [
      (RsiCrossover.fastAboveSlow, 'Fast > Slow', Icons.arrow_upward),
      (RsiCrossover.fastBelowSlow, 'Fast < Slow', Icons.arrow_downward),
      (RsiCrossover.any,           'Either',       Icons.swap_vert),
    ];

    return Row(
      children: options.map(((String, String, IconData) opt) {
        final isSelected = p.crossover == opt.$1;
        final color = opt.$1 == RsiCrossover.fastAboveSlow
            ? AppColors.bullish
            : opt.$1 == RsiCrossover.fastBelowSlow
                ? AppColors.bearish
                : AppColors.neutral;

        return Expanded(
          child: GestureDetector(
            onTap: () =>
                notifier.updateRsiParams(p.copyWith(crossover: opt.$1)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withOpacity(0.13)
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? color : AppColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    opt.$3,
                    size: 16,
                    color: isSelected ? color : AppColors.textMuted,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    opt.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? color : AppColors.textMuted,
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDualRsiHint(RsiFilterParams p) {
    final crossoverLabel = p.crossover == RsiCrossover.fastAboveSlow
        ? 'RSI(${p.period}) > RSI(${p.slowPeriod})'
        : p.crossover == RsiCrossover.fastBelowSlow
            ? 'RSI(${p.period}) < RSI(${p.slowPeriod})'
            : 'RSI(${p.period}) vs RSI(${p.slowPeriod}) — any';

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Screening for: $crossoverLabel',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupertrendFilter(ScreenerFilter filter) {
    return FilterSection(
      title: 'Supertrend',
      icon: Icons.trending_up,
      description: 'ATR-based trend direction indicator',
      enabled: filter.useSupertrend,
      onToggle: (v) =>
          ref.read(screenerFilterProvider.notifier).toggleSupertrend(v),
      child: Column(
        children: [
          SignalSelector(
            value: filter.supertrendParams.signal,
            onChanged: (s) => ref.read(screenerFilterProvider.notifier).updateSupertrendParams(
                  filter.supertrendParams.copyWith(signal: s),
                ),
          ),
          const SizedBox(height: 10),
          LabeledSlider(
            label: 'ATR Period',
            value: filter.supertrendParams.period.toDouble(),
            min: 5,
            max: 20,
            divisions: 15,
            onChanged: (v) => ref.read(screenerFilterProvider.notifier).updateSupertrendParams(
                  filter.supertrendParams.copyWith(period: v.toInt()),
                ),
          ),
          LabeledSlider(
            label: 'Multiplier',
            value: filter.supertrendParams.multiplier,
            min: 1.0,
            max: 6.0,
            divisions: 10,
            formatter: (v) => v.toStringAsFixed(1),
            onChanged: (v) => ref.read(screenerFilterProvider.notifier).updateSupertrendParams(
                  filter.supertrendParams.copyWith(multiplier: v),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildChandelierFilter(ScreenerFilter filter) {
    return FilterSection(
      title: 'Chandelier Exit',
      icon: Icons.candlestick_chart,
      description: 'Volatility-based stop-loss system',
      enabled: filter.useChandelier,
      onToggle: (v) =>
          ref.read(screenerFilterProvider.notifier).toggleChandelier(v),
      child: Column(
        children: [
          SignalSelector(
            value: filter.chandelierParams.signal,
            onChanged: (s) => ref.read(screenerFilterProvider.notifier).updateChandelierParams(
                  filter.chandelierParams.copyWith(signal: s),
                ),
            options: const ['ANY', 'BUY', 'SELL', 'NEUTRAL'],
          ),
          const SizedBox(height: 10),
          LabeledSlider(
            label: 'Period',
            value: filter.chandelierParams.period.toDouble(),
            min: 10,
            max: 50,
            divisions: 40,
            onChanged: (v) => ref.read(screenerFilterProvider.notifier).updateChandelierParams(
                  filter.chandelierParams.copyWith(period: v.toInt()),
                ),
          ),
          LabeledSlider(
            label: 'ATR Multiplier',
            value: filter.chandelierParams.multiplier,
            min: 1.0,
            max: 6.0,
            divisions: 10,
            formatter: (v) => v.toStringAsFixed(1),
            onChanged: (v) => ref.read(screenerFilterProvider.notifier).updateChandelierParams(
                  filter.chandelierParams.copyWith(multiplier: v),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacdFilter(ScreenerFilter filter) {
    return FilterSection(
      title: 'MACD',
      icon: Icons.bar_chart,
      description: 'Moving Average Convergence Divergence',
      enabled: filter.useMacd,
      onToggle: (v) => ref.read(screenerFilterProvider.notifier).toggleMacd(v),
      child: Column(
        children: [
          SignalSelector(
            value: filter.macdParams.signal,
            onChanged: (s) => ref.read(screenerFilterProvider.notifier).updateMacdParams(
                  filter.macdParams.copyWith(signal: s),
                ),
          ),
          const SizedBox(height: 10),
          LabeledSlider(
            label: 'Fast Period',
            value: filter.macdParams.fastPeriod.toDouble(),
            min: 5,
            max: 20,
            divisions: 15,
            onChanged: (v) => ref.read(screenerFilterProvider.notifier).updateMacdParams(
                  filter.macdParams.copyWith(fastPeriod: v.toInt()),
                ),
          ),
          LabeledSlider(
            label: 'Slow Period',
            value: filter.macdParams.slowPeriod.toDouble(),
            min: 15,
            max: 50,
            divisions: 35,
            onChanged: (v) => ref.read(screenerFilterProvider.notifier).updateMacdParams(
                  filter.macdParams.copyWith(slowPeriod: v.toInt()),
                ),
          ),
          LabeledSlider(
            label: 'Signal Period',
            value: filter.macdParams.signalPeriod.toDouble(),
            min: 5,
            max: 20,
            divisions: 15,
            onChanged: (v) => ref.read(screenerFilterProvider.notifier).updateMacdParams(
                  filter.macdParams.copyWith(signalPeriod: v.toInt()),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmaFilter(ScreenerFilter filter) {
    return FilterSection(
      title: 'EMA Crossover',
      icon: Icons.swap_vert,
      description: 'Exponential Moving Average crossover signal',
      enabled: filter.useEma,
      onToggle: (v) => ref.read(screenerFilterProvider.notifier).toggleEma(v),
      child: Column(
        children: [
          SignalSelector(
            value: filter.emaParams.signal,
            onChanged: (s) => ref.read(screenerFilterProvider.notifier).updateEmaParams(
                  filter.emaParams.copyWith(signal: s),
                ),
          ),
          const SizedBox(height: 10),
          LabeledSlider(
            label: 'Fast EMA Period',
            value: filter.emaParams.fastPeriod.toDouble(),
            min: 5,
            max: 50,
            divisions: 45,
            onChanged: (v) => ref.read(screenerFilterProvider.notifier).updateEmaParams(
                  filter.emaParams.copyWith(fastPeriod: v.toInt()),
                ),
          ),
          LabeledSlider(
            label: 'Slow EMA Period',
            value: filter.emaParams.slowPeriod.toDouble(),
            min: 20,
            max: 200,
            divisions: 36,
            onChanged: (v) => ref.read(screenerFilterProvider.notifier).updateEmaParams(
                  filter.emaParams.copyWith(slowPeriod: v.toInt()),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBollingerFilter(ScreenerFilter filter) {
    return FilterSection(
      title: 'Bollinger Bands',
      icon: Icons.compress,
      description: 'Price position relative to volatility bands',
      enabled: filter.useBollinger,
      onToggle: (v) =>
          ref.read(screenerFilterProvider.notifier).toggleBollinger(v),
      child: Column(
        children: [
          SignalSelector(
            value: filter.bollingerParams.signal,
            onChanged: (s) => ref.read(screenerFilterProvider.notifier).updateBollingerParams(
                  filter.bollingerParams.copyWith(signal: s),
                ),
            options: const ['ANY', 'BUY', 'SELL', 'NEUTRAL'],
          ),
          const SizedBox(height: 10),
          LabeledSlider(
            label: 'Period',
            value: filter.bollingerParams.period.toDouble(),
            min: 10,
            max: 50,
            divisions: 40,
            onChanged: (v) => ref.read(screenerFilterProvider.notifier).updateBollingerParams(
                  filter.bollingerParams.copyWith(period: v.toInt()),
                ),
          ),
          LabeledSlider(
            label: 'Std Dev Multiplier',
            value: filter.bollingerParams.stdDev,
            min: 1.0,
            max: 3.5,
            divisions: 5,
            formatter: (v) => v.toStringAsFixed(1),
            onChanged: (v) => ref.read(screenerFilterProvider.notifier).updateBollingerParams(
                  filter.bollingerParams.copyWith(stdDev: v),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdxFilter(ScreenerFilter filter) {
    return FilterSection(
      title: 'ADX',
      icon: Icons.speed,
      description: 'Average Directional Index (trend strength)',
      enabled: filter.useAdx,
      onToggle: (v) => ref.read(screenerFilterProvider.notifier).toggleAdx(v),
      child: Column(
        children: [
          SignalSelector(
            value: filter.adxParams.signal,
            onChanged: (s) => ref.read(screenerFilterProvider.notifier).updateAdxParams(
                  filter.adxParams.copyWith(signal: s),
                ),
            options: const ['ANY', 'BUY', 'SELL', 'NEUTRAL'],
          ),
          const SizedBox(height: 10),
          LabeledSlider(
            label: 'Period',
            value: filter.adxParams.period.toDouble(),
            min: 7,
            max: 30,
            divisions: 23,
            onChanged: (v) => ref.read(screenerFilterProvider.notifier).updateAdxParams(
                  filter.adxParams.copyWith(period: v.toInt()),
                ),
          ),
          LabeledSlider(
            label: 'Min ADX Strength',
            value: filter.adxParams.minAdx,
            min: 10,
            max: 50,
            divisions: 40,
            onChanged: (v) => ref.read(screenerFilterProvider.notifier).updateAdxParams(
                  filter.adxParams.copyWith(minAdx: v),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunButton(ScreenerFilter filter, ScreenerState screenerState) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background.withOpacity(0),
            AppColors.background,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (filter.activeFilterCount > 0)
              Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '${filter.activeFilterCount} filter${filter.activeFilterCount > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: screenerState.isRunning || !filter.hasAnyFilter
                    ? null
                    : () {
                        ref.read(screenerProvider.notifier).runScreener(filter);
                        context.push('/results');
                      },
                icon: screenerState.isRunning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search, size: 18),
                label: Text(
                  screenerState.isRunning ? 'Scanning...' : 'Run Screener',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  disabledBackgroundColor: AppColors.border,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
