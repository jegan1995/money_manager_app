import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetAlertModel {
  final String id;
  final String budgetId;
  final String category;
  final double budgetAmount;
  final double spentAmount;
  final double percentage;
  final String alertType; // 'warning', 'critical', 'exceeded'
  final DateTime date;
  final bool isRead;

  BudgetAlertModel({
    required this.id,
    required this.budgetId,
    required this.category,
    required this.budgetAmount,
    required this.spentAmount,
    required this.percentage,
    required this.alertType,
    required this.date,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'budgetId': budgetId,
      'category': category,
      'budgetAmount': budgetAmount,
      'spentAmount': spentAmount,
      'percentage': percentage,
      'alertType': alertType,
      'date': Timestamp.fromDate(date),
      'isRead': isRead,
    };
  }

  factory BudgetAlertModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BudgetAlertModel(
      id: doc.id,
      budgetId: data['budgetId'] ?? '',
      category: data['category'] ?? '',
      budgetAmount: (data['budgetAmount'] ?? 0).toDouble(),
      spentAmount: (data['spentAmount'] ?? 0).toDouble(),
      percentage: (data['percentage'] ?? 0).toDouble(),
      alertType: data['alertType'] ?? 'warning',
      date: (data['date'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
    );
  }

  String get message {
    if (percentage >= 100) {
      return 'Budget exceeded for $category! Spent ₹${spentAmount.toStringAsFixed(0)} of ₹${budgetAmount.toStringAsFixed(0)}';
    } else if (percentage >= 90) {
      return 'Critical: $category budget at ${percentage.toStringAsFixed(0)}%';
    } else if (percentage >= 75) {
      return 'Warning: $category budget at ${percentage.toStringAsFixed(0)}%';
    } else {
      return '$category budget at ${percentage.toStringAsFixed(0)}%';
    }
  }

  String get icon {
    if (percentage >= 100) return '🚨';
    if (percentage >= 90) return '⚠️';
    if (percentage >= 75) return '📊';
    return '💡';
  }

  BudgetAlertModel copyWith({
    String? id,
    String? budgetId,
    String? category,
    double? budgetAmount,
    double? spentAmount,
    double? percentage,
    String? alertType,
    DateTime? date,
    bool? isRead,
  }) {
    return BudgetAlertModel(
      id: id ?? this.id,
      budgetId: budgetId ?? this.budgetId,
      category: category ?? this.category,
      budgetAmount: budgetAmount ?? this.budgetAmount,
      spentAmount: spentAmount ?? this.spentAmount,
      percentage: percentage ?? this.percentage,
      alertType: alertType ?? this.alertType,
      date: date ?? this.date,
      isRead: isRead ?? this.isRead,
    );
  }
}