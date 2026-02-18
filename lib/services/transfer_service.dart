import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transfer_model.dart';
import 'account_service.dart';

class TransferService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _collection = 'transfers';
  final AccountService _accountService = AccountService();

  String? get _currentUserId => _auth.currentUser?.uid;

  // ✅ FIXED: Added userId filter, removed orderBy
  Stream<QuerySnapshot> getTransfers() {
    final userId = _currentUserId;
    if (userId == null) return const Stream.empty();
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  // Add transfer (and update account balances)
  Future<void> addTransfer(TransferModel transfer) async {
    if (_currentUserId == null) throw Exception('User not logged in');
    try {
      await _firestore.collection(_collection).add(transfer.toMap());
      await _accountService.updateAccountBalance(
        transfer.fromAccount,
        -transfer.amount,
      );
      await _accountService.updateAccountBalance(
        transfer.toAccount,
        transfer.amount,
      );
    } catch (e) {
      throw Exception('Failed to add transfer: $e');
    }
  }

  // Delete transfer (and reverse account balances)
  Future<void> deleteTransfer(TransferModel transfer) async {
    if (_currentUserId == null) throw Exception('User not logged in');
    try {
      await _firestore.collection(_collection).doc(transfer.id).delete();
      await _accountService.updateAccountBalance(
        transfer.fromAccount,
        transfer.amount,
      );
      await _accountService.updateAccountBalance(
        transfer.toAccount,
        -transfer.amount,
      );
    } catch (e) {
      throw Exception('Failed to delete transfer: $e');
    }
  }

  Future<DocumentSnapshot> getTransferById(String id) async {
    try {
      return await _firestore.collection(_collection).doc(id).get();
    } catch (e) {
      throw Exception('Failed to get transfer: $e');
    }
  }
}
