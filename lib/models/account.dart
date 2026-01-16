import 'package:cloud_firestore/cloud_firestore.dart';

class Account {
  final String id;
  final String name;
  final String type; // 'bank', 'cash', 'card', 'wallet'
  final double balance;
  final String? icon;
  final DateTime createdDate;

  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.icon,
    required this.createdDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'balance': balance,
      'icon': icon,
      'createdDate': Timestamp.fromDate(createdDate),
    };
  }

  factory Account.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Account(
      id: doc.id,
      name: data['name'] ?? '',
      type: data['type'] ?? 'cash',
      balance: (data['balance'] ?? 0).toDouble(),
      icon: data['icon'],
      createdDate: (data['createdDate'] as Timestamp).toDate(),
    );
  }
}
