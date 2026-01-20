import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'transactions';

  // Get all transactions as Stream
  Stream<QuerySnapshot> getTransactions() {
    return _firestore
        .collection(_collection)
        .orderBy('date', descending: true)
        .snapshots();
  }

  // Get all transactions as Future<List>
  Future<List<TransactionModel>> getTransactionsList() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting transactions list: $e');
      return [];
    }
  }

  // Add new transaction
  Future<void> addTransaction(TransactionModel transaction) async {
    try {
      await _firestore.collection(_collection).add(transaction.toMap());
    } catch (e) {
      throw Exception('Failed to add transaction: $e');
    }
  }

  // Update transaction
  Future<void> updateTransaction(String id, TransactionModel transaction) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(id)
          .update(transaction.toMap());
    } catch (e) {
      throw Exception('Failed to update transaction: $e');
    }
  }

  // Delete transaction
  Future<void> deleteTransaction(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete transaction: $e');
    }
  }

  // Get single transaction by ID
  Future<DocumentSnapshot> getTransactionById(String id) async {
    try {
      return await _firestore.collection(_collection).doc(id).get();
    } catch (e) {
      throw Exception('Failed to get transaction: $e');
    }
  }

  // Get transactions by date range
  Stream<QuerySnapshot> getTransactionsByDateRange(
      DateTime startDate, DateTime endDate) {
    return _firestore
        .collection(_collection)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date', descending: true)
        .snapshots();
  }

  // Get transactions by type
  Stream<QuerySnapshot> getTransactionsByType(String type) {
    return _firestore
        .collection(_collection)
        .where('type', isEqualTo: type)
        .orderBy('date', descending: true)
        .snapshots();
  }

  // Get transactions by category
  Stream<QuerySnapshot> getTransactionsByCategory(String category) {
    return _firestore
        .collection(_collection)
        .where('category', isEqualTo: category)
        .orderBy('date', descending: true)
        .snapshots();
  }

  // Get transactions by account
  Stream<QuerySnapshot> getTransactionsByAccount(String account) {
    return _firestore
        .collection(_collection)
        .where('fromAccount', isEqualTo: account)
        .orderBy('date', descending: true)
        .snapshots();
  }

  // Search transactions
  Stream<QuerySnapshot> searchTransactions(String query) {
    return _firestore
        .collection(_collection)
        .where('note', isGreaterThanOrEqualTo: query)
        .where('note', isLessThanOrEqualTo: '$query\uf8ff')
        .orderBy('note')
        .orderBy('date', descending: true)
        .snapshots();
  }

  // Get spending by category for statistics
  Future<Map<String, double>> getSpendingByCategory({
    required DateTime startDate,
    required DateTime endDate,
    String type = 'expense',
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('type', isEqualTo: type)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final Map<String, double> categoryTotals = {};

      for (var doc in snapshot.docs) {
        final transaction = TransactionModel.fromFirestore(doc);
        final category = transaction.category;
        categoryTotals[category] = (categoryTotals[category] ?? 0) + transaction.amount;
      }

      return categoryTotals;
    } catch (e) {
      print('Error getting spending by category: $e');
      return {};
    }
  }
}
