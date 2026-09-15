import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pocket_guard/models/transaction_model.dart';

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'transactions';

  Future<void> addTransaction(TransactionModel transaction) async {
    try {
      await _firestore.collection(_collection).doc(transaction.id).set(transaction.toJson());
    } catch (e) {
      debugPrint('Error adding transaction: $e');
      rethrow;
    }
  }

  Future<List<TransactionModel>> getUserTransactions(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('transactionDate', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => TransactionModel.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting transactions: $e');
      return [];
    }
  }

  Stream<List<TransactionModel>> transactionsStream(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('transactionDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => TransactionModel.fromJson(doc.data())).toList());
  }

  Future<void> deleteTransaction(String transactionId) async {
    try {
      await _firestore.collection(_collection).doc(transactionId).delete();
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
      rethrow;
    }
  }

  Future<List<TransactionModel>> getMonthlyTransactions(String userId, DateTime month) async {
    try {
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
      
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('transactionDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('transactionDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .orderBy('transactionDate', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => TransactionModel.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting monthly transactions: $e');
      return [];
    }
  }
}
