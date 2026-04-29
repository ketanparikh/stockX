class CandleData {
  final DateTime timestamp;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const CandleData({
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  double get range => high - low;
  double get bodySize => (close - open).abs();
  bool get isBullish => close >= open;

  @override
  String toString() =>
      'Candle(${timestamp.toIso8601String()}, O:$open H:$high L:$low C:$close V:$volume)';
}
