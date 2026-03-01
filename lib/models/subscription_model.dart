// lib/models/subscription_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionModel {
  final String? id;
  final String  userId;
  final String  name;
  final String  category;   // streaming, music, fitness, productivity, food, other
  final double  amount;
  final String  cycle;      // monthly, yearly, weekly, quarterly
  final DateTime startDate;
  final DateTime nextBilling;
  final String  status;     // active, paused, cancelled
  final String? note;
  final String? color;      // hex color string
  final String? icon;       // emoji
  final bool    remindMe;
  final int     remindDaysBefore;
  final DateTime createdAt;

  SubscriptionModel({
    this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.amount,
    required this.cycle,
    required this.startDate,
    required this.nextBilling,
    this.status = 'active',
    this.note,
    this.color,
    this.icon,
    this.remindMe = true,
    this.remindDaysBefore = 3,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Computed
  double get monthlyEquivalent {
    switch (cycle) {
      case 'weekly':    return amount * 4.33;
      case 'monthly':   return amount;
      case 'quarterly': return amount / 3;
      case 'yearly':    return amount / 12;
      default:          return amount;
    }
  }

  double get yearlyEquivalent {
    switch (cycle) {
      case 'weekly':    return amount * 52;
      case 'monthly':   return amount * 12;
      case 'quarterly': return amount * 4;
      case 'yearly':    return amount;
      default:          return amount;
    }
  }

  bool get isActive    => status == 'active';
  bool get isDueSoon   => nextBilling.difference(DateTime.now()).inDays <= remindDaysBefore;
  bool get isOverdue   => nextBilling.isBefore(DateTime.now());

  DateTime nextBillingAfter(DateTime from) {
    DateTime next = nextBilling;
    while (next.isBefore(from)) {
      switch (cycle) {
        case 'weekly':    next = DateTime(next.year, next.month, next.day + 7); break;
        case 'monthly':   next = DateTime(next.year, next.month + 1, next.day); break;
        case 'quarterly': next = DateTime(next.year, next.month + 3, next.day); break;
        case 'yearly':    next = DateTime(next.year + 1, next.month, next.day); break;
        default:          next = DateTime(next.year, next.month + 1, next.day);
      }
    }
    return next;
  }

  Map<String, dynamic> toMap() => {
    'userId':            userId,
    'name':              name,
    'category':          category,
    'amount':            amount,
    'cycle':             cycle,
    'startDate':         Timestamp.fromDate(startDate),
    'nextBilling':       Timestamp.fromDate(nextBilling),
    'status':            status,
    'note':              note,
    'color':             color,
    'icon':              icon,
    'remindMe':          remindMe,
    'remindDaysBefore':  remindDaysBefore,
    'createdAt':         Timestamp.fromDate(createdAt),
  };

  factory SubscriptionModel.fromMap(Map<String, dynamic> m, String id) =>
      SubscriptionModel(
        id:                id,
        userId:            m['userId'] ?? '',
        name:              m['name'] ?? '',
        category:          m['category'] ?? 'other',
        amount:            (m['amount'] ?? 0).toDouble(),
        cycle:             m['cycle'] ?? 'monthly',
        startDate:         (m['startDate'] as Timestamp).toDate(),
        nextBilling:       (m['nextBilling'] as Timestamp).toDate(),
        status:            m['status'] ?? 'active',
        note:              m['note'],
        color:             m['color'],
        icon:              m['icon'],
        remindMe:          m['remindMe'] ?? true,
        remindDaysBefore:  m['remindDaysBefore'] ?? 3,
        createdAt:         m['createdAt'] != null
            ? (m['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );

  factory SubscriptionModel.fromFirestore(DocumentSnapshot doc) =>
      SubscriptionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

  SubscriptionModel copyWith({
    String? id, String? userId, String? name, String? category,
    double? amount, String? cycle, DateTime? startDate, DateTime? nextBilling,
    String? status, String? note, String? color, String? icon,
    bool? remindMe, int? remindDaysBefore,
  }) => SubscriptionModel(
    id: id ?? this.id, userId: userId ?? this.userId,
    name: name ?? this.name, category: category ?? this.category,
    amount: amount ?? this.amount, cycle: cycle ?? this.cycle,
    startDate: startDate ?? this.startDate,
    nextBilling: nextBilling ?? this.nextBilling,
    status: status ?? this.status, note: note ?? this.note,
    color: color ?? this.color, icon: icon ?? this.icon,
    remindMe: remindMe ?? this.remindMe,
    remindDaysBefore: remindDaysBefore ?? this.remindDaysBefore,
    createdAt: createdAt,
  );
}