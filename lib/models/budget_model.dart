import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetModel {
  final String? id;
  final String category;
  final double amount;
  final String period; // 'monthly', 'weekly', 'yearly'
  final int month; // 1-12
  final int year;
  final DateTime createdAt;

  BudgetModel({
    this.id,
    required this.category,
    required this.amount,
    this.period = 'monthly',
    required this.month,
    required this.year,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'amount': amount,
      'period': period,
      'month': month,
      'year': year,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map, String id) {
    return BudgetModel(
      id: id,
      category: map['category'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      period: map['period'] ?? 'monthly',
      month: map['month'] ?? DateTime.now().month,
      year: map['year'] ?? DateTime.now().year,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
