import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recurring_transfer_model.dart';
import '../models/transaction_model.dart';
import 'transaction_service.dart';

class RecurringTransferService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TransactionService _transactionService = TransactionService();

  String? get _currentUserId => _auth.currentUser?.uid;

  Future<void> addRecurringTransfer(RecurringTransferModel transfer) async {
    if (_currentUserId == null) throw Exception('User not logged in');
    await _firestore.collection('recurring_transfers').add(transfer.toMap());
  }

  Stream<List<RecurringTransferModel>> getRecurringTransfers() {
    if (_currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('recurring_transfers')
        .where('userId', isEqualTo: _currentUserId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RecurringTransferModel.fromFirestore(doc))
            .toList());
  }

  Future<void> updateRecurringTransfer(
      String id, RecurringTransferModel transfer) async {
    if (_currentUserId == null) throw Exception('User not logged in');

    // Verify ownership
    final doc =
        await _firestore.collection('recurring_transfers').doc(id).get();
    if (doc.data()?['userId'] != _currentUserId) {
      throw Exception('Unauthorized');
    }

    await _firestore
        .collection('recurring_transfers')
        .doc(id)
        .update(transfer.toMap());
  }

  Future<void> deleteRecurringTransfer(String id) async {
    if (_currentUserId == null) throw Exception('User not logged in');

    // Verify ownership
    final doc =
        await _firestore.collection('recurring_transfers').doc(id).get();
    if (doc.data()?['userId'] != _currentUserId) {
      throw Exception('Unauthorized');
    }

    await _firestore.collection('recurring_transfers').doc(id).delete();
  }

  Future<void> processRecurringTransfers() async {
    if (_currentUserId == null) return;

    final snapshot = await _firestore
        .collection('recurring_transfers')
        .where('userId', isEqualTo: _currentUserId)
        .where('isActive', isEqualTo: true)
        .get();

    for (var doc in snapshot.docs) {
      final transfer = RecurringTransferModel.fromFirestore(doc);
      if (_shouldProcess(transfer)) {
        final transaction = TransactionModel(
          userId: _currentUserId!,
          id: '',
          type: 'transfer',
          amount: transfer.amount,
          category: 'Transfer',
          date: DateTime.now(),
          note: 'Recurring: ${transfer.note ?? ""}',
          fromAccount: transfer.fromAccountId,
          toAccount: transfer.toAccountId,
          isRecurring: true,
          recurringFrequency: transfer.frequency,
          createdAt: DateTime.now(),
        );

        await _transactionService.addTransaction(transaction);
        await _updateLastProcessed(doc.id);
      }
    }
  }

  bool _shouldProcess(RecurringTransferModel transfer) {
    final now = DateTime.now();
    final lastExecuted = transfer.lastExecuted;

    if (lastExecuted == null) return true;

    switch (transfer.frequency) {
      case 'daily':
        return now.difference(lastExecuted).inDays >= 1;
      case 'weekly':
        return now.difference(lastExecuted).inDays >= 7;
      case 'monthly':
        return now.month != lastExecuted.month || now.year != lastExecuted.year;
      default:
        return false;
    }
  }

  Future<void> _updateLastProcessed(String id) async {
    await _firestore.collection('recurring_transfers').doc(id).update({
      'lastExecuted': Timestamp.fromDate(DateTime.now()),
    });
  }
}
