// lib/models/budget_planner_model.dart
// Extends existing BudgetModel concept with: custom date range + rollover
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetPlan {
  final String?  id;
  final String   userId;
  final String   category;
  final double   amount;          // planned budget
  final String   period;          // 'monthly' | 'custom'
  final int      month;           // used when period == 'monthly'
  final int      year;
  final DateTime? startDate;      // used when period == 'custom'
  final DateTime? endDate;
  final bool     rollover;        // carry unused amount to next month
  final double   rolloverAmount;  // amount rolled over from previous period
  final String?  emoji;           // optional custom icon
  final DateTime createdAt;

  BudgetPlan({
    this.id,
    required this.userId,
    required this.category,
    required this.amount,
    this.period      = 'monthly',
    int? month,
    int? year,
    this.startDate,
    this.endDate,
    this.rollover      = false,
    this.rolloverAmount = 0,
    this.emoji,
    DateTime? createdAt,
  })  : month      = month ?? DateTime.now().month,
        year       = year  ?? DateTime.now().year,
        createdAt  = createdAt ?? DateTime.now();

  // Effective budget = set amount + any rolled-over amount
  double get effectiveAmount => amount + rolloverAmount;

  // Date range for spending query
  DateTime get periodStart => period == 'custom' && startDate != null
      ? startDate!
      : DateTime(year, month, 1);

  DateTime get periodEnd => period == 'custom' && endDate != null
      ? endDate!.add(const Duration(days: 1))
      : DateTime(year, month + 1, 1);

  String get displayPeriod => period == 'custom' && startDate != null && endDate != null
      ? '${_fmt(startDate!)} – ${_fmt(endDate!)}'
      : _monthName(month, year);

  static String _fmt(DateTime d) =>
      '${d.day} ${_months[d.month - 1]}';

  static String _monthName(int m, int y) {
    final now = DateTime.now();
    if (m == now.month && y == now.year) return 'This Month';
    return '${_months[m - 1]} $y';
  }

  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'
  ];

  Map<String, dynamic> toMap() => {
    'userId':         userId,
    'category':       category,
    'amount':         amount,
    'period':         period,
    'month':          month,
    'year':           year,
    'startDate':      startDate  != null ? Timestamp.fromDate(startDate!)  : null,
    'endDate':        endDate    != null ? Timestamp.fromDate(endDate!)    : null,
    'rollover':       rollover,
    'rolloverAmount': rolloverAmount,
    'emoji':          emoji,
    'createdAt':      Timestamp.fromDate(createdAt),
  };

  factory BudgetPlan.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return BudgetPlan(
      id:             doc.id,
      userId:         d['userId']   ?? '',
      category:       d['category'] ?? '',
      amount:         (d['amount']  ?? 0).toDouble(),
      period:         d['period']   ?? 'monthly',
      month:          d['month']    ?? DateTime.now().month,
      year:           d['year']     ?? DateTime.now().year,
      startDate:      d['startDate'] != null
          ? (d['startDate'] as Timestamp).toDate() : null,
      endDate:        d['endDate'] != null
          ? (d['endDate'] as Timestamp).toDate() : null,
      rollover:       d['rollover']       ?? false,
      rolloverAmount: (d['rolloverAmount'] ?? 0).toDouble(),
      emoji:          d['emoji'],
      createdAt:      d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  BudgetPlan copyWith({
    String? id, String? userId, String? category,
    double? amount, String? period, int? month, int? year,
    DateTime? startDate, DateTime? endDate,
    bool? rollover, double? rolloverAmount, String? emoji,
  }) => BudgetPlan(
    id:             id             ?? this.id,
    userId:         userId         ?? this.userId,
    category:       category       ?? this.category,
    amount:         amount         ?? this.amount,
    period:         period         ?? this.period,
    month:          month          ?? this.month,
    year:           year           ?? this.year,
    startDate:      startDate      ?? this.startDate,
    endDate:        endDate        ?? this.endDate,
    rollover:       rollover       ?? this.rollover,
    rolloverAmount: rolloverAmount ?? this.rolloverAmount,
    emoji:          emoji          ?? this.emoji,
    createdAt:      createdAt,
  );
}

// ── Budget status for UI ──────────────────────────────────────────────────────
class BudgetStatus {
  final BudgetPlan plan;
  final double     spent;
  final double     remaining;
  final double     pct;           // 0.0–1.0+
  final bool       isOver;
  final bool       isNear;        // >80%

  const BudgetStatus({
    required this.plan,
    required this.spent,
    required this.remaining,
    required this.pct,
    required this.isOver,
    required this.isNear,
  });

  Color get statusColor {
    if (isOver)  return const Color(0xFFe53e3e);
    if (isNear)  return const Color(0xFFed8936);
    return const Color(0xFF48bb78);
  }
}