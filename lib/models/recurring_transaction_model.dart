import 'package:cloud_firestore/cloud_firestore.dart';

class RecurringTransactionModel {
  final String? id;
  final String type;
  final double amount;
  final String category;
  final String? subcategory;
  final String? paymentMethod;
  final String frequency; // 'daily', 'weekly', 'monthly', 'yearly'
  final DateTime startDate;
  final DateTime? endDate;
  final String? note;
  final bool isActive;
  final DateTime createdAt;

  RecurringTransactionModel({
    this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.subcategory,
    this.paymentMethod,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.note,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'amount': amount,
      'category': category,
      'subcategory': subcategory,
      'paymentMethod': paymentMethod,
      'frequency': frequency,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'note': note,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory RecurringTransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return RecurringTransactionModel(
      id: id,
      type: map['type'] ?? 'expense',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? 'Other',
      subcategory: map['subcategory'],
      paymentMethod: map['paymentMethod'],
      frequency: map['frequency'] ?? 'monthly',
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: map['endDate'] != null ? (map['endDate'] as Timestamp).toDate() : null,
      note: map['note'],
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
