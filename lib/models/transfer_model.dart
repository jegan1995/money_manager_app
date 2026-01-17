import 'package:cloud_firestore/cloud_firestore.dart';

class TransferModel {
  final String? id;
  final String fromAccount;
  final String toAccount;
  final double amount;
  final DateTime date;
  final String? note;
  final DateTime createdAt;

  TransferModel({
    this.id,
    required this.fromAccount,
    required this.toAccount,
    required this.amount,
    required this.date,
    this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'fromAccount': fromAccount,
      'toAccount': toAccount,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory TransferModel.fromMap(Map<String, dynamic> map, String id) {
    return TransferModel(
      id: id,
      fromAccount: map['fromAccount'] ?? '',
      toAccount: map['toAccount'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      note: map['note'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  TransferModel copyWith({
    String? id,
    String? fromAccount,
    String? toAccount,
    double? amount,
    DateTime? date,
    String? note,
    DateTime? createdAt,
  }) {
    return TransferModel(
      id: id ?? this.id,
      fromAccount: fromAccount ?? this.fromAccount,
      toAccount: toAccount ?? this.toAccount,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}