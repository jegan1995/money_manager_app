import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction.dart' as app_transaction;

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collectionName = 'transactions';

  // Add a new transaction
  Future<void> addTransaction(app_transaction.Transaction transaction) async {
    try {
      await _db.collection(_collectionName).add(transaction.toMap());
    } catch (e) {
      throw Exception('Failed to add transaction: $e');
    }
  }

  // Get all transactions as a stream
  Stream<List<app_transaction.Transaction>> getTransactions() {
    return _db
        .collection(_collectionName)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => app_transaction.Transaction.fromFirestore(doc))
            .toList());
  }

  // Delete a transaction
  Future<void> deleteTransaction(String id) async {
    try {
      await _db.collection(_collectionName).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete transaction: $e');
    }
  }

  // Get total balance (income - expense)
  Future<double> getTotalBalance() async {
    try {
      QuerySnapshot snapshot = await _db.collection(_collectionName).get();
      double balance = 0;
      
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        double amount = (data['amount'] ?? 0).toDouble();
        String type = data['type'] ?? 'expense';
        
        if (type == 'income') {
          balance += amount;
        } else {
          balance -= amount;
        }
      }
      
      return balance;
    } catch (e) {
      throw Exception('Failed to calculate balance: $e');
    }
  }
}
