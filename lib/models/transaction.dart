import 'package:cloud_firestore/cloud_firestore.dart';

class Transaction {
  final String id;
  final String title;
  final double amount;
  final String category;
  final String type;
  final DateTime date;
  final String? notes;
  final String? paymentMethod;
  final String? accountId;
  final List<String>? tags;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.type,
    required this.date,
    this.notes,
    this.paymentMethod,
    this.accountId,
    this.tags,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'category': category,
      'type': type,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'paymentMethod': paymentMethod,
      'accountId': accountId,
      'tags': tags,
    };
  }

  factory Transaction.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Transaction(
      id: doc.id,
      title: data['title'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      category: data['category'] ?? '',
      type: data['type'] ?? 'expense',
      date: (data['date'] as Timestamp).toDate(),
      notes: data['notes'],
      paymentMethod: data['paymentMethod'],
      accountId: data['accountId'],
      tags: data['tags'] != null ? List<String>.from(data['tags']) : null,
    );
  }
}
