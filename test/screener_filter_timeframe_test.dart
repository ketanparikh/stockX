import 'package:flutter_test/flutter_test.dart';
import 'package:stockx/models/screener_filter.dart';
import 'package:stockx/utils/constants.dart';
import 'package:stockx/utils/screener_filter_fingerprint.dart';

void main() {
  test('EMA 10 Cross pins the run to weekly even if UI timeframe is daily', () {
    const filter = ScreenerFilter(
      timeframe: Timeframe.daily,
      useEma10Cross: true,
    );
    expect(filter.pinsWeeklyEmaStack, isTrue);
    expect(filter.resolvedTimeframe, Timeframe.weekly);
  });

  test('Approaching EMA 200 also pins weekly', () {
    const filter = ScreenerFilter(
      timeframe: Timeframe.daily,
      useApproachingEma200: true,
    );
    expect(filter.resolvedTimeframe, Timeframe.weekly);
  });

  test('other indicators keep the selected timeframe', () {
    const filter = ScreenerFilter(
      timeframe: Timeframe.daily,
      useSupertrend: true,
    );
    expect(filter.pinsWeeklyEmaStack, isFalse);
    expect(filter.resolvedTimeframe, Timeframe.daily);
  });

  test('weekly Yahoo range is 10y so EMA 200 can warm up', () {
    expect(Timeframe.yahooRange(Timeframe.weekly), '10y');
    expect(Timeframe.yahooRange(Timeframe.daily), '2y');
  });

  test('filter cache hash uses weekly when EMA 10 Cross is on', () {
    const dailyEma = ScreenerFilter(
      timeframe: Timeframe.daily,
      useEma10Cross: true,
    );
    const weeklyEma = ScreenerFilter(
      timeframe: Timeframe.weekly,
      useEma10Cross: true,
    );
    expect(
      screenerFilterCacheHash(dailyEma),
      screenerFilterCacheHash(weeklyEma),
    );
  });
}
