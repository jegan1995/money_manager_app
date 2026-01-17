import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transfer_model.dart';
import 'account_service.dart';

class TransferService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'transfers';
  final AccountService _accountService = AccountService();

  // Get all transfers
  Stream<QuerySnapshot> getTransfers() {
    return _firestore
        .collection(_collection)
        .orderBy('date', descending: true)
        .snapshots();
  }

  // Add transfer (and update account balances)
  Future<void> addTransfer(TransferModel transfer) async {
    try {
      // Add transfer record
      await _firestore.collection(_collection).add(transfer.toMap());

      // Update account balances
      await _accountService.updateAccountBalance(
        transfer.fromAccount,
        -transfer.amount, // Deduct from source
      );
      await _accountService.updateAccountBalance(
        transfer.toAccount,
        transfer.amount, // Add to destination
      );
    } catch (e) {
      throw Exception('Failed to add transfer: $e');
    }
  }

  // Delete transfer (and reverse account balances)
  Future<void> deleteTransfer(TransferModel transfer) async {
    try {
      // Delete transfer record
      await _firestore.collection(_collection).doc(transfer.id).delete();

      // Reverse account balances
      await _accountService.updateAccountBalance(
        transfer.fromAccount,
        transfer.amount, // Add back to source
      );
      await _accountService.updateAccountBalance(
        transfer.toAccount,
        -transfer.amount, // Deduct from destination
      );
    } catch (e) {
      throw Exception('Failed to delete transfer: $e');
    }
  }

  // Get single transfer
  Future<DocumentSnapshot> getTransferById(String id) async {
    try {
      return await _firestore.collection(_collection).doc(id).get();
    } catch (e) {
      throw Exception('Failed to get transfer: $e');
    }
  }
}