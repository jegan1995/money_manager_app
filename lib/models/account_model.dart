import 'package:cloud_firestore/cloud_firestore.dart';

class AccountModel {
  final String? id;
  final String userId;
  final String name;
  final String type; // 'cash', 'bank', 'credit_card', 'loan', 'other'
  final double balance;
  final String? icon;
  final String? color;  // hex string e.g. '#667eea'
  final String? note;
  final DateTime createdAt;

  AccountModel({
    this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.balance,
    this.icon,
    this.color,
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
      'color': color,
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
      color: map['color'],
      note: map['note'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

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
    String? color,
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
      color: color ?? this.color,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Parse hex color string to Color int
  int get colorValue {
    if (color != null && color!.startsWith('#')) {
      try {
        return int.parse('FF${color!.substring(1)}', radix: 16);
      } catch (_) {}
    }
    // Default colors by type
    switch (type) {
      case 'cash':        return 0xFF2E7D32;
      case 'bank':        return 0xFF1565C0;
      case 'card':        return 0xFF00838F;
      case 'credit_card': return 0xFF6A1B9A;
      case 'wallet':      return 0xFFF57F17;
      case 'loan':        return 0xFFC62828;
      default:            return 0xFF546E7A;
    }
  }

  bool get isDebt => type == 'credit_card' || type == 'loan';

  String get typeDisplayName {
    switch (type) {
      case 'cash':        return 'Cash';
      case 'bank':        return 'Bank Account';
      case 'credit_card': return 'Credit Card';
      case 'loan':        return 'Loan';
      case 'wallet':      return 'Digital Wallet';
      default:            return 'Other';
    }
  }
}