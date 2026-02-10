import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recurring_transfer_model.dart';
import '../models/transaction_model.dart';
import 'transaction_service.dart';
import 'account_service.dart';

class RecurringTransferService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TransactionService _transactionService = TransactionService();
  final AccountService _accountService = AccountService();

  // Add recurring transfer
  Future<void> addRecurringTransfer(RecurringTransferModel recurring) async {
    await _db.collection('recurring_transfers').add(recurring.toMap());
  }

  // Get all recurring transfers
  Stream<List<RecurringTransferModel>> getRecurringTransfers() {
    return _db
        .collection('recurring_transfers')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RecurringTransferModel.fromFirestore(doc))
            .toList());
  }

  // Update recurring transfer
  Future<void> updateRecurringTransfer(String id, RecurringTransferModel recurring) async {
    await _db.collection('recurring_transfers').doc(id).update(recurring.toMap());
  }

  // Delete recurring transfer
  Future<void> deleteRecurringTransfer(String id) async {
    await _db.collection('recurring_transfers').doc(id).delete();
  }

  // Execute due recurring transfers (call this on app start or periodically)
  Future<void> executeDueTransfers() async {
    try {
      final recurringList = await getRecurringTransfers().first;
      final now = DateTime.now();

      for (var recurring in recurringList) {
        if (!recurring.isActive) continue;

        final nextDate = _calculateNextDate(recurring);
        
        // If next date is today or past, execute transfer
        if (nextDate.isBefore(now) || _isSameDay(nextDate, now)) {
          await _executeTransfer(recurring);
        }
      }
    } catch (e) {
      print('Error executing recurring transfers: $e');
    }
  }

  // Calculate next execution date
  DateTime _calculateNextDate(RecurringTransferModel recurring) {
    DateTime next = recurring.lastExecuted ?? recurring.startDate;
    
    switch (recurring.frequency) {
      case 'daily':
        next = next.add(const Duration(days: 1));
        break;
      case 'weekly':
        next = next.add(const Duration(days: 7));
        break;
      case 'monthly':
        next = DateTime(next.year, next.month + 1, next.day);
        break;
      case 'yearly':
        next = DateTime(next.year + 1, next.month, next.day);
        break;
    }
    
    // If calculated date is still in the past, keep adding intervals
    while (next.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
      switch (recurring.frequency) {
        case 'daily':
          next = next.add(const Duration(days: 1));
          break;
        case 'weekly':
          next = next.add(const Duration(days: 7));
          break;
        case 'monthly':
          next = DateTime(next.year, next.month + 1, next.day);
          break;
        case 'yearly':
          next = DateTime(next.year + 1, next.month, next.day);
          break;
      }
    }
    
    return next;
  }

  // Execute a single recurring transfer
  Future<void> _executeTransfer(RecurringTransferModel recurring) async {
    try {
      // Create the transfer transaction
      final transaction = TransactionModel(
        id: '',
        type: 'transfer',
        amount: recurring.amount,
        category: 'Transfer',
        subcategory: recurring.title,
        fromAccount: recurring.fromAccountId,
        toAccount: recurring.toAccountId,
        date: DateTime.now(),
        note: recurring.note != null 
            ? '${recurring.note} (Auto-recurring)' 
            : 'Auto-recurring transfer',
        createdAt: DateTime.now(),
      );

      // Add the transaction
      await _transactionService.addTransaction(transaction);

      // Update account balances
      final accounts = await _accountService.getAccountsList().first;
      final fromAccount = accounts.firstWhere((a) => a.id == recurring.fromAccountId);
      final toAccount = accounts.firstWhere((a) => a.id == recurring.toAccountId);

      await _accountService.updateAccount(
        fromAccount.id!,
        fromAccount.copyWith(balance: fromAccount.balance - recurring.amount),
      );

      await _accountService.updateAccount(
        toAccount.id!,
        toAccount.copyWith(balance: toAccount.balance + recurring.amount),
      );

      // Update last executed date
      await updateRecurringTransfer(
        recurring.id!,
        recurring.copyWith(lastExecuted: DateTime.now()),
      );

      print('Executed recurring transfer: ${recurring.title}');
    } catch (e) {
      print('Error executing transfer ${recurring.title}: $e');
    }
  }

  // Helper to check if two dates are the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}