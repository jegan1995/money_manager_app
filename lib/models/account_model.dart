import 'package:cloud_firestore/cloud_firestore.dart';

class AccountModel {
  final String? id;
  final String userId;
  final String name;
  final String type; // 'cash', 'bank', 'credit_card', 'loan', 'other'
  final double balance;
  final String? icon;
  final String? note;
  final DateTime createdAt;

  AccountModel({
    this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.balance,
    this.icon,
    this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'type': type,
      'balance': balance,
      'icon': icon,
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory AccountModel.fromMap(Map<String, dynamic> map, String id) {
    return AccountModel(
      id: id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'other',
      balance: (map['balance'] ?? 0).toDouble(),
      icon: map['icon'],
      note: map['note'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // ✅ NEW: Add fromFirestore method
  factory AccountModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AccountModel.fromMap(data, doc.id);
  }

  AccountModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? type,
    double? balance,
    String? icon,
    String? note,
    DateTime? createdAt,
  }) {
    return AccountModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      icon: icon ?? this.icon,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Helper to check if account is debt-based
  bool get isDebt => type == 'credit_card' || type == 'loan';

  // Helper to get display name for type
  String get typeDisplayName {
    switch (type) {
      case 'cash':
        return 'Cash';
      case 'bank':
        return 'Bank Account';
      case 'credit_card':
        return 'Credit Card';
      case 'loan':
        return 'Loan';
      default:
        return 'Other';
    }
  }
}
