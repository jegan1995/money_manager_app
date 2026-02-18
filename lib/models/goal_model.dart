import 'package:cloud_firestore/cloud_firestore.dart';

class GoalModel {
  final String? id;
  final String userId; // ✅ NEW: User ID field
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime targetDate;
  final String? description;
  final String? icon;
  final DateTime createdAt;
  final bool isCompleted;

  GoalModel({
    this.id,
    required this.userId, // ✅ NEW: Required field
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    required this.targetDate,
    this.description,
    this.icon,
    DateTime? createdAt,
    this.isCompleted = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'userId': userId, // ✅ NEW: Include in map
      'name': name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'targetDate': Timestamp.fromDate(targetDate),
      'description': description,
      'icon': icon,
      'createdAt': Timestamp.fromDate(createdAt),
      'isCompleted': isCompleted,
    };
  }

  factory GoalModel.fromMap(Map<String, dynamic> map, String id) {
    return GoalModel(
      id: id,
      userId: map['userId'] ?? '', // ✅ NEW: Read userId
      name: map['name'] ?? '',
      targetAmount: (map['targetAmount'] ?? 0).toDouble(),
      currentAmount: (map['currentAmount'] ?? 0).toDouble(),
      targetDate: (map['targetDate'] as Timestamp).toDate(),
      description: map['description'],
      icon: map['icon'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isCompleted: map['isCompleted'] ?? false,
    );
  }

  GoalModel copyWith({
    String? id,
    String? userId, // ✅ NEW: Added to copyWith
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    String? description,
    String? icon,
    DateTime? createdAt,
    bool? isCompleted,
  }) {
    return GoalModel(
      id: id ?? this.id,
      userId: userId ?? this.userId, // ✅ NEW
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  double get progress => (currentAmount / targetAmount * 100).clamp(0, 100);

  int get daysRemaining {
    final now = DateTime.now();
    return targetDate.difference(now).inDays;
  }

  bool get isOverdue => DateTime.now().isAfter(targetDate) && !isCompleted;
}
