import 'candle_data.dart';
import 'indicator_result.dart';
import 'screener_result.dart';

const _codecVersion = 1;

/// JSON used by Supabase `screener_filter_cache.payload` (no OHLCV arrays).
Map<String, dynamic> encodeScreenerResultsPayload(List<ScreenerResult> rows) {
  return {
    'v': _codecVersion,
    'results': rows.map(encodeScreenerResultRow).toList(),
  };
}

Map<String, dynamic> encodeScreenerResultRow(ScreenerResult r) {
  return {
    'q': _encodeQuote(r.quote),
    'm': r.matchingFilters,
    't': r.totalFilters,
    'i': r.indicators.map(encodeIndicator).toList(),
  };
}

Map<String, dynamic> _encodeQuote(StockQuote q) => {
      's': q.symbol,
      'n': q.name,
      'mk': q.market,
      'sc': q.sector,
      'p': q.price,
      'ch': q.change,
      'cp': q.changePercent,
      'v': q.volume,
      'h52': q.week52High,
      'l52': q.week52Low,
    };

StockQuote _decodeQuote(Map<String, dynamic> m) => StockQuote(
      symbol: m['s'] as String,
      name: m['n'] as String,
      market: m['mk'] as String,
      sector: m['sc'] as String,
      price: (m['p'] as num).toDouble(),
      change: (m['ch'] as num).toDouble(),
      changePercent: (m['cp'] as num).toDouble(),
      volume: (m['v'] as num).toDouble(),
      week52High: m['h52'] == null ? null : (m['h52'] as num).toDouble(),
      week52Low: m['l52'] == null ? null : (m['l52'] as num).toDouble(),
    );

String _sigName(SignalType s) {
  switch (s) {
    case SignalType.buy:
      return 'buy';
    case SignalType.sell:
      return 'sell';
    case SignalType.neutral:
      return 'neutral';
  }
}

SignalType _parseSignal(String? raw) {
  switch (raw) {
    case 'buy':
      return SignalType.buy;
    case 'sell':
      return SignalType.sell;
    default:
      return SignalType.neutral;
  }
}

Map<String, dynamic> encodeIndicator(IndicatorResult r) {
  final age = r.signalAge;
  final sig = _sigName(r.signal);
  if (r is RsiResult) {
    return {
      'k': 'rsi',
      'sig': sig,
      'age': age,
      'fast': r.fastRsi,
      'slow': r.slowRsi,
    };
  }
  if (r is SupertrendResult) {
    return {
      'k': 'st',
      'sig': sig,
      'age': age,
      'bull': r.isBullish,
      'val': r.value ?? 0.0,
    };
  }
  if (r is ChandelierResult) {
    return {
      'k': 'ch',
      'sig': sig,
      'age': age,
      'long': r.value ?? 0.0,
      'short': r.value2 ?? 0.0,
    };
  }
  if (r is MacdResult) {
    return {
      'k': 'macd',
      'sig': sig,
      'age': age,
      'a': r.value ?? 0.0,
      'b': r.value2 ?? 0.0,
      'c': r.value3 ?? 0.0,
    };
  }
  if (r is EmaResult) {
    return {
      'k': 'ema',
      'sig': sig,
      'age': age,
      'label': r.name,
      'a': r.value ?? 0.0,
      'b': r.value2 ?? 0.0,
    };
  }
  if (r is BollingerResult) {
    return {
      'k': 'bb',
      'sig': sig,
      'age': age,
      'a': r.value ?? 0.0,
      'b': r.value2 ?? 0.0,
      'c': r.value3 ?? 0.0,
    };
  }
  if (r is AdxResult) {
    return {
      'k': 'adx',
      'sig': sig,
      'age': age,
      'a': r.value ?? 0.0,
      'b': r.value2 ?? 0.0,
      'c': r.value3 ?? 0.0,
    };
  }
  if (r is SethiResult) {
    return {
      'k': 'sethi',
      'sig': sig,
      'age': age,
      'rsi': r.value ?? 0.0,
      'h20': r.value2 ?? 0.0,
      'dma50': r.value3 ?? 0.0,
      'active': r.setupActive,
    };
  }
  return {
    'k': 'base',
    'name': r.name,
    'sig': sig,
    'age': age,
    'a': r.value,
    'b': r.value2,
    'c': r.value3,
    'd': r.description,
  };
}

