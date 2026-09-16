class MarketQuote {
  final String symbol;
  final String companyName;
  final String exchange;
  final double price;
  final double changePercent;
  final DateTime updatedAt;
  final List<double> sparkline;

  const MarketQuote({
    required this.symbol,
    required this.companyName,
    required this.exchange,
    required this.price,
    required this.changePercent,
    required this.updatedAt,
    this.sparkline = const [],
  });

  bool get isGain => changePercent >= 0;

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'companyName': companyName,
        'exchange': exchange,
        'price': price,
        'changePercent': changePercent,
        'updatedAt': updatedAt.toIso8601String(),
        'sparkline': sparkline,
      };

  factory MarketQuote.fromJson(Map<String, dynamic> json) => MarketQuote(
        symbol: (json['symbol'] ?? '').toString(),
        companyName: (json['companyName'] ?? json['symbol'] ?? '').toString(),
        exchange: (json['exchange'] ?? 'NSE').toString(),
        price: (json['price'] as num?)?.toDouble() ?? 0,
        changePercent: (json['changePercent'] as num?)?.toDouble() ?? 0,
        updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ?? DateTime.now(),
        sparkline: ((json['sparkline'] as List?) ?? const [])
            .whereType<num>()
            .map((value) => value.toDouble())
            .toList(),
      );
}

class MarketSnapshot {
  final List<MarketQuote> quotes;
  final List<MarketQuote> gainers;
  final List<MarketQuote> losers;
  final DateTime updatedAt;
  final bool isMarketOpen;
  final bool fromCache;

  const MarketSnapshot({
    required this.quotes,
    this.gainers = const [],
    this.losers = const [],
    required this.updatedAt,
    required this.isMarketOpen,
    this.fromCache = false,
  });
}

class MarketBar {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const MarketBar({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });
}

class MarketSeries {
  final MarketQuote quote;
  final List<MarketBar> bars;

  const MarketSeries({required this.quote, required this.bars});
}