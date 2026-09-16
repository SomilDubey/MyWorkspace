import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pocket_guard/models/investment_model.dart';

class InvestmentService {
  final FirebaseFirestore _firestore;

  InvestmentService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String uid, String name) =>
      _firestore.collection('users').doc(uid).collection(name);

  Stream<List<InvestmentModel>> portfolioStream(String uid) => _collection(uid, 'portfolio')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => InvestmentModel.fromFirestore(doc)).toList());

  Stream<List<WatchlistItem>> watchlistStream(String uid) => _collection(uid, 'watchlist')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => WatchlistItem.fromFirestore(doc)).toList());

  Future<void> saveInvestment(InvestmentModel investment) async {
    try {
      await _collection(investment.userId, 'portfolio').doc(investment.id).set(investment.toFirestore());
    } catch (error) {
      debugPrint('Saving investment failed: $error');
      rethrow;
    }
  }

  Future<void> deleteInvestment(String uid, String id) => _collection(uid, 'portfolio').doc(id).delete();

  Future<void> saveWatchlist(String uid, WatchlistItem item) => _collection(uid, 'watchlist').doc(item.documentId).set(item.toFirestore(), SetOptions(merge: true));

  Future<void> deleteWatchlist(String uid, String symbol, {String exchange = 'NSE'}) => _collection(uid, 'watchlist').doc(WatchlistItem.documentIdFor(symbol, exchange)).delete();
}

class WatchlistItem {
  final String symbol;
  final String exchange;
  final bool pinned;

  const WatchlistItem({required this.symbol, required this.exchange, this.pinned = false});

  static String documentIdFor(String symbol, String exchange) =>
      '${exchange.toUpperCase()}_${symbol.toUpperCase()}';

  String get documentId => documentIdFor(symbol, exchange);

  factory WatchlistItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return WatchlistItem(
      symbol: (data['symbol'] ?? doc.id.split('_').skip(1).join('_')).toString(),
      exchange: (data['exchange'] ?? 'NSE').toString(),
      pinned: data['pinned'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {'symbol': symbol, 'exchange': exchange, 'pinned': pinned};
}