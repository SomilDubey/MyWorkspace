import 'package:cloud_firestore/cloud_firestore.dart';

class InvestmentModel {
  final String id;
  final String userId;
  final String stockSymbol;
  final int quantity;
  final double averagePrice;
  final double currentPrice;
  final DateTime createdAt;
  final DateTime updatedAt;

  InvestmentModel({
    required this.id,
    required this.userId,
    required this.stockSymbol,
    required this.quantity,
    required this.averagePrice,
    required this.currentPrice,
    required this.createdAt,
    required this.updatedAt,
  });

  double get totalInvested => quantity * averagePrice;
  double get currentValue => quantity * currentPrice;
  double get profitLoss => currentValue - totalInvested;
  double get profitLossPercentage => (profitLoss / totalInvested) * 100;

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'stockSymbol': stockSymbol,
    'quantity': quantity,
    'averagePrice': averagePrice,
    'currentPrice': currentPrice,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory InvestmentModel.fromJson(Map<String, dynamic> json) => InvestmentModel(
    id: json['id'] as String,
    userId: json['userId'] as String,
    stockSymbol: json['stockSymbol'] as String,
    quantity: json['quantity'] as int,
    averagePrice: (json['averagePrice'] as num).toDouble(),
    currentPrice: (json['currentPrice'] as num).toDouble(),
    createdAt: (json['createdAt'] as Timestamp).toDate(),
    updatedAt: (json['updatedAt'] as Timestamp).toDate(),
  );

  InvestmentModel copyWith({
    String? id,
    String? userId,
    String? stockSymbol,
    int? quantity,
    double? averagePrice,
    double? currentPrice,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => InvestmentModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    stockSymbol: stockSymbol ?? this.stockSymbol,
    quantity: quantity ?? this.quantity,
    averagePrice: averagePrice ?? this.averagePrice,
    currentPrice: currentPrice ?? this.currentPrice,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

class SIPModel {
  final String id;
  final String userId;
  final double amount;
  final int dayOfMonth;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  SIPModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.dayOfMonth,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'amount': amount,
    'dayOfMonth': dayOfMonth,
    'isActive': isActive,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory SIPModel.fromJson(Map<String, dynamic> json) => SIPModel(
    id: json['id'] as String,
    userId: json['userId'] as String,
    amount: (json['amount'] as num).toDouble(),
    dayOfMonth: json['dayOfMonth'] as int,
    isActive: json['isActive'] as bool? ?? true,
    createdAt: (json['createdAt'] as Timestamp).toDate(),
    updatedAt: (json['updatedAt'] as Timestamp).toDate(),
  );

  SIPModel copyWith({
    String? id,
    String? userId,
    double? amount,
    int? dayOfMonth,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SIPModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    amount: amount ?? this.amount,
    dayOfMonth: dayOfMonth ?? this.dayOfMonth,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
