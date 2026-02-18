import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaction_model.dart';
import 'account_service.dart';

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AccountService _accountService = AccountService();
  final String _collection = 'transactions';

  String? get _currentUserId => _auth.currentUser?.uid;

  Stream<List<TransactionModel>> getTransactions() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
      // Sort client-side - no index needed
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Future<List<TransactionModel>> getTransactionsList() async {
    final userId = _currentUserId;
    if (userId == null) return [];
    final snapshot = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .get();
    final list = snapshot.docs
        .map((doc) => TransactionModel.fromFirestore(doc))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Stream<List<TransactionModel>> searchTransactions(String query) {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final all = snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
      if (query.isEmpty) return all;
      final q = query.toLowerCase();
      return all.where((txn) {
        return txn.category.toLowerCase().contains(q) ||
            (txn.subcategory?.toLowerCase().contains(q) ?? false) ||
            (txn.note?.toLowerCase().contains(q) ?? false) ||
            txn.amount.toString().contains(q);
      }).toList();
    });
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    if (_currentUserId == null) throw Exception('User not logged in');
    try {
      final t = TransactionModel(
        id: '',
        userId: _currentUserId!,
        type: transaction.type,
        amount: transaction.amount,
        category: transaction.category,
        subcategory: transaction.subcategory,
        paymentMethod: transaction.paymentMethod,
        date: transaction.date,
        note: transaction.note,
        fromAccount: transaction.fromAccount,
        toAccount: transaction.toAccount,
        isRecurring: transaction.isRecurring,
        recurringFrequency: transaction.recurringFrequency,
        imageUrl: transaction.imageUrl,
        createdAt: DateTime.now(),
      );
      await _firestore.collection(_collection).add(t.toMap());

      // Update account balances
      if (t.type == 'income' && t.toAccount != null) {
        await _accountService.updateAccountBalance(t.toAccount!, t.amount);
      } else if (t.type == 'expense' && t.fromAccount != null) {
        await _accountService.updateAccountBalance(t.fromAccount!, -t.amount);
      } else if (t.type == 'transfer') {
        if (t.fromAccount != null) {
          await _accountService.updateAccountBalance(t.fromAccount!, -t.amount);
        }
        if (t.toAccount != null) {
          await _accountService.updateAccountBalance(t.toAccount!, t.amount);
        }
      }
    } catch (e) {
      throw Exception('Failed to add transaction: $e');
    }
  }

  Future<void> updateTransaction(
      String id, TransactionModel newTransaction) async {
    if (_currentUserId == null) throw Exception('User not logged in');
    try {
      final oldDoc = await _firestore.collection(_collection).doc(id).get();
      if (!oldDoc.exists) throw Exception('Transaction not found');
      final old = TransactionModel.fromFirestore(oldDoc);

      // Reverse old balance effect
      if (old.type == 'income' && old.toAccount != null) {
        await _accountService.updateAccountBalance(old.toAccount!, -old.amount);
      } else if (old.type == 'expense' && old.fromAccount != null) {
        await _accountService.updateAccountBalance(
            old.fromAccount!, old.amount);
      } else if (old.type == 'transfer') {
        if (old.fromAccount != null) {
          await _accountService.updateAccountBalance(
              old.fromAccount!, old.amount);
        }
        if (old.toAccount != null) {
          await _accountService.updateAccountBalance(
              old.toAccount!, -old.amount);
        }
      }

      // Apply new balance effect
      if (newTransaction.type == 'income' && newTransaction.toAccount != null) {
        await _accountService.updateAccountBalance(
            newTransaction.toAccount!, newTransaction.amount);
      } else if (newTransaction.type == 'expense' &&
          newTransaction.fromAccount != null) {
        await _accountService.updateAccountBalance(
            newTransaction.fromAccount!, -newTransaction.amount);
      } else if (newTransaction.type == 'transfer') {
        if (newTransaction.fromAccount != null) {
          await _accountService.updateAccountBalance(
              newTransaction.fromAccount!, -newTransaction.amount);
        }
        if (newTransaction.toAccount != null) {
          await _accountService.updateAccountBalance(
              newTransaction.toAccount!, newTransaction.amount);
        }
      }

      final updated = TransactionModel(
        id: id,
        userId: _currentUserId!,
        type: newTransaction.type,
        amount: newTransaction.amount,
        category: newTransaction.category,
        subcategory: newTransaction.subcategory,
        paymentMethod: newTransaction.paymentMethod,
        date: newTransaction.date,
        note: newTransaction.note,
        fromAccount: newTransaction.fromAccount,
        toAccount: newTransaction.toAccount,
        isRecurring: newTransaction.isRecurring,
        recurringFrequency: newTransaction.recurringFrequency,
        imageUrl: newTransaction.imageUrl,
        createdAt: newTransaction.createdAt,
      );
      await _firestore.collection(_collection).doc(id).update(updated.toMap());
    } catch (e) {
      throw Exception('Failed to update transaction: $e');
    }
  }

  Future<void> deleteTransaction(String id) async {
    if (_currentUserId == null) throw Exception('User not logged in');
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (!doc.exists) throw Exception('Not found');
      final t = TransactionModel.fromFirestore(doc);

      // Reverse balance effect
      if (t.type == 'income' && t.toAccount != null) {
        await _accountService.updateAccountBalance(t.toAccount!, -t.amount);
      } else if (t.type == 'expense' && t.fromAccount != null) {
        await _accountService.updateAccountBalance(t.fromAccount!, t.amount);
      } else if (t.type == 'transfer') {
        if (t.fromAccount != null) {
          await _accountService.updateAccountBalance(t.fromAccount!, t.amount);
        }
        if (t.toAccount != null) {
          await _accountService.updateAccountBalance(t.toAccount!, -t.amount);
        }
      }

      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete transaction: $e');
    }
  }

  Future<Map<String, double>> getSpendingByCategory(int month, int year) async {
    final userId = _currentUserId;
    if (userId == null) return {};
    final snapshot = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: 'expense')
        .get();
    final spending = <String, double>{};
    for (var doc in snapshot.docs) {
      final txn = TransactionModel.fromFirestore(doc);
      if (txn.date.month == month && txn.date.year == year) {
        spending[txn.category] = (spending[txn.category] ?? 0) + txn.amount;
      }
    }
    return spending;
  }
}