IndicatorResult decodeIndicator(Map<String, dynamic> m) {
  final sig = _parseSignal(m['sig'] as String?);
  final age = (m['age'] as num?)?.toInt() ?? 0;
  switch (m['k']) {
    case 'rsi':
      return RsiResult(
        fastRsi: (m['fast'] as num).toDouble(),
        slowRsi: m['slow'] == null ? null : (m['slow'] as num).toDouble(),
        signal: sig,
        signalAge: age,
      );
    case 'st':
      return SupertrendResult(
        supertrendValue: (m['val'] as num).toDouble(),
        isBullish: m['bull'] as bool? ?? false,
        signal: sig,
        signalAge: age,
      );
    case 'ch':
      return ChandelierResult(
        longStop: (m['long'] as num).toDouble(),
        shortStop: (m['short'] as num).toDouble(),
        signal: sig,
        signalAge: age,
      );
    case 'macd':
      return MacdResult(
        macdLine: (m['a'] as num).toDouble(),
        signalLine: (m['b'] as num).toDouble(),
        histogram: (m['c'] as num).toDouble(),
        signal: sig,
        signalAge: age,
      );
    case 'ema':
      return EmaResult(
        label: m['label'] as String? ?? 'EMA',
        fastEma: (m['a'] as num).toDouble(),
        slowEma: (m['b'] as num).toDouble(),
        signal: sig,
        signalAge: age,
      );
    case 'bb':
      final mid = (m['b'] as num).toDouble();
      return BollingerResult(
        upper: (m['a'] as num).toDouble(),
        middle: mid,
        lower: (m['c'] as num).toDouble(),
        close: mid,
        signal: sig,
        signalAge: age,
      );
    case 'adx':
      return AdxResult(
        adx: (m['a'] as num).toDouble(),
        plusDi: (m['b'] as num).toDouble(),
        minusDi: (m['c'] as num).toDouble(),
        signal: sig,
        signalAge: age,
      );
    case 'sethi':
      final active = m['active'] as bool? ?? sig == SignalType.buy;
      return SethiResult(
        rsi: (m['rsi'] as num).toDouble(),
        priorHigh20: (m['h20'] as num).toDouble(),
        dma50: (m['dma50'] as num).toDouble(),
        dma200: 0,
        signal: sig,
        setupActive: active,
        signalAge: age,
      );
    default:
      return IndicatorResult(
        name: m['name'] as String? ?? 'Indicator',
        value: m['a'] == null ? null : (m['a'] as num).toDouble(),
        value2: m['b'] == null ? null : (m['b'] as num).toDouble(),
        value3: m['c'] == null ? null : (m['c'] as num).toDouble(),
        signal: sig,
        description: m['d'] as String? ?? '',
        signalAge: age,
      );
  }
}

/// Rebuilds [ScreenerResult] rows using [candlesFor] for OHLCV (chart / detail).
List<ScreenerResult> decodeScreenerResultsPayload(
  Map<String, dynamic> root,
  List<CandleData> Function(String symbol) candlesFor,
) {
  final rootMap = Map<String, dynamic>.from(root);
  final vRaw = rootMap['v'];
  final version = vRaw is int
      ? vRaw
      : vRaw is num
          ? vRaw.toInt()
          : -1;
  if (version != _codecVersion) return const [];

  final raw = rootMap['results'];
  if (raw is! List) return const [];

  final out = <ScreenerResult>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final row = Map<String, dynamic>.from(item);
    final qm = row['q'];
    if (qm is! Map) continue;
    final quoteMap = Map<String, dynamic>.from(qm);
    final quote = _decodeQuote(quoteMap);
    final candles = candlesFor(quote.symbol);
    if (candles.length < 2) continue;

    final il = row['i'];
    if (il is! List) continue;
    final indicators = <IndicatorResult>[];
    for (final e in il) {
      if (e is Map) {
        indicators.add(decodeIndicator(Map<String, dynamic>.from(e)));
      }
    }

    out.add(
      ScreenerResult(
        quote: quote,
        candles: candles,
        indicators: indicators,
        matchingFilters: (row['m'] as num?)?.toInt() ?? 0,
        totalFilters: (row['t'] as num?)?.toInt() ?? 0,
      ),
    );
  }
  return out;
}
