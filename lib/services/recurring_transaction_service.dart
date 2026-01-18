import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recurring_transaction_model.dart';
import '../models/transaction_model.dart';
import 'transaction_service.dart';

class RecurringTransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'recurring_transactions';
  final TransactionService _transactionService = TransactionService();

  // Get all recurring transactions
  Stream<QuerySnapshot> getRecurringTransactions() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Add recurring transaction
  Future<void> addRecurringTransaction(RecurringTransactionModel recurring) async {
    try {
      await _firestore.collection(_collection).add(recurring.toMap());
    } catch (e) {
      throw Exception('Failed to add recurring transaction: $e');
    }
  }

  // Update recurring transaction
  Future<void> updateRecurringTransaction(
      String id, RecurringTransactionModel recurring) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(id)
          .update(recurring.toMap());
    } catch (e) {
      throw Exception('Failed to update recurring transaction: $e');
    }
  }

  // Delete recurring transaction
  Future<void> deleteRecurringTransaction(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete recurring transaction: $e');
    }
  }

  // Generate transactions from recurring (call this daily)
  Future<void> generateRecurringTransactions() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      final now = DateTime.now();

      for (var doc in snapshot.docs) {
        final recurring = RecurringTransactionModel.fromMap(doc.data(), doc.id);

        if (_shouldGenerateTransaction(recurring, now)) {
          final transaction = TransactionModel(
            type: recurring.type,
            amount: recurring.amount,
            category: recurring.category,
            subcategory: recurring.subcategory,
            paymentMethod: recurring.paymentMethod,
            date: now,
            note: recurring.note,
          );

          await _transactionService.addTransaction(transaction);
        }
      }
    } catch (e) {
      throw Exception('Failed to generate recurring transactions: $e');
    }
  }

  bool _shouldGenerateTransaction(RecurringTransactionModel recurring, DateTime now) {
    // Check if within date range
    if (now.isBefore(recurring.startDate)) return false;
    if (recurring.endDate != null && now.isAfter(recurring.endDate!)) return false;

    // Check frequency
    switch (recurring.frequency) {
      case 'daily':
        return true;
      case 'weekly':
        return now.weekday == recurring.startDate.weekday;
      case 'monthly':
        return now.day == recurring.startDate.day;
      case 'yearly':
        return now.month == recurring.startDate.month &&
            now.day == recurring.startDate.day;
      default:
        return false;
    }
  }
}
