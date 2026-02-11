import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/budget_alert_model.dart';
import '../models/budget_model.dart';
import 'transaction_service.dart';

class BudgetAlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TransactionService _transactionService = TransactionService();

  // Check all budgets and create alerts if needed
  Future<void> checkBudgets() async {
    try {
      final now = DateTime.now();
      
      // Get budgets for current month/year
      final budgetsSnapshot = await _firestore
          .collection('budgets')
          .where('month', isEqualTo: now.month)
          .where('year', isEqualTo: now.year)
          .get();
      
      if (budgetsSnapshot.docs.isEmpty) {
        print('No budgets found for current month');
        return;
      }
      
      for (var budgetDoc in budgetsSnapshot.docs) {
        final budget = BudgetModel.fromFirestore(budgetDoc);
        
        // Calculate spending for this budget's category in current month
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0);
        
        final transactions = await _transactionService.getTransactionsList();
        
        // Filter transactions for this budget's category in current month
        final categorySpending = transactions
            .where((t) =>
                t.type == 'expense' &&
                t.category == budget.category &&
                t.date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
                t.date.isBefore(endOfMonth.add(const Duration(days: 1))))
            .fold(0.0, (sum, t) => sum + t.amount);
        
        final percentage = (categorySpending / budget.amount) * 100;
        
        print('Budget check: ${budget.category} - ₹$categorySpending / ₹${budget.amount} (${percentage.toStringAsFixed(1)}%)');
        
        // Create alert if threshold is crossed
        if (percentage >= 75) {
          await _createOrUpdateAlert(
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

  // Create or update alert for a budget
  Future<void> _createOrUpdateAlert({
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

      print('Creating alert: $category at ${percentage.toStringAsFixed(1)}% ($alertType)');

      // Check if alert already exists for this budget this month
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      
      final existingAlerts = await _firestore
          .collection('budget_alerts')
          .where('budgetId', isEqualTo: budgetId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .get();

      if (existingAlerts.docs.isNotEmpty) {
        // Update existing alert
        final alertDoc = existingAlerts.docs.first;
        await alertDoc.reference.update({
          'spentAmount': spentAmount,
          'percentage': percentage,
          'alertType': alertType,
          'date': Timestamp.fromDate(DateTime.now()),
          'isRead': false, // Mark as unread when updated
        });
        print('Alert updated for $category');
      } else {
        // Create new alert
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
        
        await _firestore.collection('budget_alerts').add(alert.toMap());
        print('New alert created for $category');
      }
    } catch (e) {
      print('Error creating/updating alert: $e');
    }
  }

  // Get unread alerts
  Stream<List<BudgetAlertModel>> getUnreadAlerts() {
    return _firestore
        .collection('budget_alerts')
        .where('isRead', isEqualTo: false)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BudgetAlertModel.fromFirestore(doc))
            .toList());
  }

  // Get all alerts
  Stream<List<BudgetAlertModel>> getAllAlerts() {
    return _firestore
        .collection('budget_alerts')
        .orderBy('date', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BudgetAlertModel.fromFirestore(doc))
            .toList());
  }

  // Mark alert as read
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

  // Mark all alerts as read
  Future<void> markAllAsRead() async {
    try {
      final unreadAlerts = await _firestore
          .collection('budget_alerts')
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in unreadAlerts.docs) {
        await doc.reference.update({'isRead': true});
      }
    } catch (e) {
      print('Error marking all alerts as read: $e');
    }
  }

  // Delete old alerts (older than 3 months)
  Future<void> cleanupOldAlerts() async {
    try {
      final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
      
      final oldAlerts = await _firestore
          .collection('budget_alerts')
          .where('date', isLessThan: Timestamp.fromDate(threeMonthsAgo))
          .get();

      for (var doc in oldAlerts.docs) {
        await doc.reference.delete();
      }
      
      if (oldAlerts.docs.isNotEmpty) {
        print('Cleaned up ${oldAlerts.docs.length} old alerts');
      }
    } catch (e) {
      print('Error cleaning up old alerts: $e');
    }
  }

  // Get alert count
  Stream<int> getUnreadCount() {
    return _firestore
        .collection('budget_alerts')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}