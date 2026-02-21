import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String userId; // ✅ NEW: User ID field
  final String type;
  final double amount;
  final String category;
  final String? subcategory;
  final String? paymentMethod;
  final DateTime date;
  final String? note;
  final String? description;
  final String? fromAccount;
  final String? toAccount;
  final bool isRecurring;
  final String? recurringFrequency;
  final String? imageUrl;
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.userId, // ✅ NEW: Required field
    required this.type,
    required this.amount,
    required this.category,
    this.subcategory,
    this.paymentMethod,
    required this.date,
    this.note,
    this.description,
    this.fromAccount,
    this.toAccount,
    this.isRecurring = false,
    this.recurringFrequency,
    this.imageUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'userId': userId, // ✅ NEW: Include in map
      'type': type,
      'amount': amount,
      'category': category,
      'subcategory': subcategory,
      'paymentMethod': paymentMethod,
      'date': Timestamp.fromDate(date),
      'note': note,
      'description': description,
      'fromAccount': fromAccount,
      'toAccount': toAccount,
      'isRecurring': isRecurring,
      'recurringFrequency': recurringFrequency,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      userId: data['userId'] ?? '', // ✅ NEW: Read userId
      type: data['type'] ?? 'expense',
      amount: (data['amount'] ?? 0.0).toDouble(),
      category: data['category'] ?? '',
      subcategory: data['subcategory'],
      paymentMethod: data['paymentMethod'],
      date: (data['date'] as Timestamp).toDate(),
      note: data['note'],
      description: data['description'],
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

  TransactionModel copyWith({
    String? id,
    String? userId, // ✅ NEW: Added to copyWith
    String? type,
    double? amount,
    String? category,
    String? subcategory,
    String? paymentMethod,
    DateTime? date,
    String? note,
    String? description,
    String? fromAccount,
    String? toAccount,
    bool? isRecurring,
    String? recurringFrequency,
    String? imageUrl,
    DateTime? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId, // ✅ NEW
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      date: date ?? this.date,
      note: note ?? this.note,
      description: description ?? this.description,
      fromAccount: fromAccount ?? this.fromAccount,
      toAccount: toAccount ?? this.toAccount,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringFrequency: recurringFrequency ?? this.recurringFrequency,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
