import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pocket_guard/models/investment_model.dart';
import 'package:pocket_guard/models/market_quote.dart';
import 'package:pocket_guard/services/investment_service.dart';
import 'package:pocket_guard/services/market_data_service.dart';
import 'package:pocket_guard/theme.dart';

final investmentServiceProvider = Provider((ref) => InvestmentService());
final marketDataServiceProvider = Provider((ref) => MarketDataService());

final portfolioProvider = StreamProvider.autoDispose<List<InvestmentModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  return uid == null ? Stream.value(const []) : ref.watch(investmentServiceProvider).portfolioStream(uid);
});

final watchlistProvider = StreamProvider.autoDispose<List<WatchlistItem>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  return uid == null ? Stream.value(const []) : ref.watch(investmentServiceProvider).watchlistStream(uid);
});

class InvestmentsTab extends ConsumerStatefulWidget {
  const InvestmentsTab({super.key});
  @override ConsumerState<InvestmentsTab> createState() => _InvestmentsTabState();
}

class _InvestmentsTabState extends ConsumerState<InvestmentsTab> {
  final _search = TextEditingController();
  Timer? _timer;
  Timer? _searchTimer;
  Map<String, MarketQuote> _quotes = {};
  List<MarketQuote> _gainers = [];
  List<MarketQuote> _losers = [];
  List<MarketQuote> _results = [];
  DateTime? _updated;
  bool _open = false;
  bool _cached = false;
  bool _loading = true;
  bool _savingInvestment = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final holdings = ref.read(portfolioProvider).asData?.value ?? const [];
    final saved = ref.read(watchlistProvider).asData?.value ?? const [];
    final symbols = <String>{'RELIANCE', 'TCS', 'INFY', 'SBIN', 'HDFCBANK', 'ICICIBANK', ...holdings.map((e) => e.stockSymbol), ...saved.map((e) => e.symbol)}.toList();
    try {
      final snapshot = await ref.read(marketDataServiceProvider).load(symbols: symbols);
      if (!mounted) return;
      setState(() {
        _quotes = {for (final quote in snapshot.quotes) quote.symbol: quote};
        _gainers = snapshot.gainers;
        _losers = snapshot.losers;
        _updated = snapshot.updatedAt;
        _open = snapshot.isMarketOpen;
        _cached = snapshot.fromCache;
        _loading = false;
        _error = snapshot.fromCache || (snapshot.gainers.isEmpty && snapshot.losers.isEmpty)
          ? 'Unable to refresh market data'
          : null;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Unable to refresh market data'; });
    }
  }

  void _searchStocks(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await ref.read(marketDataServiceProvider).search(value);
        if (mounted) setState(() => _results = results);
      } catch (_) { if (mounted) setState(() => _results = []); }
    });
  }

  MarketQuote? _quote(String symbol) => _quotes[symbol.toUpperCase()];

  @override
  Widget build(BuildContext context) {
    final holdings = ref.watch(portfolioProvider).asData?.value ?? const [];
    final watchlist = ref.watch(watchlistProvider).asData?.value ?? const [];
    final invested = holdings.fold<double>(0, (sum, item) => sum + item.totalInvested);
    final current = holdings.fold<double>(0, (sum, item) => sum + item.quantity * (_quote(item.stockSymbol)?.price ?? item.buyPrice));
    final pnl = current - invested;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: AppSpacing.paddingMd, children: [
        _header(context),
        const SizedBox(height: 16),
        TextField(controller: _search, onChanged: (value) { setState(() {}); _searchStocks(value); }, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search any NSE or BSE stock')),
        if (_search.text.isNotEmpty && _results.isNotEmpty) Card(child: Column(children: _results.map((q) => _quoteTile(context, q, add: true, onTap: () => _addInvestment(prefill: q))).toList())),
        const SizedBox(height: 20),
        _analytics(context, holdings, invested, current, pnl),
        const SizedBox(height: 24),
        _strip(context, 'Top Gainers', _gainers.take(10).toList()),
        const SizedBox(height: 20),
        _strip(context, 'Top Losers', _losers.take(10).toList()),
        const SizedBox(height: 24),
        _section(context, 'Portfolio', Icons.account_balance_wallet_outlined, _addInvestment),
        ...holdings.isEmpty ? [_empty(context, 'Add your first investment to start tracking your portfolio.')] : holdings.map((item) => _holding(context, item)),
        const SizedBox(height: 18),
        _section(context, 'Watchlist', Icons.visibility_outlined, _addWatchlist),
        ...watchlist.isEmpty ? [_empty(context, 'Track stocks here before you buy them.')] : watchlist.map((item) => _watch(context, item)),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_error!, style: context.textStyles.bodySmall?.withColor(AppColors.lossRed))),
        if (_loading) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
      ]),
    );
  }

  Widget _header(BuildContext context) {
    final stamp = _updated == null ? 'Waiting for quote' : DateFormat('d MMM, h:mm:ss a').format(_updated!.toLocal());
    return Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Investments', style: context.textStyles.headlineMedium?.extraBold), const SizedBox(height: 6), Row(children: [Icon(Icons.circle, size: 9, color: _open ? AppColors.profitGreen : AppColors.lossRed), const SizedBox(width: 6), Text(_open ? 'Market Open' : 'Market Closed', style: context.textStyles.bodySmall?.semiBold), const SizedBox(width: 10), Flexible(child: Text('${_cached ? 'Cached' : 'Updated'} $stamp', overflow: TextOverflow.ellipsis, style: context.textStyles.bodySmall?.withColor(AppColors.textSecondary)))])])), IconButton(onPressed: _refresh, tooltip: 'Refresh prices', icon: const Icon(Icons.refresh))]);
  }

  Widget _analytics(BuildContext context, List<InvestmentModel> holdings, double invested, double current, double pnl) {
    final allocation = <String, double>{};
    for (final item in holdings) {
      allocation[item.stockSymbol] = (allocation[item.stockSymbol] ?? 0) + item.quantity * (_quote(item.stockSymbol)?.price ?? item.buyPrice);
    }
    final today = holdings.fold<double>(0, (sum, item) => sum + item.quantity * (_quote(item.stockSymbol)?.priceChange ?? 0));
    final chart = allocation.isEmpty
        ? const Icon(Icons.pie_chart_outline, size: 48)
        : PieChart(PieChartData(
            centerSpaceRadius: 25,
            sectionsSpace: 2,
            sections: allocation.entries.toList().asMap().entries.map((entry) {
              return PieChartSectionData(
                value: entry.value.value,
                title: '',
                radius: 30,
                color: Colors.primaries[entry.key % Colors.primaries.length],
              );
            }).toList(),
          ));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: _metric(context, 'Total Portfolio', current, AppColors.credTeal)),
        const SizedBox(width: 10),
        Expanded(child: _metric(context, 'Invested', invested, null)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _metric(context, 'Unrealized P/L', pnl, pnl >= 0 ? AppColors.profitGreen : AppColors.lossRed)),
        const SizedBox(width: 10),
        Expanded(child: _metric(context, "Today's P/L", today, today >= 0 ? AppColors.profitGreen : AppColors.lossRed)),
      ]),
      const SizedBox(height: 12),
      Card(child: Padding(padding: AppSpacing.paddingMd, child: Row(children: [
        SizedBox(height: 110, width: 110, child: chart),
        const SizedBox(width: 18),
        Expanded(child: Text('Portfolio allocation\n${invested == 0 ? '0.00' : (pnl / invested * 100).toStringAsFixed(2)}% total return', style: context.textStyles.titleMedium?.semiBold)),
      ]))),
    ]);
  }

  Widget _metric(BuildContext context, String label, double value, Color? color) => Card(child: Padding(padding: AppSpacing.paddingMd, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.bodySmall?.withColor(AppColors.textSecondary)), const SizedBox(height: 7), Text('₹${value.toStringAsFixed(2)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.titleLarge?.semiBold.withColor(color ?? Theme.of(context).colorScheme.onSurface))])));

  Widget _strip(BuildContext context, String title, List<MarketQuote> quotes) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: context.textStyles.titleLarge?.extraBold),
      const SizedBox(height: 10),
      SizedBox(
        height: 142,
        child: quotes.isEmpty
            ? _empty(context, 'Market data is temporarily unavailable')
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: quotes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, index) {
                  final quote = quotes[index];
                  final color = quote.isGain ? AppColors.profitGreen : AppColors.lossRed;
                  return SizedBox(
                    width: 178,
                    child: Card(
                      child: Padding(
                        padding: AppSpacing.paddingMd,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _exchange(quote.exchange),
                          const SizedBox(height: 8),
                          Text(quote.companyName, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.bodySmall?.semiBold),
                          Text(quote.symbol, style: context.textStyles.titleMedium?.extraBold),
                          SizedBox(height: 18, child: CustomPaint(painter: _SparklinePainter(quote.isGain ? AppColors.profitGreen : AppColors.lossRed, quote.changePercent))),
                          const Spacer(),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('₹${quote.price.toStringAsFixed(2)}', style: context.textStyles.bodyMedium?.semiBold),
                            Text('${quote.isGain ? '+' : ''}${quote.changePercent.toStringAsFixed(2)}%', style: context.textStyles.bodySmall?.semiBold.withColor(color)),
                          ]),
                        ]),
                      ),
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  Widget _holding(BuildContext context, InvestmentModel item) { final q = _quote(item.stockSymbol); final value = item.quantity * (q?.price ?? item.buyPrice); final profit = value - item.totalInvested; return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(onTap: () => _editInvestment(item), onLongPress: () => _confirmDeleteInvestment(item), title: Row(children: [Text(item.stockSymbol, style: context.textStyles.titleMedium?.extraBold), const SizedBox(width: 8), _exchange(q?.exchange ?? 'NSE')]), subtitle: Text('${item.quantity} shares · Buy ₹${item.buyPrice.toStringAsFixed(2)}', style: context.textStyles.bodySmall?.withColor(AppColors.textSecondary)), trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text('₹${value.toStringAsFixed(2)}', style: context.textStyles.titleMedium?.semiBold), Text('${profit >= 0 ? '+' : ''}₹${profit.toStringAsFixed(2)}', style: context.textStyles.bodySmall?.semiBold.withColor(profit >= 0 ? AppColors.profitGreen : AppColors.lossRed))]))); }

  Widget _watch(BuildContext context, WatchlistItem item) {
    final q = _quote(item.symbol) ?? MarketQuote(symbol: item.symbol, companyName: item.symbol, exchange: item.exchange, price: 0, changePercent: 0, updatedAt: DateTime.now());
    return Dismissible(
      key: ValueKey(item.documentId),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _removeWatchlist(item),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppColors.lossRed, borderRadius: BorderRadius.circular(AppRadius.xl)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Card(margin: const EdgeInsets.only(bottom: 10), child: _quoteTile(context, q, trailing: IconButton(onPressed: () => _removeWatchlist(item), tooltip: 'Remove stock', icon: const Icon(Icons.remove_circle_outline)))),
    );
  }
  Widget _quoteTile(BuildContext context, MarketQuote q, {bool add = false, Widget? trailing, VoidCallback? onTap}) => ListTile(onTap: onTap, leading: _exchange(q.exchange), title: Text(q.companyName, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.bodyMedium?.semiBold), subtitle: Text(q.symbol), trailing: trailing ?? Row(mainAxisSize: MainAxisSize.min, children: [Text(q.price > 0 ? '₹${q.price.toStringAsFixed(2)}' : '--'), if (add) IconButton(onPressed: () => _saveWatchlist(q), tooltip: 'Add to watchlist', icon: const Icon(Icons.add))]));
  Widget _exchange(String value) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: AppColors.credTeal.withValues(alpha: .12), borderRadius: BorderRadius.circular(6)), child: Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.credTeal)));
  Widget _section(BuildContext context, String title, IconData icon, VoidCallback onAdd) => Row(children: [Icon(icon, size: 20, color: AppColors.credTeal), const SizedBox(width: 8), Text(title, style: context.textStyles.titleLarge?.extraBold), const Spacer(), IconButton(onPressed: onAdd, tooltip: 'Add $title', icon: const Icon(Icons.add_circle_outline))]);
  Widget _empty(BuildContext context, String text) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Text(text, style: context.textStyles.bodyMedium?.withColor(AppColors.textSecondary))));

  Future<void> _addInvestment({MarketQuote? prefill}) async {
    if (_savingInvestment) return;
    final form = await showDialog<_Form>(
      context: context,
      builder: (_) => _InvestmentDialog(initialSymbol: prefill?.symbol, initialCompanyName: prefill?.companyName),
    );
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (form == null || uid == null) return;
    setState(() => _savingInvestment = true);
    try {
      await ref.read(investmentServiceProvider).saveInvestment(InvestmentModel(id: '${form.symbol}_${DateTime.now().microsecondsSinceEpoch}', userId: uid, stockSymbol: form.symbol, quantity: form.quantity, buyPrice: form.price, buyDate: form.date));
      if (mounted) {
        _search.clear();
        setState(() => _results = []);
      }
      _refresh();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to save this investment. Please check your connection and try again.')));
    } finally {
      if (mounted) setState(() => _savingInvestment = false);
    }
  }

  Future<void> _editInvestment(InvestmentModel item) async {
    if (_savingInvestment) return;
    final form = await showDialog<_Form>(
      context: context,
      builder: (_) => _InvestmentDialog(
        initialSymbol: item.stockSymbol,
        initialQuantity: item.quantity,
        initialPrice: item.buyPrice,
        initialDate: item.buyDate,
        isEditing: true,
      ),
    );
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (form == null || uid == null) return;
    setState(() => _savingInvestment = true);
    try {
      await ref.read(investmentServiceProvider).saveInvestment(InvestmentModel(id: item.id, userId: uid, stockSymbol: form.symbol, quantity: form.quantity, buyPrice: form.price, buyDate: form.date));
      _refresh();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to update this investment. Please try again.')));
    } finally {
      if (mounted) setState(() => _savingInvestment = false);
    }
  }
  Future<void> _addWatchlist() async { final controller = TextEditingController(); final symbol = await showDialog<String>(context: context, builder: (_) => AlertDialog(title: const Text('Add to watchlist'), content: TextField(controller: controller, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'NSE/BSE symbol')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim().toUpperCase()), child: const Text('Add'))])); controller.dispose(); if (symbol != null && symbol.isNotEmpty) await _saveWatchlist(MarketQuote(symbol: symbol, companyName: symbol, exchange: 'NSE', price: 0, changePercent: 0, updatedAt: DateTime.now())); }
  Future<void> _saveWatchlist(MarketQuote q) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await ref.read(investmentServiceProvider).saveWatchlist(uid, WatchlistItem(symbol: q.symbol, exchange: q.exchange));
      _refresh();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to save watchlist. Check Firestore permissions.')));
    }
  }
  Future<void> _removeWatchlist(WatchlistItem item) async { final uid = FirebaseAuth.instance.currentUser?.uid; if (uid != null) await ref.read(investmentServiceProvider).deleteWatchlist(uid, item.symbol, exchange: item.exchange); }

  Future<void> _confirmDeleteInvestment(InvestmentModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete investment'),
        content: Text('Remove ${item.stockSymbol} from your portfolio? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.lossRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _deleteInvestment(item);
  }

  Future<void> _deleteInvestment(InvestmentModel item) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await ref.read(investmentServiceProvider).deleteInvestment(uid, item.id);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to delete this investment. Please try again.')));
    }
  }
}

