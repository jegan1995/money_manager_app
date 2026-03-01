// lib/models/bill_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class BillModel {
  final String? id;
  final String  userId;
  final String  name;
  final String  category;  // electricity, water, rent, phone, internet, insurance, gas, other
  final double  amount;
  final int     dueDayOfMonth; // 1-31, which day of month bill is due
  final String  frequency;     // monthly, quarterly, yearly, once
  final DateTime? dueDate;     // for one-time or next due
  final String  status;        // pending, paid, overdue
  final String? accountId;     // which account to pay from
  final String? note;
  final bool    remindMe;
  final int     remindDaysBefore;
  final DateTime? paidDate;
  final DateTime  createdAt;

  BillModel({
    this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.amount,
    required this.dueDayOfMonth,
    this.frequency = 'monthly',
    this.dueDate,
    this.status = 'pending',
    this.accountId,
    this.note,
    this.remindMe = true,
    this.remindDaysBefore = 3,
    this.paidDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isPaid    => status == 'paid';
  bool get isOverdue => !isPaid && nextDueDate.isBefore(DateTime.now());
  bool get isDueSoon {
    if (isPaid) return false;
    final d = nextDueDate.difference(DateTime.now()).inDays;
    return d >= 0 && d <= remindDaysBefore;
  }

  int get daysUntilDue => nextDueDate.difference(DateTime.now()).inDays;

  DateTime get nextDueDate {
    if (dueDate != null && frequency == 'once') return dueDate!;
    final now = DateTime.now();
    var candidate = DateTime(now.year, now.month, dueDayOfMonth.clamp(1, 28));
    if (candidate.isBefore(now)) {
      switch (frequency) {
        case 'monthly':   candidate = DateTime(now.year, now.month + 1, dueDayOfMonth.clamp(1, 28)); break;
        case 'quarterly': candidate = DateTime(now.year, now.month + 3, dueDayOfMonth.clamp(1, 28)); break;
        case 'yearly':    candidate = DateTime(now.year + 1, now.month, dueDayOfMonth.clamp(1, 28)); break;
        default: candidate = DateTime(now.year, now.month + 1, dueDayOfMonth.clamp(1, 28));
      }
    }
    return candidate;
  }

  Map<String, dynamic> toMap() => {
    'userId':            userId,
    'name':              name,
    'category':          category,
    'amount':            amount,
    'dueDayOfMonth':     dueDayOfMonth,
    'frequency':         frequency,
    'dueDate':           dueDate != null ? Timestamp.fromDate(dueDate!) : null,
    'status':            status,
    'accountId':         accountId,
    'note':              note,
    'remindMe':          remindMe,
    'remindDaysBefore':  remindDaysBefore,
    'paidDate':          paidDate != null ? Timestamp.fromDate(paidDate!) : null,
    'createdAt':         Timestamp.fromDate(createdAt),
  };

  factory BillModel.fromMap(Map<String, dynamic> m, String id) => BillModel(
    id:               id,
    userId:           m['userId'] ?? '',
    name:             m['name'] ?? '',
    category:         m['category'] ?? 'other',
    amount:           (m['amount'] ?? 0).toDouble(),
    dueDayOfMonth:    m['dueDayOfMonth'] ?? 1,
    frequency:        m['frequency'] ?? 'monthly',
    dueDate:          m['dueDate'] != null ? (m['dueDate'] as Timestamp).toDate() : null,
    status:           m['status'] ?? 'pending',
    accountId:        m['accountId'],
    note:             m['note'],
    remindMe:         m['remindMe'] ?? true,
    remindDaysBefore: m['remindDaysBefore'] ?? 3,
    paidDate:         m['paidDate'] != null ? (m['paidDate'] as Timestamp).toDate() : null,
    createdAt:        m['createdAt'] != null
        ? (m['createdAt'] as Timestamp).toDate() : DateTime.now(),
  );

  factory BillModel.fromFirestore(DocumentSnapshot doc) =>
      BillModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

  BillModel copyWith({
    String? id, String? userId, String? name, String? category,
    double? amount, int? dueDayOfMonth, String? frequency,
    DateTime? dueDate, String? status, String? accountId,
    String? note, bool? remindMe, int? remindDaysBefore,
    DateTime? paidDate,
  }) => BillModel(
    id: id ?? this.id, userId: userId ?? this.userId,
    name: name ?? this.name, category: category ?? this.category,
    amount: amount ?? this.amount,
    dueDayOfMonth: dueDayOfMonth ?? this.dueDayOfMonth,
    frequency: frequency ?? this.frequency,
    dueDate: dueDate ?? this.dueDate,
    status: status ?? this.status,
    accountId: accountId ?? this.accountId,
    note: note ?? this.note, remindMe: remindMe ?? this.remindMe,
    remindDaysBefore: remindDaysBefore ?? this.remindDaysBefore,
    paidDate: paidDate ?? this.paidDate,
    createdAt: createdAt,
  );
}