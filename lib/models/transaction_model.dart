import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionCategory {
  creditCard,
  emi,
  loan,
  bills,
  chai,
  snacks,
  sutta,
  travel,
  misc,
}

class TransactionModel {
  final String id;
  final String userId;
  final double amount;
  final TransactionCategory category;
  final String description;
  final bool isAutomatic;
  final DateTime transactionDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.category,
    required this.description,
    this.isAutomatic = false,
    required this.transactionDate,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'amount': amount,
    'category': category.name,
    'description': description,
    'isAutomatic': isAutomatic,
    'transactionDate': Timestamp.fromDate(transactionDate),
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory TransactionModel.fromJson(Map<String, dynamic> json) => TransactionModel(
    id: json['id'] as String,
    userId: json['userId'] as String,
    amount: (json['amount'] as num).toDouble(),
    category: TransactionCategory.values.firstWhere((e) => e.name == json['category']),
    description: json['description'] as String,
    isAutomatic: json['isAutomatic'] as bool? ?? false,
    transactionDate: (json['transactionDate'] as Timestamp).toDate(),
    createdAt: (json['createdAt'] as Timestamp).toDate(),
    updatedAt: (json['updatedAt'] as Timestamp).toDate(),
  );

  TransactionModel copyWith({
    String? id,
    String? userId,
    double? amount,
    TransactionCategory? category,
    String? description,
    bool? isAutomatic,
    DateTime? transactionDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TransactionModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    amount: amount ?? this.amount,
    category: category ?? this.category,
    description: description ?? this.description,
    isAutomatic: isAutomatic ?? this.isAutomatic,
    transactionDate: transactionDate ?? this.transactionDate,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
