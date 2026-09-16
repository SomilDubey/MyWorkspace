import 'dart:async';

import 'package:candlesticks/candlesticks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_guard/models/market_quote.dart';
import 'package:pocket_guard/services/market_data_service.dart';
import 'package:pocket_guard/theme.dart';

final chartsMarketDataServiceProvider = Provider((ref) => MarketDataService());

class ChartsTab extends ConsumerStatefulWidget {
  const ChartsTab({super.key});
  @override ConsumerState<ChartsTab> createState() => _ChartsTabState();
}

class _ChartsTabState extends ConsumerState<ChartsTab> {
  final _search = TextEditingController(text: 'RELIANCE');
  Timer? _searchTimer;
  String _timeframe = '1D';
  MarketSeries? _series;
  List<MarketQuote> _results = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSeries('RELIANCE');
  }

  @override
  void dispose() { _searchTimer?.cancel(); _search.dispose(); super.dispose(); }

  Future<void> _loadSeries(String symbol) async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ref.read(chartsMarketDataServiceProvider).series(symbol, timeframe: _timeframe);
      if (mounted) setState(() { _series = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Unable to load chart data'; });
    }
  }

  void _searchStocks(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 350), () async {
      final results = await ref.read(chartsMarketDataServiceProvider).search(value);
      if (mounted) setState(() => _results = results);
    });
  }

  @override
  Widget build(BuildContext context) {
    final series = _series;
    final quote = series?.quote;
    final bars = series?.bars ?? const <MarketBar>[];
    final candles = bars.map((bar) => Candle(date: bar.date, open: bar.open, high: bar.high, low: bar.low, close: bar.close, volume: bar.volume)).toList();
    final change = quote?.changePercent ?? 0;
    return ListView(padding: AppSpacing.paddingMd, children: [
      Text('Market Charts', style: context.textStyles.headlineMedium?.extraBold),
      const SizedBox(height: 14),
      TextField(controller: _search, onChanged: (value) { setState(() {}); _searchStocks(value); }, onSubmitted: (value) => _loadSeries(value.trim().toUpperCase()), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search any NSE or BSE stock')),
      if (_search.text.isNotEmpty && _results.isNotEmpty) Card(child: Column(children: _results.take(6).map((item) => ListTile(leading: _badge(item.exchange), title: Text(item.companyName), subtitle: Text(item.symbol), trailing: Text('₹${item.price.toStringAsFixed(2)}'), onTap: () { _search.text = item.symbol; _results = []; _loadSeries(item.symbol); setState(() {}); })).toList())),
      const SizedBox(height: 18),
      if (quote != null) ...[
        Row(children: [Expanded(child: Text('${quote.companyName} (${quote.exchange})', style: context.textStyles.titleLarge?.extraBold)), Text('${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%', style: context.textStyles.titleMedium?.semiBold.withColor(change >= 0 ? AppColors.profitGreen : AppColors.lossRed))]),
        const SizedBox(height: 6),
        Text('₹${quote.price.toStringAsFixed(2)}', style: context.textStyles.displayLarge?.withSize(34)),
        if (bars.isNotEmpty) Text('High ₹${bars.map((b) => b.high).reduce((a, b) => a > b ? a : b).toStringAsFixed(2)}  •  Low ₹${bars.map((b) => b.low).reduce((a, b) => a < b ? a : b).toStringAsFixed(2)}', style: context.textStyles.bodySmall?.withColor(AppColors.textSecondary)),
      ],
      const SizedBox(height: 14),
      Row(children: ['1D', '1W', '1M', '3M', '1Y', '5Y'].map((value) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(value), selected: _timeframe == value, selectedColor: AppColors.credTeal, onSelected: (_) { setState(() => _timeframe = value); _loadSeries(_search.text.trim().toUpperCase()); }, labelStyle: context.textStyles.bodySmall?.withColor(_timeframe == value ? AppColors.darkBackground : Theme.of(context).colorScheme.onSurface)))).toList()),
      const SizedBox(height: 14),
      Card(child: SizedBox(height: 400, child: _loading ? const Center(child: CircularProgressIndicator()) : candles.isEmpty ? Center(child: Text(_error ?? 'No chart data available')) : Candlesticks(candles: candles))),
    ]);
  }

  Widget _badge(String exchange) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: AppColors.credTeal.withValues(alpha: .12), borderRadius: BorderRadius.circular(6)), child: Text(exchange, style: const TextStyle(fontSize: 10, color: AppColors.credTeal, fontWeight: FontWeight.w700)));
}