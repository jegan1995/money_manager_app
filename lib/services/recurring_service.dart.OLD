import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart' as app_transaction;

class RecurringService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addRecurring(RecurringTransaction recurring) async {
    await _db.collection('recurring_transactions').add(recurring.toMap());
  }

  Stream<List<RecurringTransaction>> getRecurringTransactions() {
    return _db.collection('recurring_transactions').snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => RecurringTransaction.fromFirestore(doc)).toList(),
    );
  }

  Future<void> deleteRecurring(String id) async {
    await _db.collection('recurring_transactions').doc(id).delete();
  }

  Future<void> generateDueTransactions() async {
    final recurring = await getRecurringTransactions().first;
    final now = DateTime.now();

    for (var r in recurring) {
      if (_shouldGenerate(r, now)) {
        await _generateTransaction(r);
        await _updateLastGenerated(r.id, now);
      }
    }
  }

  bool _shouldGenerate(RecurringTransaction r, DateTime now) {
    switch (r.frequency) {
      case 'daily':
        return now.difference(r.lastGenerated).inDays >= 1;
      case 'weekly':
        return now.difference(r.lastGenerated).inDays >= 7;
      case 'monthly':
        return now.month != r.lastGenerated.month || now.year != r.lastGenerated.year;
      case 'yearly':
        return now.year != r.lastGenerated.year;
      default:
        return false;
    }
  }

  Future<void> _generateTransaction(RecurringTransaction r) async {
    final transaction = app_transaction.Transaction(
      id: '',
      title: r.title,
      amount: r.amount,
      category: r.category,
      type: r.type,
      date: DateTime.now(),
      notes: r.notes,
    );
    await _db.collection('transactions').add(transaction.toMap());
  }

  Future<void> _updateLastGenerated(String id, DateTime date) async {
    await _db.collection('recurring_transactions').doc(id).update({
      'lastGenerated': Timestamp.fromDate(date),
    });
  }
}
