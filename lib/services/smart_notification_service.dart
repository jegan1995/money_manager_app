// lib/services/smart_notification_service.dart
// Feature 20 — Smart Notification Service
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/goal_model.dart';
import '../models/budget_model.dart';
import '../models/recurring_transaction_model.dart';
import 'transaction_service.dart';

class AppNotification {
  final String  id;
  final String  type;
  final String  title;
  final String  body;
  final String  emoji;
  final int     priority;
  final bool    isRead;
  final DateTime createdAt;
  final Map<String, dynamic> meta;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.emoji,
    required this.priority,
    required this.isRead,
    required this.createdAt,
    this.meta = const {},
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id:        doc.id,
      type:      d['type']    ?? 'tip',
      title:     d['title']   ?? '',
      body:      d['body']    ?? '',
      emoji:     d['emoji']   ?? '🔔',
      priority:  d['priority'] ?? 0,
      isRead:    d['isRead']  ?? false,
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      meta: Map<String, dynamic>.from(d['meta'] ?? {}),
    );
  }
}

class SmartNotificationService {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _txn  = TransactionService();

  String? get _uid => _auth.currentUser?.uid;
  static const _col = 'smart_notifications';

  Stream<List<AppNotification>> getNotifications() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _db.collection(_col)
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => AppNotification.fromFirestore(d))
          .toList();
      list.sort((a, b) {
        if (a.isRead != b.isRead) return a.isRead ? 1 : -1;
        if (a.priority != b.priority) return b.priority - a.priority;
        return b.createdAt.compareTo(a.createdAt);
      });
      return list;
    });
  }

  Stream<int> getUnreadCount() {
    final uid = _uid;
    if (uid == null) return Stream.value(0);
    return _db.collection(_col)
        .where('userId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Future<void> markRead(String id) =>
      _db.collection(_col).doc(id).update({'isRead': true});

  Future<void> markAllRead() async {
    final uid = _uid;
    if (uid == null) return;
    final snap = await _db.collection(_col)
        .where('userId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) batch.update(doc.reference, {'isRead': true});
    await batch.commit();
  }

  Future<void> delete(String id) => _db.collection(_col).doc(id).delete();

  Future<void> clearAll() async {
    final uid = _uid;
    if (uid == null) return;
    final snap = await _db.collection(_col)
        .where('userId', isEqualTo: uid).get();
    final batch = _db.batch();
    for (final doc in snap.docs) batch.delete(doc.reference);
    await batch.commit();
  }

  // ── MAIN: Run all checks & generate notifications ─────────────────────────
  Future<int> generateNotifications() async {
    final uid = _uid;
    if (uid == null) return 0;
    int n = 0;
    n += await _checkBudgets(uid);
    n += await _checkGoals(uid);
    n += await _checkRecurring(uid);
    n += await _checkDailySpending(uid);
    return n;
  }

  // ── 1. Budget overspending ────────────────────────────────────────────────
  Future<int> _checkBudgets(String uid) async {
    int count = 0;
    try {
      final now   = DateTime.now();
      final snap  = await _db.collection('budgets')
          .where('userId', isEqualTo: uid)
          .where('month',  isEqualTo: now.month)
          .where('year',   isEqualTo: now.year)
          .get();
      if (snap.docs.isEmpty) return 0;

      final txns  = await _txn.getTransactionsList();
      final start = DateTime(now.year, now.month, 1);
      final end   = DateTime(now.year, now.month + 1, 0);

      for (final doc in snap.docs) {
        final b     = BudgetModel.fromFirestore(doc);
        final spent = txns
            .where((t) =>
                t.type == 'expense' &&
                t.category == b.category &&
                !t.date.isBefore(start) &&
                !t.date.isAfter(end))
            .fold(0.0, (s, t) => s + t.amount);
        final pct = b.amount > 0 ? (spent / b.amount) * 100 : 0.0;
        if (pct < 75) continue;

        final String emoji, title, body;
        final int priority;
        if (pct >= 100) {
          emoji = '🚨'; priority = 3;
          title = '${b.category} Budget Exceeded!';
          body  = 'Spent ₹${spent.toStringAsFixed(0)} of '
                  '₹${b.amount.toStringAsFixed(0)} (${pct.toStringAsFixed(0)}%)';
        } else if (pct >= 90) {
          emoji = '⚠️'; priority = 2;
          title = '${b.category} Almost Exhausted';
          body  = '${pct.toStringAsFixed(0)}% used — '
                  '₹${(b.amount - spent).toStringAsFixed(0)} remaining';
        } else {
          emoji = '📊'; priority = 1;
          title = '${b.category} at ${pct.toStringAsFixed(0)}%';
          body  = 'Spent ₹${spent.toStringAsFixed(0)} of '
                  '₹${b.amount.toStringAsFixed(0)} this month';
        }

        await _upsert(uid,
          key:      'budget_${doc.id}_${now.month}_${now.year}',
          type:     'budget', title: title, body: body,
          emoji:    emoji, priority: priority,
          meta:     {'category': b.category, 'pct': pct, 'spent': spent},
        );
        count++;
      }
    } catch (_) {}
    return count;
  }

  // ── 2. Goal deadlines ─────────────────────────────────────────────────────
  Future<int> _checkGoals(String uid) async {
    int count = 0;
    try {
      final snap = await _db.collection('goals')
          .where('userId',      isEqualTo: uid)
          .where('isCompleted', isEqualTo: false)
          .get();

      for (final doc in snap.docs) {
        final g        = GoalModel.fromFirestore(doc);
        final daysLeft = g.targetDate.difference(DateTime.now()).inDays;
        final pct      = g.targetAmount > 0
            ? (g.currentAmount / g.targetAmount) * 100 : 0.0;
        final need     = g.targetAmount - g.currentAmount;

        if (daysLeft < 0) {
          await _upsert(uid,
            key: 'goal_overdue_${doc.id}', type: 'goal',
            title: '⏰ Goal Overdue: ${g.name}',
            body:  '₹${need.toStringAsFixed(0)} still needed. Extend deadline or add savings.',
            emoji: '⏰', priority: 2,
            meta:  {'goalId': doc.id, 'daysLeft': daysLeft, 'pct': pct},
          );
          count++;
        } else if (daysLeft <= 7) {
          await _upsert(uid,
            key: 'goal_7d_${doc.id}', type: 'goal',
            title: '🎯 ${g.name} due in $daysLeft days!',
            body:  '₹${need.toStringAsFixed(0)} still needed. Add savings now!',
            emoji: '🎯', priority: 2,
            meta:  {'goalId': doc.id, 'daysLeft': daysLeft, 'pct': pct},
          );
          count++;
        } else if (daysLeft <= 30) {
          await _upsert(uid,
            key: 'goal_30d_${doc.id}', type: 'goal',
            title: '🎯 ${g.name} — $daysLeft days left',
            body:  '${pct.toStringAsFixed(0)}% saved. ₹${need.toStringAsFixed(0)} to go!',
            emoji: '🎯', priority: 1,
            meta:  {'goalId': doc.id, 'daysLeft': daysLeft, 'pct': pct},
          );
          count++;
        }
      }
    } catch (_) {}
    return count;
  }

  // ── 3. Recurring due reminders ────────────────────────────────────────────
  Future<int> _checkRecurring(String uid) async {
    int count = 0;
    try {
      final snap = await _db.collection('recurring_transactions')
          .where('userId',   isEqualTo: uid)
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in snap.docs) {
        final r        = RecurringTransactionModel.fromFirestore(doc);
        final daysLeft = r.nextDate.difference(DateTime.now()).inDays;
        if (daysLeft > 3) continue;

        final when = daysLeft == 0 ? 'today'
            : daysLeft == 1 ? 'tomorrow'
            : 'in $daysLeft days';
        final emoji = r.type == 'expense' ? '💸' : '💰';

        await _upsert(uid,
          key:      'recurring_${doc.id}_${r.nextDate.millisecondsSinceEpoch}',
          type:     'recurring',
          title:    '${r.type == 'expense' ? 'Payment' : 'Income'} due $when',
          body:     '${r.category}: ₹${r.amount.toStringAsFixed(0)} (${r.frequency})',
          emoji:    emoji, priority: daysLeft <= 1 ? 2 : 1,
          meta:     {'recurringId': doc.id, 'daysLeft': daysLeft, 'amount': r.amount},
        );
        count++;
      }
    } catch (_) {}
    return count;
  }

  // ── 4. Daily spending summary ─────────────────────────────────────────────
  Future<int> _checkDailySpending(String uid) async {
    try {
      final now        = DateTime.now();
      final today      = DateTime(now.year, now.month, now.day);
      final txns       = await _txn.getTransactionsList();
      final todaySpent = txns
          .where((t) => t.type == 'expense' && !t.date.isBefore(today))
          .fold(0.0, (s, t) => s + t.amount);
      if (todaySpent <= 0) return 0;

      final yesterday      = today.subtract(const Duration(days: 1));
      final yesterdaySpent = txns
          .where((t) =>
              t.type == 'expense' &&
              !t.date.isBefore(yesterday) &&
              t.date.isBefore(today))
          .fold(0.0, (s, t) => s + t.amount);
      final diff = yesterdaySpent > 0
          ? ((todaySpent - yesterdaySpent) / yesterdaySpent) * 100 : 0.0;

      final String emoji, title, body;
      final int priority;
      if (diff > 50 && todaySpent > 500) {
        emoji = '📈'; priority = 2;
        title = 'High spending today!';
        body  = '₹${todaySpent.toStringAsFixed(0)} spent — ${diff.toStringAsFixed(0)}% more than yesterday';
      } else if (todaySpent > 2000) {
        emoji = '💡'; priority = 1;
        title = 'Today\'s spending: ₹${todaySpent.toStringAsFixed(0)}';
        body  = yesterdaySpent > 0
            ? 'Yesterday: ₹${yesterdaySpent.toStringAsFixed(0)}'
            : 'Keep tracking your daily expenses';
      } else {
        emoji = '✅'; priority = 0;
        title = 'Low spending day 🎉';
        body  = 'Only ₹${todaySpent.toStringAsFixed(0)} spent today. Great job!';
      }

      await _upsert(uid,
        key:      'daily_${today.year}_${today.month}_${today.day}',
        type:     'spending', title: title, body: body,
        emoji:    emoji, priority: priority,
        meta:     {'todaySpent': todaySpent, 'yesterdaySpent': yesterdaySpent},
      );
      return 1;
    } catch (_) {}
    return 0;
  }

  // ── Upsert helper ─────────────────────────────────────────────────────────
  Future<void> _upsert(
    String uid, {
    required String key,
    required String type,
    required String title,
    required String body,
    required String emoji,
    required int priority,
    Map<String, dynamic> meta = const {},
  }) async {
    try {
      final existing = await _db.collection(_col)
          .where('userId', isEqualTo: uid)
          .where('key',    isEqualTo: key)
          .limit(1).get();

      final data = <String, dynamic>{
        'userId':    uid, 'key': key, 'type': type,
        'title':     title, 'body': body, 'emoji': emoji,
        'priority':  priority, 'isRead': false,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'meta':      meta,
      };

      if (existing.docs.isNotEmpty) {
        final wasRead = existing.docs.first.data()['isRead'] ?? false;
        data['isRead'] = wasRead;
        await existing.docs.first.reference.update(data);
      } else {
        await _db.collection(_col).add(data);
      }
    } catch (_) {}
  }
}