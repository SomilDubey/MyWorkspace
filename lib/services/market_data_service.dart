import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pocket_guard/investments/market_api_config.dart';
import 'package:pocket_guard/models/market_quote.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MarketDataService {
  static const _cacheKey = 'investments_twelve_data_snapshot_v1';
  final http.Client _client;
  final String baseUrl;
  final String apiKey;

  MarketDataService({
    http.Client? client,
    String? baseUrl,
    String? apiKey,
  })  : baseUrl = baseUrl ?? MarketApiConfig.baseUrl,
        apiKey = apiKey ?? MarketApiConfig.apiKey,
        _client = client ?? http.Client();

  Future<MarketSnapshot> load({List<String> symbols = const []}) async {
    try {
      if (apiKey.isEmpty) throw StateError('Twelve Data API key is not configured.');
      final responses = await Future.wait([
        _fetchMoverList(type: 'gainers'),
        _fetchMoverList(type: 'losers'),
        ...symbols.map(_fetchNseQuote),
      ]);
      final gainers = responses[0] as List<MarketQuote>;
      final losers = responses[1] as List<MarketQuote>;
      final quotes = responses.skip(2).whereType<MarketQuote>().toList();
      if (gainers.isEmpty && losers.isEmpty && quotes.isEmpty) {
        throw StateError('Twelve Data returned no market data.');
      }
      final snapshot = MarketSnapshot(
        quotes: _uniqueQuotes([...quotes, ...gainers, ...losers]),
        gainers: _sorted(gainers, descending: true),
        losers: _sorted(losers, descending: false),
        updatedAt: DateTime.now(),
        isMarketOpen: _marketOpenFrom(),
      );
      await _writeCache(snapshot);
      return snapshot;
    } catch (error) {
      debugPrint('Twelve Data refresh failed: $error');
      final cached = await _readCache();
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<List<MarketQuote>> search(String query) async {
    if (query.trim().isEmpty || apiKey.isEmpty) return const [];
    try {
      final data = await _getJson('/symbol_search', {'symbol': query.trim()});
      final symbols = _listFrom(data);
      final results = await Future.wait(symbols.take(20).map((item) async {
        final symbol = _text(item, ['symbol']);
        final exchange = _exchange(item);
        if (symbol.isEmpty) return null;
        return _fetchQuote(symbol, exchange, fallback: item);
      }));
      return results.whereType<MarketQuote>().where((quote) => quote.symbol.isNotEmpty).toList();
    } catch (error) {
      debugPrint('Twelve Data search failed: $error');
      final cached = await _readCache();
      final needle = query.trim().toUpperCase();
      return cached?.quotes.where((quote) =>
          quote.symbol.toUpperCase().contains(needle) ||
          quote.companyName.toUpperCase().contains(needle)).toList() ?? const [];
    }
  }

  Future<MarketSeries> series(String symbol, {String timeframe = '1D'}) async {
    final interval = switch (timeframe) {
      '1D' => '5min',
      '1W' => '30min',
      '1M' => '1day',
      '3M' => '1day',
      '1Y' => '1week',
      _ => '1month',
    };
    final outputsize = switch (timeframe) {
      '1D' => '78',
      '1W' => '100',
      '1M' => '31',
      '3M' => '92',
      '1Y' => '52',
      _ => '60',
    };
    final data = await _getJson('/time_series', {
      'symbol': '$symbol:NSE',
      'interval': interval,
      'outputsize': outputsize,
      'order': 'asc',
    });
    final values = _listFrom(data);
    final bars = values.map((item) {
      DateTime parseDate() => DateTime.tryParse(_text(item, ['datetime'])) ?? DateTime.now();
      return MarketBar(
        date: parseDate(),
        open: _number(item, ['open']),
        high: _number(item, ['high']),
        low: _number(item, ['low']),
        close: _number(item, ['close']),
        volume: _number(item, ['volume']),
      );
    }).where((bar) => bar.close > 0).toList();
    final quote = await _fetchQuote(symbol, 'NSE') ?? MarketQuote(symbol: symbol, companyName: symbol, exchange: 'NSE', price: bars.isEmpty ? 0 : bars.last.close, changePercent: 0, updatedAt: DateTime.now());
    return MarketSeries(quote: quote, bars: bars);
  }

  Future<List<MarketQuote>> _fetchMoverList({required String type}) async {
    try {
      final data = await _getJson('/market_movers', {'exchange': 'NSE', 'type': type});
      final namedValues = data[type] is List ? data[type] as List : null;
      final values = namedValues == null
          ? _listFrom(data)
          : namedValues.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
      return values
          .map((item) => _parseQuote(item, defaultExchange: 'NSE'))
          .where((quote) => quote.price > 0)
          .toList();
    } catch (error) {
      debugPrint('Twelve Data movers unavailable for $type: $error');
      return const [];
    }
  }

  Future<MarketQuote?> _fetchNseQuote(String symbol) async {
    final quote = await _fetchQuote(symbol, 'NSE');
    if (quote != null) return quote;
    try {
      final data = await _getJson('/symbol_search', {'symbol': symbol});
      final match = _listFrom(data).where((item) =>
          _text(item, ['symbol']).toUpperCase() == symbol.toUpperCase() &&
          _exchange(item) == 'NSE').firstOrNull;
      return match == null ? null : _parseQuote(match, defaultExchange: 'NSE', fallbackSymbol: symbol);
    } catch (error) {
      debugPrint('Directory fallback failed for $symbol: $error');
      return null;
    }
  }

  Future<MarketQuote?> _fetchQuote(String symbol, String exchange, {Map<String, dynamic>? fallback}) async {
    for (final candidate in ['$symbol:$exchange', symbol]) {
      try {
        final data = await _getJson('/quote', {'symbol': candidate});
        return _parseQuote(data, defaultExchange: exchange, fallbackSymbol: symbol);
      } catch (error) {
        debugPrint('Quote unavailable for $candidate: $error');
      }
    }
    if (fallback == null) return null;
    return _parseQuote(fallback, defaultExchange: exchange, fallbackSymbol: symbol);
  }

  MarketQuote _parseQuote(Map<String, dynamic> data, {required String defaultExchange, String? fallbackSymbol}) {
    final symbol = _text(data, ['symbol', 'ticker'], fallback: fallbackSymbol ?? '');
    return MarketQuote(
      symbol: symbol.split(':').first,
      companyName: _text(data, ['name', 'instrument_name', 'company_name'], fallback: symbol),
      exchange: _exchange(data, fallback: defaultExchange),
      price: _number(data, ['close', 'price', 'last', 'current_price']),
      changePercent: _number(data, ['percent_change', 'percentage_change', 'change_percent', 'change_percentage']),
      updatedAt: DateTime.now(),
    );
  }

  Future<Map<String, dynamic>> _getJson(String path, Map<String, String> params) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: {...params, 'apikey': apiKey});
    final response = await _client.get(uri, headers: const {'Accept': 'application/json'}).timeout(const Duration(seconds: 15));
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || decoded is! Map) {
      throw StateError('Twelve Data returned HTTP ${response.statusCode}.');
    }
    final data = Map<String, dynamic>.from(decoded);
    if (data['status'] == 'error' || data['code'] != null) {
      throw StateError((data['message'] ?? 'Twelve Data request failed').toString());
    }
    return data;
  }

  List<Map<String, dynamic>> _listFrom(Map<String, dynamic> data) {
    final raw = data['data'] ?? data['values'] ?? data['results'] ?? const [];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  String _text(Map<String, dynamic> data, List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) return value.toString();
    }
    return fallback;
  }

  double _number(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      final parsed = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }

  String _exchange(Map<String, dynamic> data, {String fallback = 'NSE'}) {
    final value = _text(data, ['exchange', 'mic_code'], fallback: fallback).toUpperCase();
    return value.contains('BSE') || value == 'XBOM' ? 'BSE' : 'NSE';
  }

  List<MarketQuote> _sorted(List<MarketQuote> values, {required bool descending}) {
    final result = [...values];
    result.sort((a, b) => descending ? b.changePercent.compareTo(a.changePercent) : a.changePercent.compareTo(b.changePercent));
    return result;
  }

  List<MarketQuote> _uniqueQuotes(List<MarketQuote> values) {
    final result = <String, MarketQuote>{};
    for (final quote in values) {
      result['${quote.exchange}:${quote.symbol}'] = quote;
    }
    return result.values.toList();
  }

  bool _marketOpenFrom() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final weekday = now.weekday >= DateTime.monday && now.weekday <= DateTime.friday;
    final minutes = now.hour * 60 + now.minute;
    return weekday && minutes >= 555 && minutes <= 930;
  }

  Future<void> _writeCache(MarketSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode({
      'updatedAt': snapshot.updatedAt.toIso8601String(),
      'isMarketOpen': snapshot.isMarketOpen,
      'quotes': snapshot.quotes.map((quote) => quote.toJson()).toList(),
      'gainers': snapshot.gainers.map((quote) => quote.toJson()).toList(),
      'losers': snapshot.losers.map((quote) => quote.toJson()).toList(),
    }));
  }

  Future<MarketSnapshot?> _readCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      List<MarketQuote> read(String key) => ((data[key] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => MarketQuote.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      final quotes = read('quotes');
      final cachedGainers = read('gainers');
      final cachedLosers = read('losers');
      return MarketSnapshot(
        quotes: quotes,
        gainers: cachedGainers.isEmpty ? _sorted(quotes.where((q) => q.isGain).toList(), descending: true) : cachedGainers,
        losers: cachedLosers.isEmpty ? _sorted(quotes.where((q) => !q.isGain).toList(), descending: false) : cachedLosers,
        updatedAt: DateTime.tryParse((data['updatedAt'] ?? '').toString()) ?? DateTime.now(),
        isMarketOpen: data['isMarketOpen'] as bool? ?? false,
        fromCache: true,
      );
    } catch (error) {
      debugPrint('Market cache read failed: $error');
      return null;
    }
  }
}