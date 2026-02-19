import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/account_model.dart';

class AccountService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _collection = 'accounts';

  String? get _currentUserId => _auth.currentUser?.uid;

  Stream<List<AccountModel>> getAccounts() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AccountModel.fromFirestore(doc))
          .toList();
    });
  }

  Stream<List<AccountModel>> getAccountsList() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AccountModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ))
            .toList());
  }

  Future<void> addAccount(AccountModel account) async {
    if (_currentUserId == null) throw Exception('User not logged in');
    await _firestore.collection(_collection).add(account.toMap());
  }

  Future<void> updateAccount(String id, AccountModel account) async {
    if (_currentUserId == null) throw Exception('User not logged in');
    await _firestore.collection(_collection).doc(id).update(account.toMap());
  }

  Future<void> deleteAccount(String id) async {
    if (_currentUserId == null) throw Exception('User not logged in');
    await _firestore.collection(_collection).doc(id).delete();
  }

  Stream<QuerySnapshot> getAccountsByType(String type) {
    final userId = _currentUserId;
    if (userId == null) return const Stream.empty();
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: type)
        .snapshots();
  }

  Future<void> updateAccountBalance(String accountId, double amount) async {
    if (_currentUserId == null) throw Exception('User not logged in');
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
