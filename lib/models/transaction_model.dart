import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String? id;
  final String type; // 'income', 'expense', or 'transfer'
  final double amount;
  final String category;
  final String? subcategory;
  final String? paymentMethod;
  final String? fromAccount;
  final String? toAccount;
  final DateTime date;
  final String? note;
  final DateTime createdAt;

  TransactionModel({
    this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.subcategory,
    this.paymentMethod,
    this.fromAccount,
    this.toAccount,
    required this.date,
    this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'amount': amount,
      'category': category,
      'subcategory': subcategory,
      'paymentMethod': paymentMethod,
      'fromAccount': fromAccount,
      'toAccount': toAccount,
      'date': Timestamp.fromDate(date),
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return TransactionModel(
      id: id,
      type: map['type'] ?? 'expense',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? 'Other',
      subcategory: map['subcategory'],
      paymentMethod: map['paymentMethod'],
      fromAccount: map['fromAccount'],
      toAccount: map['toAccount'],
      date: (map['date'] as Timestamp).toDate(),
      note: map['note'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  TransactionModel copyWith({
    String? id,
    String? type,
    double? amount,
    String? category,
    String? subcategory,
    String? paymentMethod,
    String? fromAccount,
    String? toAccount,
    DateTime? date,
    String? note,
    DateTime? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      fromAccount: fromAccount ?? this.fromAccount,
      toAccount: toAccount ?? this.toAccount,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
