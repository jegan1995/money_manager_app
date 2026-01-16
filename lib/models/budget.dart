import 'package:cloud_firestore/cloud_firestore.dart';

class Budget {
  final String id;
  final String category;
  final double amount;
  final String period; // 'monthly', 'yearly'
  final DateTime createdDate;

  Budget({
    required this.id,
    required this.category,
    required this.amount,
    required this.period,
    required this.createdDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'amount': amount,
      'period': period,
      'createdDate': Timestamp.fromDate(createdDate),
    };
  }

  factory Budget.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Budget(
      id: doc.id,
      category: data['category'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      period: data['period'] ?? 'monthly',
      createdDate: (data['createdDate'] as Timestamp).toDate(),
    );
  }
}
