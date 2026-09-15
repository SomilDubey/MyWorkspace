import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? phoneNumber;

  /// Legacy field kept for backward compatibility.
  /// In Pay Vault v1+, this represents the Personal salary.
  final double monthlySalary;

  /// New field: Personal salary (used for Personal account calculations).
  final double personalSalary;

  /// New field: Business income (used for Business account calculations).
  final double businessIncome;

  /// Feature flag: whether Personal account is enabled for this user.
  final bool personalAccountEnabled;

  /// Feature flag: whether Business account is enabled for this user.
  final bool businessAccountEnabled;

  final int salaryDate;
  final double fixedDeductions;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.phoneNumber,
    required this.monthlySalary,
    double? personalSalary,
    double? businessIncome,
    bool? personalAccountEnabled,
    bool? businessAccountEnabled,
    required this.salaryDate,
    this.fixedDeductions = 0.0,
    required this.createdAt,
    required this.updatedAt,
  })  : personalSalary = personalSalary ?? monthlySalary,
        businessIncome = businessIncome ?? 0.0,
        personalAccountEnabled = personalAccountEnabled ?? true,
        businessAccountEnabled = businessAccountEnabled ?? true;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'phoneNumber': phoneNumber,
        'monthlySalary': monthlySalary,
        'personalSalary': personalSalary,
        'businessIncome': businessIncome,
        'personalAccountEnabled': personalAccountEnabled,
        'businessAccountEnabled': businessAccountEnabled,
        'salaryDate': salaryDate,
        'fixedDeductions': fixedDeductions,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) {
      final parsed = DateTime.tryParse(v);
      if (parsed != null) return parsed;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final legacyMonthly = ((json['monthlySalary'] ?? 0) as num).toDouble();
    final personal = (json['personalSalary'] as num?)?.toDouble();
    return UserModel(
      uid: (json['uid'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      displayName: json['displayName'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      monthlySalary: legacyMonthly,
      personalSalary: personal ?? legacyMonthly,
      businessIncome: (json['businessIncome'] as num?)?.toDouble() ?? 0.0,
      personalAccountEnabled: (json['personalAccountEnabled'] as bool?) ?? true,
      businessAccountEnabled: (json['businessAccountEnabled'] as bool?) ?? true,
      salaryDate: ((json['salaryDate'] ?? 0) as num).toInt(),
      fixedDeductions: (json['fixedDeductions'] as num?)?.toDouble() ?? 0.0,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? phoneNumber,
    double? monthlySalary,
    double? personalSalary,
    double? businessIncome,
    bool? personalAccountEnabled,
    bool? businessAccountEnabled,
    int? salaryDate,
    double? fixedDeductions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final nextMonthly = monthlySalary ?? this.monthlySalary;
    final nextPersonal = personalSalary ?? this.personalSalary;
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      monthlySalary: nextMonthly,
      personalSalary: nextPersonal,
      businessIncome: businessIncome ?? this.businessIncome,
      personalAccountEnabled: personalAccountEnabled ?? this.personalAccountEnabled,
      businessAccountEnabled: businessAccountEnabled ?? this.businessAccountEnabled,
      salaryDate: salaryDate ?? this.salaryDate,
      fixedDeductions: fixedDeductions ?? this.fixedDeductions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
