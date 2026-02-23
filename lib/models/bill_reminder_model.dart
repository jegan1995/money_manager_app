import 'package:cloud_firestore/cloud_firestore.dart';

class BillReminderModel {
  final String id;
  final String userId;
  final String name;
  final double amount;
  final int dueDayOfMonth; // 1–31
  final String category;
  final String? accountId;
  final bool isActive;
  final bool isAutoPay;
  final String repeatType; // monthly, yearly, one_time
  final DateTime? nextDueDate;
  final DateTime? lastPaidDate;
  final String? note;
  final DateTime createdAt;

  BillReminderModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.amount,
    required this.dueDayOfMonth,
    required this.category,
    this.accountId,
    this.isActive = true,
    this.isAutoPay = false,
    this.repeatType = 'monthly',
    this.nextDueDate,
    this.lastPaidDate,
    this.note,
    required this.createdAt,
  });

  // How many days until due (negative = overdue)
  int get daysUntilDue {
    if (nextDueDate == null) return 999;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(nextDueDate!.year, nextDueDate!.month, nextDueDate!.day);
    return due.difference(today).inDays;
  }

  String get statusLabel {
    final d = daysUntilDue;
    if (d < 0) return 'Overdue by ${d.abs()} day${d.abs() > 1 ? 's' : ''}';
    if (d == 0) return 'Due Today!';
    if (d == 1) return 'Due Tomorrow';
    if (d <= 7) return 'Due in $d days';
    return 'Due in $d days';
  }

  String get statusColor {
    final d = daysUntilDue;
    if (d < 0) return 'red';
    if (d == 0) return 'red';
    if (d <= 3) return 'orange';
    if (d <= 7) return 'yellow';
    return 'green';
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'name': name,
        'amount': amount,
        'dueDayOfMonth': dueDayOfMonth,
        'category': category,
        'accountId': accountId,
        'isActive': isActive,
        'isAutoPay': isAutoPay,
        'repeatType': repeatType,
        'nextDueDate': nextDueDate != null ? Timestamp.fromDate(nextDueDate!) : null,
        'lastPaidDate': lastPaidDate != null ? Timestamp.fromDate(lastPaidDate!) : null,
        'note': note,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory BillReminderModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return BillReminderModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      name: d['name'] ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      dueDayOfMonth: d['dueDayOfMonth'] ?? 1,
      category: d['category'] ?? 'Bills & Utilities',
      accountId: d['accountId'],
      isActive: d['isActive'] ?? true,
      isAutoPay: d['isAutoPay'] ?? false,
      repeatType: d['repeatType'] ?? 'monthly',
      nextDueDate: (d['nextDueDate'] as Timestamp?)?.toDate(),
      lastPaidDate: (d['lastPaidDate'] as Timestamp?)?.toDate(),
      note: d['note'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  BillReminderModel copyWith({
    String? id,
    String? name,
    double? amount,
    int? dueDayOfMonth,
    String? category,
    String? accountId,
    bool? isActive,
    bool? isAutoPay,
    String? repeatType,
    DateTime? nextDueDate,
    DateTime? lastPaidDate,
    String? note,
  }) =>
      BillReminderModel(
        id: id ?? this.id,
        userId: userId,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        dueDayOfMonth: dueDayOfMonth ?? this.dueDayOfMonth,
        category: category ?? this.category,
        accountId: accountId ?? this.accountId,
        isActive: isActive ?? this.isActive,
        isAutoPay: isAutoPay ?? this.isAutoPay,
        repeatType: repeatType ?? this.repeatType,
        nextDueDate: nextDueDate ?? this.nextDueDate,
        lastPaidDate: lastPaidDate ?? this.lastPaidDate,
        note: note ?? this.note,
        createdAt: createdAt,
      );
}