import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';
import 'account_service.dart';

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'transactions';
  final AccountService _accountService = AccountService();

  // Get all transactions (ordered by date descending)
  Stream<QuerySnapshot> getTransactions() {
    return _firestore
        .collection(_collection)
        .orderBy('date', descending: true)
        .snapshots();
  }

  // Add new transaction (with account balance update)
  Future<void> addTransaction(TransactionModel transaction) async {
    try {
      await _firestore.collection(_collection).add(transaction.toMap());

      // Update account balance if transfer
      if (transaction.type == 'transfer' &&
          transaction.fromAccount != null &&
          transaction.toAccount != null) {
        await _accountService.updateAccountBalance(
          transaction.fromAccount!,
          -transaction.amount,
        );
        await _accountService.updateAccountBalance(
          transaction.toAccount!,
          transaction.amount,
        );
      }
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
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date', descending: true)
        .snapshots();
  }

  // Get transactions by type (income/expense/transfer)
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

  // Search transactions
  Future<List<TransactionModel>> searchTransactions(String query) async {
    try {
      final snapshot = await _firestore.collection(_collection).get();
      
      final allTransactions = snapshot.docs
          .map((doc) => TransactionModel.fromMap(
                doc.data(),
                doc.id,
              ))
          .toList();

      // Filter by query (category, note, amount)
      return allTransactions.where((txn) {
        final queryLower = query.toLowerCase();
        return txn.category.toLowerCase().contains(queryLower) ||
            (txn.subcategory?.toLowerCase().contains(queryLower) ?? false) ||
            (txn.note?.toLowerCase().contains(queryLower) ?? false) ||
            txn.amount.toString().contains(query);
      }).toList();
    } catch (e) {
      throw Exception('Failed to search transactions: $e');
    }
  }

  // Get spending by category for a month
  Future<Map<String, double>> getSpendingByCategory(int month, int year) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

      final snapshot = await _firestore
          .collection(_collection)
          .where('type', isEqualTo: 'expense')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final Map<String, double> spending = {};

      for (var doc in snapshot.docs) {
        final txn = TransactionModel.fromMap(doc.data(), doc.id);
        spending[txn.category] = (spending[txn.category] ?? 0) + txn.amount;
      }

      return spending;
    } catch (e) {
      throw Exception('Failed to get spending by category: $e');
    }
  }
}
