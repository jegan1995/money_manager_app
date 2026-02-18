import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recurring_transaction_model.dart';
import '../models/transaction_model.dart';
import 'transaction_service.dart';

class RecurringTransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TransactionService _transactionService = TransactionService();
  final String _collection = 'recurring_transactions';

  String? get _currentUserId => _auth.currentUser?.uid;

  Stream<List<RecurringTransactionModel>> getRecurringTransactions() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => RecurringTransactionModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) => a.nextDate.compareTo(b.nextDate));
      return list;
    });
  }

  Future<void> addRecurringTransaction(
      RecurringTransactionModel recurring) async {
    if (_currentUserId == null) throw Exception('User not logged in');

    final r = RecurringTransactionModel(
      id: '',
      userId: _currentUserId!,
      type: recurring.type,
      amount: recurring.amount,
      category: recurring.category,
      subcategory: recurring.subcategory,
      fromAccount: recurring.fromAccount,
      toAccount: recurring.toAccount,
      frequency: recurring.frequency,
      nextDate: recurring.nextDate,
      lastExecuted: null,
      isActive: true,
      note: recurring.note,
      createdAt: DateTime.now(),
    );

    await _firestore.collection(_collection).add(r.toMap());
  }

  Future<void> updateRecurringTransaction(
      String id, RecurringTransactionModel recurring) async {
    if (_currentUserId == null) throw Exception('User not logged in');

    final r = RecurringTransactionModel(
      id: id,
      userId: _currentUserId!,
      type: recurring.type,
      amount: recurring.amount,
      category: recurring.category,
      subcategory: recurring.subcategory,
      fromAccount: recurring.fromAccount,
      toAccount: recurring.toAccount,
      frequency: recurring.frequency,
      nextDate: recurring.nextDate,
      lastExecuted: recurring.lastExecuted,
      isActive: recurring.isActive,
      note: recurring.note,
      createdAt: recurring.createdAt,
    );

    await _firestore.collection(_collection).doc(id).update(r.toMap());
  }

  Future<void> deleteRecurringTransaction(String id) async {
    if (_currentUserId == null) throw Exception('User not logged in');
    await _firestore.collection(_collection).doc(id).delete();
  }

  Future<void> toggleRecurringTransaction(String id, bool isActive) async {
    if (_currentUserId == null) throw Exception('User not logged in');
    await _firestore
        .collection(_collection)
        .doc(id)
        .update({'isActive': isActive});
  }

  // Execute recurring transaction now
  Future<void> executeRecurring(String id) async {
    if (_currentUserId == null) throw Exception('User not logged in');

    final doc = await _firestore.collection(_collection).doc(id).get();
    if (!doc.exists) throw Exception('Not found');

    final recurring = RecurringTransactionModel.fromFirestore(doc);

    // Create transaction
    final transaction = TransactionModel(
      id: '',
      userId: _currentUserId!,
      type: recurring.type,
      amount: recurring.amount,
      category: recurring.category,
      subcategory: recurring.subcategory,
      paymentMethod: 'recurring',
      date: DateTime.now(),
      note: recurring.note,
      fromAccount: recurring.fromAccount,
      toAccount: recurring.toAccount,
      isRecurring: false,
      recurringFrequency: null,
      imageUrl: null,
      createdAt: DateTime.now(),
    );

    await _transactionService.addTransaction(transaction);

    // Update next date
    final nextDate = _calculateNextDate(DateTime.now(), recurring.frequency);
    await _firestore.collection(_collection).doc(id).update({
      'lastExecuted': Timestamp.fromDate(DateTime.now()),
      'nextDate': Timestamp.fromDate(nextDate),
    });
  }

  // Check and execute due recurring transactions
  Future<void> checkAndExecuteRecurring() async {
    final userId = _currentUserId;
    if (userId == null) return;

    final now = DateTime.now();
    final snapshot = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();

    for (var doc in snapshot.docs) {
      final recurring = RecurringTransactionModel.fromFirestore(doc);

      if (recurring.nextDate.isBefore(now) ||
          recurring.nextDate.day == now.day) {
        await executeRecurring(recurring.id);
      }
    }
  }

  DateTime _calculateNextDate(DateTime current, String frequency) {
    switch (frequency) {
      case 'daily':
        return current.add(const Duration(days: 1));
      case 'weekly':
        return current.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(current.year, current.month + 1, current.day);
      case 'yearly':
        return DateTime(current.year + 1, current.month, current.day);
      default:
        return current.add(const Duration(days: 30));
    }
  }
}
