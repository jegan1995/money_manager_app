// lib/models/net_worth_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class NetWorthItem {
  final String?  id;
  final String   userId;
  final String   type;       // 'asset' | 'liability'
  final String   category;
  final String   name;
  final double   value;
  final String?  note;
  final DateTime updatedAt;

  NetWorthItem({
    this.id,
    required this.userId,
    required this.type,
    required this.category,
    required this.name,
    required this.value,
    this.note,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'userId':    userId,
    'type':      type,
    'category':  category,
    'name':      name,
    'value':     value,
    'note':      note,
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory NetWorthItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return NetWorthItem(
      id:        doc.id,
      userId:    d['userId']   ?? '',
      type:      d['type']     ?? 'asset',
      category:  d['category'] ?? '',
      name:      d['name']     ?? '',
      value:     (d['value']   ?? 0).toDouble(),
      note:      d['note'],
      updatedAt: d['updatedAt'] != null
          ? (d['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  NetWorthItem copyWith({
    String? id, String? userId, String? type,
    String? category, String? name, double? value, String? note,
  }) => NetWorthItem(
    id:       id       ?? this.id,
    userId:   userId   ?? this.userId,
    type:     type     ?? this.type,
    category: category ?? this.category,
    name:     name     ?? this.name,
    value:    value    ?? this.value,
    note:     note     ?? this.note,
  );
}