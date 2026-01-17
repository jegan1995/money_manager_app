import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String? id;
  final String type; // 'income' or 'expense'
  final double amount;
  final String category;
  final String? subcategory; // NEW: Subcategory
  final String account; // NEW: Account name
  final String paymentMethod; // Now mandatory
  final DateTime date;
  final String? note;
  final String? imageUrl; // NEW: Receipt/bill image
  final DateTime createdAt;

  TransactionModel({
    this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.subcategory,
    required this.account,
    required this.paymentMethod,
    required this.date,
    this.note,
    this.imageUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert to Firestore
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'amount': amount,
      'category': category,
      'subcategory': subcategory,
      'account': account,
      'paymentMethod': paymentMethod,
      'date': Timestamp.fromDate(date),
      'note': note,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create from Firestore
  factory TransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return TransactionModel(
      id: id,
      type: map['type'] ?? 'expense',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? 'Other',
      subcategory: map['subcategory'],
      account: map['account'] ?? 'Cash',
      paymentMethod: map['paymentMethod'] ?? 'Cash',
      date: (map['date'] as Timestamp).toDate(),
      note: map['note'],
      imageUrl: map['imageUrl'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  // Copy with modifications
  TransactionModel copyWith({
    String? id,
    String? type,
    double? amount,
    String? category,
    String? subcategory,
    String? account,
    String? paymentMethod,
    DateTime? date,
    String? note,
    String? imageUrl,
    DateTime? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      account: account ?? this.account,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      date: date ?? this.date,
      note: note ?? this.note,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}