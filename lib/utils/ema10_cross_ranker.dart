import '../models/indicator_result.dart';
import '../models/screener_result.dart';

/// Sort EMA 10 Cross BUYs by distance above EMA 200 and mark the top [topN].
class Ema10CrossRanker {
  Ema10CrossRanker._();

  static double pctAbove200(ScreenerResult row) {
    final ind = row.getIndicator(Ema10CrossResult.resultName);
    if (ind is! Ema10CrossResult) return double.negativeInfinity;
    return ind.pctAbove200;
  }

  static bool isBuy(ScreenerResult row) {
    final ind = row.getIndicator(Ema10CrossResult.resultName);
    return ind is Ema10CrossResult && ind.signal == SignalType.buy;
  }

  static List<ScreenerResult> rank(
    List<ScreenerResult> rows, {
    required bool enabled,
    int topN = 5,
  }) {
    if (!enabled || rows.isEmpty) return rows;

    final buys = <ScreenerResult>[];
    final rest = <ScreenerResult>[];
    for (final row in rows) {
      if (isBuy(row)) {
        buys.add(row);
      } else {
        rest.add(row);
      }
    }

    buys.sort((a, b) {
      final byVs200 = pctAbove200(b).compareTo(pctAbove200(a));
      if (byVs200 != 0) return byVs200;
      return b.matchScore.compareTo(a.matchScore);
    });
    rest.sort((a, b) => b.matchScore.compareTo(a.matchScore));

    final ranked = <ScreenerResult>[];
    for (var i = 0; i < buys.length; i++) {
      ranked.add(
        ScreenerResult(
          quote: buys[i].quote,
          candles: buys[i].candles,
          indicators: buys[i].indicators,
          matchingFilters: buys[i].matchingFilters,
          totalFilters: buys[i].totalFilters,
          priorityRank: topN > 0 && i < topN ? i + 1 : null,
        ),
      );
    }
    ranked.addAll(rest);
    return ranked;
  }
}