class _Form { final String symbol; final int quantity; final double price; final DateTime date; const _Form(this.symbol, this.quantity, this.price, this.date); }

class _InvestmentDialog extends StatefulWidget {
  final String? initialSymbol;
  final String? initialCompanyName;
  final int? initialQuantity;
  final double? initialPrice;
  final DateTime? initialDate;
  final bool isEditing;
  const _InvestmentDialog({
    this.initialSymbol,
    this.initialCompanyName,
    this.initialQuantity,
    this.initialPrice,
    this.initialDate,
    this.isEditing = false,
  });
  @override State<_InvestmentDialog> createState() => _InvestmentDialogState();
}

class _InvestmentDialogState extends State<_InvestmentDialog> {
  late final TextEditingController _symbol = TextEditingController(text: widget.initialSymbol ?? '');
  late final TextEditingController _quantity = TextEditingController(text: widget.initialQuantity?.toString() ?? '');
  late final TextEditingController _price = TextEditingController(text: widget.initialPrice != null ? widget.initialPrice!.toStringAsFixed(2) : '');
  late DateTime _date = widget.initialDate ?? DateTime.now();
  String? _symbolError;
  String? _quantityError;
  String? _priceError;
  bool _submitting = false;

  @override void dispose() { _symbol.dispose(); _quantity.dispose(); _price.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.isEditing ? 'Edit investment' : 'Add investment'),
    content: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (widget.initialCompanyName != null && widget.initialCompanyName!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(alignment: Alignment.centerLeft, child: Text(widget.initialCompanyName!, style: context.textStyles.bodySmall?.withColor(AppColors.textSecondary))),
          ),
        TextField(controller: _symbol, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: 'Stock symbol', errorText: _symbolError)),
        TextField(controller: _quantity, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Quantity', errorText: _quantityError)),
        TextField(controller: _price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Buy price', errorText: _priceError)),
        Row(children: [
          Expanded(child: Text('Buy date: ${DateFormat('d MMM yyyy').format(_date)}')),
          TextButton(
            onPressed: _submitting ? null : () async {
              final selected = await showDatePicker(context: context, firstDate: DateTime(1990), lastDate: DateTime.now(), initialDate: _date);
              if (selected != null) setState(() => _date = selected);
            },
            child: const Text('Change'),
          ),
        ]),
      ]),
    ),
    actions: [
      TextButton(onPressed: _submitting ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _submitting ? null : _submit, child: Text(widget.isEditing ? 'Update' : 'Save')),
    ],
  );

  void _submit() {
    if (_submitting) return;
    final symbol = _symbol.text.trim().toUpperCase();
    final quantity = int.tryParse(_quantity.text.trim());
    final price = double.tryParse(_price.text.trim());
    setState(() {
      _symbolError = symbol.isEmpty ? 'Enter a stock symbol' : null;
      _quantityError = (quantity == null || quantity <= 0) ? 'Enter a valid quantity' : null;
      _priceError = (price == null || price <= 0) ? 'Enter a valid buy price' : null;
    });
    if (_symbolError != null || _quantityError != null || _priceError != null) return;
    setState(() => _submitting = true);
    Navigator.pop(context, _Form(symbol, quantity!, price!, _date));
  }
}

extension on MarketQuote { double get priceChange => price * changePercent / 100; }

class _SparklinePainter extends CustomPainter {
  final Color color;
  final double change;

  const _SparklinePainter(this.color, this.change);

  @override
  void paint(Canvas canvas, Size size) {
    final points = List.generate(8, (index) {
      final progress = index / 7;
      final wave = (index.isEven ? 0.12 : -0.08) * size.height;
      return Offset(progress * size.width, size.height / 2 - (change.sign * progress * size.height * .8) - wave);
    });
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => oldDelegate.color != color || oldDelegate.change != change;
}