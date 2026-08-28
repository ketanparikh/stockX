import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/screener_filter.dart';
import '../models/screener_result.dart';
import '../services/screener_service.dart';
import 'sync_provider.dart'
    show
        cacheServiceProvider,
        dataSyncServiceProvider,
        supabaseServiceProvider,
        yahooFinanceServiceProvider;

// Re-export so existing imports of yahooFinanceServiceProvider keep working
export 'sync_provider.dart' show yahooFinanceServiceProvider;

final screenerServiceProvider = Provider<ScreenerService>((ref) {
  return ScreenerService(
    ref.watch(cacheServiceProvider),
    ref.watch(dataSyncServiceProvider),
    ref.watch(supabaseServiceProvider),
    ref.watch(yahooFinanceServiceProvider),
  );
});

// Filter state
class ScreenerFilterNotifier extends StateNotifier<ScreenerFilter> {
  ScreenerFilterNotifier() : super(const ScreenerFilter());

  void updateMarkets(Set<String> markets) {
    state = state.copyWith(markets: markets);
  }

  void toggleMarket(String market) {
    final updated = Set<String>.from(state.markets);
    if (updated.contains(market)) {
      if (updated.length > 1) updated.remove(market);
    } else {
      updated.add(market);
    }
    state = state.copyWith(markets: updated);
  }

  void updateSectors(Set<String> sectors) {
    state = state.copyWith(sectors: sectors);
  }

  void toggleSector(String sector) {
    final updated = Set<String>.from(state.sectors);
    if (updated.contains(sector)) {
      updated.remove(sector);
    } else {
      updated.add(sector);
    }
    state = state.copyWith(sectors: updated);
  }

  void setTimeframe(String timeframe) {
    state = state.copyWith(timeframe: timeframe);
  }

  void toggleRsi(bool enabled) {
    state = state.copyWith(useRsi: enabled);
  }

  void updateRsiParams(RsiFilterParams params) {
    state = state.copyWith(rsiParams: params);
  }

  void toggleSupertrend(bool enabled) {
    state = state.copyWith(useSupertrend: enabled);
  }

  void updateSupertrendParams(SupertrendFilterParams params) {
    state = state.copyWith(supertrendParams: params);
  }

  void toggleChandelier(bool enabled) {
    state = state.copyWith(useChandelier: enabled);
  }

  void updateChandelierParams(ChandelierFilterParams params) {
    state = state.copyWith(chandelierParams: params);
  }

  void toggleMacd(bool enabled) {
    state = state.copyWith(useMacd: enabled);
  }

  void updateMacdParams(MacdFilterParams params) {
    state = state.copyWith(macdParams: params);
  }

  void toggleEma(bool enabled) {
    state = state.copyWith(useEma: enabled);
  }

  void updateEmaParams(EmaFilterParams params) {
    state = state.copyWith(emaParams: params);
  }

  void toggleEma10Cross(bool enabled) {
    state = state.copyWith(useEma10Cross: enabled);
  }

  void updateEma10CrossParams(Ema10CrossFilterParams params) {
    state = state.copyWith(ema10CrossParams: params);
  }

  void toggleApproachingEma200(bool enabled) {
    state = state.copyWith(useApproachingEma200: enabled);
  }

  void updateApproachingEma200Params(ApproachingEma200FilterParams params) {
    state = state.copyWith(approachingEma200Params: params);
  }

  void toggleBollinger(bool enabled) {
    state = state.copyWith(useBollinger: enabled);
  }

  void updateBollingerParams(BollingerFilterParams params) {
    state = state.copyWith(bollingerParams: params);
  }

  void toggleAdx(bool enabled) {
    state = state.copyWith(useAdx: enabled);
  }

  void updateAdxParams(AdxFilterParams params) {
    state = state.copyWith(adxParams: params);
  }

  void toggleSethi(bool enabled) {
    state = state.copyWith(useSethi: enabled);
  }

  void updateSethiParams(SethiFilterParams params) {
    state = state.copyWith(sethiParams: params);
  }

  void toggleQualityFilter(bool enabled) {
    state = state.copyWith(useQualityFilter: enabled);
  }

  void updateQualityParams(QualityFilterParams params) {
    state = state.copyWith(qualityParams: params);
  }

  void setRequireAllFilters(bool value) {
    state = state.copyWith(requireAllFilters: value);
  }

  void setRequireFreshSignal(bool value) {
    state = state.copyWith(requireFreshSignal: value);
  }

  void setFreshSignalMaxBars(int bars) {
    state = state.copyWith(freshSignalMaxBars: bars);
  }

  void setMaxResults(int value) {
    state = state.copyWith(maxResults: value);
  }

  void reset() {
    state = const ScreenerFilter();
  }
}

final screenerFilterProvider =
    StateNotifierProvider<ScreenerFilterNotifier, ScreenerFilter>(
  (ref) => ScreenerFilterNotifier(),
);

// Screener execution state
enum ScreenerStatus { idle, running, success, error }

class ScreenerState {
  final ScreenerStatus status;
  final List<ScreenerResult> results;
  final String? errorMessage;
  final int processed;
  final int total;

  const ScreenerState({
    this.status = ScreenerStatus.idle,
    this.results = const [],
    this.errorMessage,
    this.processed = 0,
    this.total = 0,
  });

  bool get isRunning => status == ScreenerStatus.running;
  bool get hasResults => results.isNotEmpty;
  double get progress => total > 0 ? processed / total : 0;

  ScreenerState copyWith({
    ScreenerStatus? status,
    List<ScreenerResult>? results,
    String? errorMessage,
    int? processed,
    int? total,
  }) =>
      ScreenerState(
        status: status ?? this.status,
        results: results ?? this.results,
        errorMessage: errorMessage,
        processed: processed ?? this.processed,
        total: total ?? this.total,
      );
}

class ScreenerNotifier extends StateNotifier<ScreenerState> {
  final ScreenerService _service;

  ScreenerNotifier(this._service) : super(const ScreenerState());

  Future<void> runScreener(ScreenerFilter filter) async {
    state = const ScreenerState(status: ScreenerStatus.running);

    try {
      final results = await _service.runScreener(
        filter,
        onProgress: (processed, total) {
          state = state.copyWith(
            processed: processed,
            total: total,
          );
        },
      );

      state = ScreenerState(
        status: ScreenerStatus.success,
        results: results,
        processed: state.total,
        total: state.total,
      );
    } catch (e) {
      state = ScreenerState(
        status: ScreenerStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void reset() {
    state = const ScreenerState();
  }
}

final screenerProvider =
    StateNotifierProvider<ScreenerNotifier, ScreenerState>(
  (ref) => ScreenerNotifier(ref.watch(screenerServiceProvider)),
);
