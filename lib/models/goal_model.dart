import 'package:cloud_firestore/cloud_firestore.dart';

class GoalModel {
  final String? id;
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

  double get progress => (currentAmount / targetAmount * 100).clamp(0, 100);

  int get daysRemaining {
    final now = DateTime.now();
    return targetDate.difference(now).inDays;
  }

  bool get isOverdue => DateTime.now().isAfter(targetDate) && !isCompleted;
}
