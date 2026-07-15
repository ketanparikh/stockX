import 'indicator_result.dart';
import 'screener_result.dart';

/// Per-indicator status when checking a single stock against screener filters.
class IndicatorFilterStatus {
  const IndicatorFilterStatus({
    required this.indicator,
    required this.criteriaLabel,
    required this.isFilterEnabled,
    required this.matchesFilter,
  });

  final IndicatorResult indicator;
  final String criteriaLabel;
  final bool isFilterEnabled;
  final bool matchesFilter;
}

/// Result of looking up one stock against the current screener configuration.
class StockSearchAnalysis {
  const StockSearchAnalysis({
    required this.result,
    required this.statuses,
    required this.passesScreener,
    required this.hasActiveFilters,
    this.qualityPasses,
    this.qualityCriteriaLabel,
  });

  final ScreenerResult result;
  final List<IndicatorFilterStatus> statuses;
  final bool passesScreener;
  final bool hasActiveFilters;
  final bool? qualityPasses;
  final String? qualityCriteriaLabel;

  int get matchingCount =>
      statuses.where((s) => s.isFilterEnabled && s.matchesFilter).length;

  int get activeFilterCount =>
      statuses.where((s) => s.isFilterEnabled).length;
}
