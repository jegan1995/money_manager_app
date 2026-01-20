import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String type; // 'income', 'expense', 'transfer'
  final double amount;
  final String category;
  final String? subcategory;
  final String? paymentMethod;
  final DateTime date;
  final String? note;
  final String? fromAccount;
  final String? toAccount;
  final bool isRecurring;
  final String? recurringFrequency;
  final String? imageUrl; // Added for receipt images
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.subcategory,
    this.paymentMethod,
    required this.date,
    this.note,
    this.fromAccount,
    this.toAccount,
    this.isRecurring = false,
    this.recurringFrequency,
    this.imageUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'amount': amount,
      'category': category,
      'subcategory': subcategory,
      'paymentMethod': paymentMethod,
      'date': Timestamp.fromDate(date),
      'note': note,
      'fromAccount': fromAccount,
      'toAccount': toAccount,
      'isRecurring': isRecurring,
      'recurringFrequency': recurringFrequency,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create from Firestore document
  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      type: data['type'] ?? 'expense',
      amount: (data['amount'] ?? 0.0).toDouble(),
      category: data['category'] ?? '',
      subcategory: data['subcategory'],
      paymentMethod: data['paymentMethod'],
      date: (data['date'] as Timestamp).toDate(),
      note: data['note'],
      fromAccount: data['fromAccount'],
      toAccount: data['toAccount'],
      isRecurring: data['isRecurring'] ?? false,
      recurringFrequency: data['recurringFrequency'],
      imageUrl: data['imageUrl'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // Copy with method for creating modified copies
  TransactionModel copyWith({
    String? id,
    String? type,
    double? amount,
    String? category,
    String? subcategory,
    String? paymentMethod,
    DateTime? date,
    String? note,
    String? fromAccount,
    String? toAccount,
    bool? isRecurring,
    String? recurringFrequency,
    String? imageUrl,
    DateTime? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      date: date ?? this.date,
      note: note ?? this.note,
      fromAccount: fromAccount ?? this.fromAccount,
      toAccount: toAccount ?? this.toAccount,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringFrequency: recurringFrequency ?? this.recurringFrequency,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
