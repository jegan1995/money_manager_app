import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetModel {
  final String id;
  final String category;
  final double amount;
  final int month;
  final int year;
  final DateTime createdAt;

  BudgetModel({
    required this.id,
    required this.category,
    required this.amount,
    required this.month,
    required this.year,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'amount': amount,
      'month': month,
      'year': year,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory BudgetModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BudgetModel(
      id: doc.id,
      category: data['category'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      month: data['month'] ?? DateTime.now().month,
      year: data['year'] ?? DateTime.now().year,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  BudgetModel copyWith({
    String? id,
    String? category,
    double? amount,
    int? month,
    int? year,
    DateTime? createdAt,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      month: month ?? this.month,
      year: year ?? this.year,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
