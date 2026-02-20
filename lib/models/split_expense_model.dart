import 'package:cloud_firestore/cloud_firestore.dart';

class SplitExpenseModel {
  final String id;
  final String userId;
  final String description;
  final double totalAmount;
  final List<SplitPerson> splits;
  final DateTime date;
  final String? category;
  final bool isSettled;
  final DateTime createdAt;

  SplitExpenseModel({
    required this.id,
    required this.userId,
    required this.description,
    required this.totalAmount,
    required this.splits,
    required this.date,
    this.category,
    this.isSettled = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'description': description,
      'totalAmount': totalAmount,
      'splits': splits.map((s) => s.toMap()).toList(),
      'date': Timestamp.fromDate(date),
      'category': category,
      'isSettled': isSettled,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory SplitExpenseModel.fromMap(Map<String, dynamic> map, String id) {
    return SplitExpenseModel(
      id: id,
      userId: map['userId'] ?? '',
      description: map['description'] ?? '',
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      splits: (map['splits'] as List)
          .map((s) => SplitPerson.fromMap(s as Map<String, dynamic>))
          .toList(),
      date: (map['date'] as Timestamp).toDate(),
      category: map['category'],
      isSettled: map['isSettled'] ?? false,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  factory SplitExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SplitExpenseModel.fromMap(data, doc.id);
  }
}

class SplitPerson {
  final String name;
  final double amount;
  final bool isPaid;

  SplitPerson({
    required this.name,
    required this.amount,
    this.isPaid = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'isPaid': isPaid,
    };
  }

  factory SplitPerson.fromMap(Map<String, dynamic> map) {
    return SplitPerson(
      name: map['name'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      isPaid: map['isPaid'] ?? false,
    );
  }

  SplitPerson copyWith({String? name, double? amount, bool? isPaid}) {
    return SplitPerson(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      isPaid: isPaid ?? this.isPaid,
    );
  }
}
