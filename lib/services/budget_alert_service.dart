import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/budget_alert_model.dart';
import '../models/budget_model.dart';
import 'transaction_service.dart';

class BudgetAlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TransactionService _transactionService = TransactionService();

  String? get _currentUserId => _auth.currentUser?.uid;

  // Check all budgets and create alerts if needed
  Future<void> checkBudgets() async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      final now = DateTime.now();

      // ✅ FIXED: Added userId filter, removed orderBy
      final budgetsSnapshot = await _firestore
          .collection('budgets')
          .where('userId', isEqualTo: userId)
          .where('month', isEqualTo: now.month)
          .where('year', isEqualTo: now.year)
          .get();

      if (budgetsSnapshot.docs.isEmpty) return;

      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      final transactions = await _transactionService.getTransactionsList();

      for (var budgetDoc in budgetsSnapshot.docs) {
        final budget = BudgetModel.fromFirestore(budgetDoc);

        final categorySpending = transactions
            .where((t) =>
                t.type == 'expense' &&
                t.category == budget.category &&
                t.date
                    .isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
                t.date.isBefore(endOfMonth.add(const Duration(days: 1))))
            .fold(0.0, (sum, t) => sum + t.amount);

        final percentage = (categorySpending / budget.amount) * 100;

        if (percentage >= 75) {
          await _createOrUpdateAlert(
            userId: userId,
            budgetId: budget.id,
            category: budget.category,
            budgetAmount: budget.amount,
            spentAmount: categorySpending,
            percentage: percentage,
          );
        }
      }
    } catch (e) {
      print('Error checking budgets: $e');
    }
  }

  Future<void> _createOrUpdateAlert({
    required String userId,
    required String budgetId,
    required String category,
    required double budgetAmount,
    required double spentAmount,
    required double percentage,
  }) async {
    try {
      final alertType = percentage >= 100
          ? 'exceeded'
          : percentage >= 90
              ? 'critical'
              : 'warning';

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      // ✅ FIXED: Added userId filter, removed orderBy
      final existingAlerts = await _firestore
          .collection('budget_alerts')
          .where('userId', isEqualTo: userId)
          .where('budgetId', isEqualTo: budgetId)
          .get();

      // Filter client-side for current month
      final thisMonthAlerts = existingAlerts.docs.where((doc) {
        final date = (doc.data()['date'] as Timestamp).toDate();
        return date.isAfter(startOfMonth);
      }).toList();

      if (thisMonthAlerts.isNotEmpty) {
        await thisMonthAlerts.first.reference.update({
          'spentAmount': spentAmount,
          'percentage': percentage,
          'alertType': alertType,
          'date': Timestamp.fromDate(DateTime.now()),
          'isRead': false,
        });
      } else {
        final alert = BudgetAlertModel(
          id: '',
          budgetId: budgetId,
          category: category,
          budgetAmount: budgetAmount,
          spentAmount: spentAmount,
          percentage: percentage,
          alertType: alertType,
          date: DateTime.now(),
        );

        // Add userId to the map
        final alertMap = alert.toMap();
        alertMap['userId'] = userId;
        await _firestore.collection('budget_alerts').add(alertMap);
      }
    } catch (e) {
      print('Error creating/updating alert: $e');
    }
  }

  // ✅ FIXED: Removed orderBy, sort client-side
  Stream<List<BudgetAlertModel>> getUnreadAlerts() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('budget_alerts')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => BudgetAlertModel.fromFirestore(doc))
          .toList();
      // ✅ Sort client-side
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  // ✅ FIXED: Removed orderBy, sort client-side
  Stream<List<BudgetAlertModel>> getAllAlerts() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('budget_alerts')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => BudgetAlertModel.fromFirestore(doc))
          .toList();
      // ✅ Sort client-side, limit to 50
      list.sort((a, b) => b.date.compareTo(a.date));
      return list.take(50).toList();
    });
  }

  Future<void> markAsRead(String alertId) async {
    try {
      await _firestore
          .collection('budget_alerts')
          .doc(alertId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking alert as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      // ✅ FIXED: Added userId filter
      final unreadAlerts = await _firestore
          .collection('budget_alerts')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in unreadAlerts.docs) {
        await doc.reference.update({'isRead': true});
      }
    } catch (e) {
      print('Error marking all alerts as read: $e');
    }
  }

  Future<void> cleanupOldAlerts() async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));

      // ✅ FIXED: Added userId filter, removed orderBy
      final allAlerts = await _firestore
          .collection('budget_alerts')
          .where('userId', isEqualTo: userId)
          .get();

      // Filter client-side for old alerts
      final oldAlerts = allAlerts.docs.where((doc) {
        final date = (doc.data()['date'] as Timestamp).toDate();
        return date.isBefore(threeMonthsAgo);
      }).toList();

      for (var doc in oldAlerts) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error cleaning up old alerts: $e');
    }
  }

  // ✅ FIXED: Added userId filter
  Stream<int> getUnreadCount() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value(0);

    return _firestore
        .collection('budget_alerts')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
