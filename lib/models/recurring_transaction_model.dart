import 'package:cloud_firestore/cloud_firestore.dart';

class RecurringTransactionModel {
  final String id;
  final String userId;
  final String type; // 'income' or 'expense'
  final double amount;
  final String category;
  final String? subcategory;
  final String? fromAccount; // For expenses
  final String? toAccount; // For income
  final String frequency; // 'daily', 'weekly', 'monthly', 'yearly'
  final DateTime nextDate;
  final DateTime? lastExecuted;
  final bool isActive;
  final String? note;
  final DateTime createdAt;

  RecurringTransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.category,
    this.subcategory,
    this.fromAccount,
    this.toAccount,
    required this.frequency,
    required this.nextDate,
    this.lastExecuted,
    required this.isActive,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'amount': amount,
      'category': category,
      'subcategory': subcategory,
      'fromAccount': fromAccount,
      'toAccount': toAccount,
      'frequency': frequency,
      'nextDate': Timestamp.fromDate(nextDate),
      'lastExecuted':
          lastExecuted != null ? Timestamp.fromDate(lastExecuted!) : null,
      'isActive': isActive,
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory RecurringTransactionModel.fromMap(
      Map<String, dynamic> map, String id) {
    return RecurringTransactionModel(
      id: id,
      userId: map['userId'] ?? '',
      type: map['type'] ?? 'expense',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? '',
      subcategory: map['subcategory'],
      fromAccount: map['fromAccount'],
      toAccount: map['toAccount'],
      frequency: map['frequency'] ?? 'monthly',
      nextDate: (map['nextDate'] as Timestamp).toDate(),
      lastExecuted: map['lastExecuted'] != null
          ? (map['lastExecuted'] as Timestamp).toDate()
          : null,
      isActive: map['isActive'] ?? true,
      note: map['note'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  factory RecurringTransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RecurringTransactionModel.fromMap(data, doc.id);
  }
}
