import 'package:cloud_firestore/cloud_firestore.dart';

class InvestmentModel {
  final String id;
  final String userId;
  final String stockSymbol;
  final int quantity;
  final double buyPrice;
  final DateTime buyDate;

  InvestmentModel({
    required this.id,
    required this.userId,
    required this.stockSymbol,
    required this.quantity,
    required this.buyPrice,
    required this.buyDate,
  });

  double get totalInvested => quantity * buyPrice;

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'userId': userId,
    'stockSymbol': stockSymbol,
    'quantity': quantity,
    'buyPrice': buyPrice,
    'buyDate': Timestamp.fromDate(buyDate),
  };

  factory InvestmentModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? {};
    final rawDate = json['buyDate'] ?? json['createdAt'];
    final buyDate = rawDate is Timestamp
        ? rawDate.toDate()
        : DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();
    return InvestmentModel(
      id: doc.id,
      userId: (json['userId'] ?? '') as String,
      stockSymbol: (json['stockSymbol'] ?? '') as String,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      buyPrice: ((json['buyPrice'] ?? json['averagePrice'] ?? 0) as num).toDouble(),
      buyDate: buyDate,
    );
  }
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
