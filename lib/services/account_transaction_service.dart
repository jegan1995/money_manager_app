import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';

class AccountTransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add transaction and update account balances
  Future<void> addTransactionWithAccountUpdate(TransactionModel transaction) async {
    final batch = _firestore.batch();

    // Add transaction
    final transactionRef = _firestore.collection('transactions').doc();
    batch.set(transactionRef, transaction.toMap());

    // Update account balances
    if (transaction.type == 'income' && transaction.toAccount != null) {
      final accountRef = _firestore.collection('accounts').doc(transaction.toAccount);
      batch.update(accountRef, {
        'balance': FieldValue.increment(transaction.amount),
      });
    } else if (transaction.type == 'expense' && transaction.fromAccount != null) {
      final accountRef = _firestore.collection('accounts').doc(transaction.fromAccount);
      batch.update(accountRef, {
        'balance': FieldValue.increment(-transaction.amount),
      });
    } else if (transaction.type == 'transfer') {
      if (transaction.fromAccount != null) {
        final fromAccountRef = _firestore.collection('accounts').doc(transaction.fromAccount);
        batch.update(fromAccountRef, {
          'balance': FieldValue.increment(-transaction.amount),
        });
      }
      if (transaction.toAccount != null) {
        final toAccountRef = _firestore.collection('accounts').doc(transaction.toAccount);
        batch.update(toAccountRef, {
          'balance': FieldValue.increment(transaction.amount),
        });
      }
    }

    await batch.commit();
  }

  // Delete transaction and revert account balances
  Future<void> deleteTransactionWithAccountUpdate(TransactionModel transaction) async {
    final batch = _firestore.batch();

    // Delete transaction
    final transactionRef = _firestore.collection('transactions').doc(transaction.id);
    batch.delete(transactionRef);

    // Revert account balances
    if (transaction.type == 'income' && transaction.toAccount != null) {
      final accountRef = _firestore.collection('accounts').doc(transaction.toAccount);
      batch.update(accountRef, {
        'balance': FieldValue.increment(-transaction.amount),
      });
    } else if (transaction.type == 'expense' && transaction.fromAccount != null) {
      final accountRef = _firestore.collection('accounts').doc(transaction.fromAccount);
      batch.update(accountRef, {
        'balance': FieldValue.increment(transaction.amount),
      });
    } else if (transaction.type == 'transfer') {
      if (transaction.fromAccount != null) {
        final fromAccountRef = _firestore.collection('accounts').doc(transaction.fromAccount);
        batch.update(fromAccountRef, {
          'balance': FieldValue.increment(transaction.amount),
        });
      }
      if (transaction.toAccount != null) {
        final toAccountRef = _firestore.collection('accounts').doc(transaction.toAccount);
        batch.update(toAccountRef, {
          'balance': FieldValue.increment(-transaction.amount),
        });
      }
    }

    await batch.commit();
  }
}