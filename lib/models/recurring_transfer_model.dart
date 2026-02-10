import 'package:cloud_firestore/cloud_firestore.dart';

class RecurringTransferModel {
  final String? id;
  final String title;
  final double amount;
  final String fromAccountId;
  final String toAccountId;
  final String frequency; // daily, weekly, monthly, yearly
  final DateTime startDate;
  final String? note;
  final bool isActive;
  final DateTime? lastExecuted;
  final DateTime createdAt;

  RecurringTransferModel({
    this.id,
    required this.title,
    required this.amount,
    required this.fromAccountId,
    required this.toAccountId,
    required this.frequency,
    required this.startDate,
    this.note,
    this.isActive = true,
    this.lastExecuted,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'fromAccountId': fromAccountId,
      'toAccountId': toAccountId,
      'frequency': frequency,
      'startDate': Timestamp.fromDate(startDate),
      'note': note,
      'isActive': isActive,
      'lastExecuted': lastExecuted != null ? Timestamp.fromDate(lastExecuted!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory RecurringTransferModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RecurringTransferModel(
      id: doc.id,
      title: data['title'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      fromAccountId: data['fromAccountId'] ?? '',
      toAccountId: data['toAccountId'] ?? '',
      frequency: data['frequency'] ?? 'monthly',
      startDate: (data['startDate'] as Timestamp).toDate(),
      note: data['note'],
      isActive: data['isActive'] ?? true,
      lastExecuted: data['lastExecuted'] != null ? (data['lastExecuted'] as Timestamp).toDate() : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  RecurringTransferModel copyWith({
    String? id,
    String? title,
    double? amount,
    String? fromAccountId,
    String? toAccountId,
    String? frequency,
    DateTime? startDate,
    String? note,
    bool? isActive,
    DateTime? lastExecuted,
    DateTime? createdAt,
  }) {
    return RecurringTransferModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      fromAccountId: fromAccountId ?? this.fromAccountId,
      toAccountId: toAccountId ?? this.toAccountId,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      note: note ?? this.note,
      isActive: isActive ?? this.isActive,
      lastExecuted: lastExecuted ?? this.lastExecuted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}