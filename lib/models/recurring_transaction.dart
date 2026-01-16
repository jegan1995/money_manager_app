import 'package:cloud_firestore/cloud_firestore.dart';

class RecurringTransaction {
  final String id;
  final String title;
  final double amount;
  final String category;
  final String type;
  final String frequency; // 'daily', 'weekly', 'monthly', 'yearly'
  final DateTime startDate;
  final DateTime? endDate;
  final String? notes;
  final DateTime lastGenerated;

  RecurringTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.type,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.notes,
    required this.lastGenerated,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'category': category,
      'type': type,
      'frequency': frequency,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'notes': notes,
      'lastGenerated': Timestamp.fromDate(lastGenerated),
    };
  }

  factory RecurringTransaction.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return RecurringTransaction(
      id: doc.id,
      title: data['title'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      category: data['category'] ?? '',
      type: data['type'] ?? 'expense',
      frequency: data['frequency'] ?? 'monthly',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: data['endDate'] != null ? (data['endDate'] as Timestamp).toDate() : null,
      notes: data['notes'],
      lastGenerated: (data['lastGenerated'] as Timestamp).toDate(),
    );
  }
}
