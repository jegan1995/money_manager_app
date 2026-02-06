import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/account_model.dart';

class AccountService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'accounts';

  // Get all accounts as Stream<QuerySnapshot>
  Stream<QuerySnapshot> getAccounts() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // Get accounts as Stream<List<AccountModel>>
  Stream<List<AccountModel>> getAccountsList() {
    return _firestore
        .collection(_collection)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AccountModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ))
            .toList());
  }

  // Add account
  Future<void> addAccount(AccountModel account) async {
    try {
      await _firestore.collection(_collection).add(account.toMap());
    } catch (e) {
      throw Exception('Failed to add account: $e');
    }
  }

  // Update account
  Future<void> updateAccount(String id, AccountModel account) async {
    try {
      await _firestore.collection(_collection).doc(id).update(account.toMap());
    } catch (e) {
      throw Exception('Failed to update account: $e');
    }
  }

  // Delete account
  Future<void> deleteAccount(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }

  // Get accounts by type
  Stream<QuerySnapshot> getAccountsByType(String type) {
    return _firestore
        .collection(_collection)
        .where('type', isEqualTo: type)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // Update account balance (for transactions)
  Future<void> updateAccountBalance(String accountId, double amount) async {
    try {
      final doc = await _firestore.collection(_collection).doc(accountId).get();
      if (doc.exists) {
        final currentBalance = (doc.data()!['balance'] ?? 0).toDouble();
        await _firestore.collection(_collection).doc(accountId).update({
          'balance': currentBalance + amount,
        });
      }
    } catch (e) {
      throw Exception('Failed to update balance: $e');
    }
  }
}