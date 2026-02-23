import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bill_reminder_model.dart';

class BillReminderService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  static const _collection = 'bill_reminders';

  String? get _uid => _auth.currentUser?.uid;

  // ── Calculate next due date ──────────────────────────────────────────────────
  static DateTime calculateNextDueDate(int dueDayOfMonth, String repeatType,
      {DateTime? lastPaidDate}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (repeatType == 'one_time') {
      // Use current month's due day
      return DateTime(now.year, now.month, dueDayOfMonth);
    }

    if (repeatType == 'yearly') {
      DateTime candidate = DateTime(now.year, now.month, dueDayOfMonth);
      if (candidate.isBefore(today)) {
        candidate = DateTime(now.year + 1, now.month, dueDayOfMonth);
      }
      return candidate;
    }

    // monthly (default)
    DateTime candidate = DateTime(now.year, now.month, dueDayOfMonth);
    if (candidate.isBefore(today)) {
      // Move to next month
      int nextMonth = now.month + 1;
      int nextYear = now.year;
      if (nextMonth > 12) {
        nextMonth = 1;
        nextYear++;
      }
      // Handle months with fewer days (e.g., Feb 30 → Feb 28)
      final lastDayOfNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
      final day =
          dueDayOfMonth > lastDayOfNextMonth ? lastDayOfNextMonth : dueDayOfMonth;
      candidate = DateTime(nextYear, nextMonth, day);
    }
    return candidate;
  }

  // ── Streams ─────────────────────────────────────────────────────────────────
  Stream<List<BillReminderModel>> getBillReminders() {
    if (_uid == null) return Stream.value([]);
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: _uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(BillReminderModel.fromFirestore).toList();
      // Sort: overdue first → due soon → upcoming
      list.sort((a, b) => (a.daysUntilDue).compareTo(b.daysUntilDue));
      return list;
    });
  }

  Stream<int> getOverdueCount() {
    return getBillReminders().map((list) =>
        list.where((b) => b.isActive && b.daysUntilDue <= 0).length);
  }

  // ── CRUD ────────────────────────────────────────────────────────────────────
  Future<void> addBillReminder(BillReminderModel bill) async {
    if (_uid == null) throw Exception('Not logged in');
    final nextDue = calculateNextDueDate(bill.dueDayOfMonth, bill.repeatType);
    final data = bill.copyWith(nextDueDate: nextDue).toFirestore();
    data['userId'] = _uid!;
    await _firestore.collection(_collection).add(data);
  }

  Future<void> updateBillReminder(String id, BillReminderModel bill) async {
    final nextDue = calculateNextDueDate(bill.dueDayOfMonth, bill.repeatType);
    await _firestore
        .collection(_collection)
        .doc(id)
        .update(bill.copyWith(nextDueDate: nextDue).toFirestore());
  }

  Future<void> deleteBillReminder(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  // Mark as paid → advance next due date
  Future<void> markAsPaid(BillReminderModel bill) async {
    final now = DateTime.now();
    DateTime? nextDue;

    if (bill.repeatType == 'monthly') {
      int nextMonth = now.month + 1;
      int nextYear = now.year;
      if (nextMonth > 12) {
        nextMonth = 1;
        nextYear++;
      }
      final lastDay = DateTime(nextYear, nextMonth + 1, 0).day;
      final day = bill.dueDayOfMonth > lastDay ? lastDay : bill.dueDayOfMonth;
      nextDue = DateTime(nextYear, nextMonth, day);
    } else if (bill.repeatType == 'yearly') {
      nextDue = DateTime(now.year + 1, now.month, bill.dueDayOfMonth);
    } else {
      // one_time — deactivate after paying
      await _firestore.collection(_collection).doc(bill.id).update({
        'isActive': false,
        'lastPaidDate': Timestamp.fromDate(now),
      });
      return;
    }

    await _firestore.collection(_collection).doc(bill.id).update({
      'lastPaidDate': Timestamp.fromDate(now),
      'nextDueDate': Timestamp.fromDate(nextDue),
    });
  }

  Future<void> toggleActive(String id, bool isActive) async {
    await _firestore.collection(_collection).doc(id).update({'isActive': isActive});
  }
}