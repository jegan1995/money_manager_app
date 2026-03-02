// lib/models/loan_model.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Loan types ────────────────────────────────────────────────────────────────
enum LoanType {
  home, car, personal, education, business, other;

  String get label => switch (this) {
    LoanType.home      => 'Home Loan',
    LoanType.car       => 'Car Loan',
    LoanType.personal  => 'Personal Loan',
    LoanType.education => 'Education Loan',
    LoanType.business  => 'Business Loan',
    LoanType.other     => 'Other Loan',
  };

  String get emoji => switch (this) {
    LoanType.home      => '🏠',
    LoanType.car       => '🚗',
    LoanType.personal  => '👤',
    LoanType.education => '🎓',
    LoanType.business  => '🏢',
    LoanType.other     => '💳',
  };

  Color get color => switch (this) {
    LoanType.home      => const Color(0xFF667eea),
    LoanType.car       => const Color(0xFF4facfe),
    LoanType.personal  => const Color(0xFFfa709a),
    LoanType.education => const Color(0xFF43e97b),
    LoanType.business  => const Color(0xFFf9ca24),
    LoanType.other     => const Color(0xFFb0bec5),
  };

  static LoanType fromString(String s) =>
      LoanType.values.firstWhere((e) => e.name == s,
          orElse: () => LoanType.other);
}

// ── Loan model ────────────────────────────────────────────────────────────────
class LoanModel {
  final String?   id;
  final String    userId;
  final String    name;           // "SBI Home Loan"
  final LoanType  type;
  final double    principal;      // original loan amount
  final double    annualRate;     // annual interest rate %
  final int       tenureMonths;   // total months
  final DateTime  startDate;
  final double    extraPayments;  // cumulative prepayments made
  final String?   lenderName;
  final String?   accountNumber;
  final String?   note;
  final bool      isActive;
  final DateTime  createdAt;

  LoanModel({
    this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.principal,
    required this.annualRate,
    required this.tenureMonths,
    required this.startDate,
    this.extraPayments  = 0,
    this.lenderName,
    this.accountNumber,
    this.note,
    this.isActive       = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // ── EMI formula: P × r × (1+r)^n / ((1+r)^n - 1) ────────────────────────
  double get monthlyRate => annualRate / 12 / 100;

  double get emi {
    if (annualRate == 0) return principal / tenureMonths;
    final r = monthlyRate;
    final n = tenureMonths;
    final pow = (1 + r);
    double powN = 1;
    for (int i = 0; i < n; i++) powN *= pow;
    return principal * r * powN / (powN - 1);
  }

  double get totalPayable => emi * tenureMonths;
  double get totalInterest => totalPayable - principal;

  // Months elapsed since start
  int get monthsElapsed {
    final now = DateTime.now();
    return ((now.year - startDate.year) * 12 +
            (now.month - startDate.month))
        .clamp(0, tenureMonths);
  }

  double get amountPaid     => emi * monthsElapsed + extraPayments;
  double get principalPaid  => (amountPaid - interestPaid).clamp(0, principal);
  double get interestPaid {
    // Sum of interest from amortization up to monthsElapsed
    double totalInt = 0;
    double balance  = principal;
    final r = monthlyRate;
    for (int i = 0; i < monthsElapsed; i++) {
      final interest = balance * r;
      totalInt += interest;
      balance  -= (emi - interest);
      if (balance <= 0) break;
    }
    return totalInt.clamp(0, totalInterest);
  }

  double get outstandingBalance {
    double balance = principal;
    final r = monthlyRate;
    for (int i = 0; i < monthsElapsed; i++) {
      balance = balance * (1 + r) - emi;
      if (balance <= 0) return 0;
    }
    return (balance - extraPayments).clamp(0, principal);
  }

  double get progressPct =>
      (amountPaid / totalPayable).clamp(0.0, 1.0);

  DateTime get expectedEndDate =>
      DateTime(startDate.year, startDate.month + tenureMonths);

  int get monthsRemaining =>
      (tenureMonths - monthsElapsed).clamp(0, tenureMonths);

  // ── Amortization schedule ─────────────────────────────────────────────────
  List<AmortizationRow> get schedule {
    final rows    = <AmortizationRow>[];
    double balance = principal;
    final r       = monthlyRate;
    final e       = emi;
    for (int i = 1; i <= tenureMonths; i++) {
      if (balance <= 0) break;
      final interest  = balance * r;
      final prinPart  = (e - interest).clamp(0.0, balance);
      balance        -= prinPart;
      final date      = DateTime(
          startDate.year, startDate.month + i);
      rows.add(AmortizationRow(
        month:      i,
        date:       date,
        emi:        e,
        principal:  prinPart,
        interest:   interest,
        balance:    balance.clamp(0.0, principal),
        isPaid:     i <= monthsElapsed,
      ));
    }
    return rows;
  }

  // ── Prepayment simulation ─────────────────────────────────────────────────
  PrepaymentResult simulate(double extraAmount) {
    double balance   = outstandingBalance;
    final r          = monthlyRate;
    final e          = emi;
    balance         -= extraAmount;
    if (balance <= 0) {
      return PrepaymentResult(
        newMonths:       0,
        savedInterest:   0,
        savedMonths:     monthsRemaining,
        newEndDate:      DateTime.now(),
      );
    }
    int months = 0;
    double interest = 0;
    while (balance > 0 && months < 1200) {
      final imt = balance * r;
      final pp  = (e - imt).clamp(0.0, balance);
      interest += imt;
      balance  -= pp;
      months++;
    }
    final origInterestLeft = remainingInterest();
    return PrepaymentResult(
      newMonths:     months,
      savedInterest: (origInterestLeft - interest).clamp(0, origInterestLeft),
      savedMonths:   monthsRemaining - months,
      newEndDate:    DateTime(DateTime.now().year,
          DateTime.now().month + months),
    );
  }

  double remainingInterest() {
    double balance = outstandingBalance;
    final r = monthlyRate;
    final e = emi;
    double interest = 0;
    while (balance > 0) {
      final imt = balance * r;
      interest += imt;
      balance  -= (e - imt).clamp(0.0, balance);
    }
    return interest;
  }

  // ── Firestore ─────────────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
    'userId':        userId,
    'name':          name,
    'type':          type.name,
    'principal':     principal,
    'annualRate':    annualRate,
    'tenureMonths':  tenureMonths,
    'startDate':     Timestamp.fromDate(startDate),
    'extraPayments': extraPayments,
    'lenderName':    lenderName,
    'accountNumber': accountNumber,
    'note':          note,
    'isActive':      isActive,
    'createdAt':     Timestamp.fromDate(createdAt),
  };

  factory LoanModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LoanModel(
      id:             doc.id,
      userId:         d['userId']        ?? '',
      name:           d['name']          ?? '',
      type:           LoanType.fromString(d['type'] ?? 'other'),
      principal:      (d['principal']    ?? 0).toDouble(),
      annualRate:     (d['annualRate']   ?? 0).toDouble(),
      tenureMonths:   d['tenureMonths']  ?? 12,
      startDate:      d['startDate'] != null
          ? (d['startDate'] as Timestamp).toDate()
          : DateTime.now(),
      extraPayments:  (d['extraPayments'] ?? 0).toDouble(),
      lenderName:     d['lenderName'],
      accountNumber:  d['accountNumber'],
      note:           d['note'],
      isActive:       d['isActive'] ?? true,
      createdAt:      d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  LoanModel copyWith({
    String? id, String? userId, String? name, LoanType? type,
    double? principal, double? annualRate, int? tenureMonths,
    DateTime? startDate, double? extraPayments,
    String? lenderName, String? accountNumber,
    String? note, bool? isActive,
  }) => LoanModel(
    id:            id            ?? this.id,
    userId:        userId        ?? this.userId,
    name:          name          ?? this.name,
    type:          type          ?? this.type,
    principal:     principal     ?? this.principal,
    annualRate:    annualRate    ?? this.annualRate,
    tenureMonths:  tenureMonths  ?? this.tenureMonths,
    startDate:     startDate     ?? this.startDate,
    extraPayments: extraPayments ?? this.extraPayments,
    lenderName:    lenderName    ?? this.lenderName,
    accountNumber: accountNumber ?? this.accountNumber,
    note:          note          ?? this.note,
    isActive:      isActive      ?? this.isActive,
    createdAt:     createdAt,
  );
}

// ── Supporting classes ────────────────────────────────────────────────────────
class AmortizationRow {
  final int      month;
  final DateTime date;
  final double   emi;
  final double   principal;
  final double   interest;
  final double   balance;
  final bool     isPaid;

  const AmortizationRow({
    required this.month,    required this.date,
    required this.emi,      required this.principal,
    required this.interest, required this.balance,
    required this.isPaid,
  });
}

class PrepaymentResult {
  final int      newMonths;
  final double   savedInterest;
  final int      savedMonths;
  final DateTime newEndDate;

  const PrepaymentResult({
    required this.newMonths,    required this.savedInterest,
    required this.savedMonths,  required this.newEndDate,
  });
}