import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/split_expense_model.dart';

class SplitExpenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _collection = 'split_expenses';

  String? get _currentUserId => _auth.currentUser?.uid;

  Stream<List<SplitExpenseModel>> getSplitExpenses() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => SplitExpenseModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Future<void> addSplitExpense(SplitExpenseModel expense) async {
    if (_currentUserId == null) throw Exception('User not logged in');

    final exp = SplitExpenseModel(
      id: '',
      userId: _currentUserId!,
      description: expense.description,
      totalAmount: expense.totalAmount,
      splits: expense.splits,
      date: expense.date,
      category: expense.category,
      isSettled: false,
      createdAt: DateTime.now(),
    );

    await _firestore.collection(_collection).add(exp.toMap());
  }

  Future<void> updateSplitExpense(String id, SplitExpenseModel expense) async {
    if (_currentUserId == null) throw Exception('User not logged in');
    await _firestore.collection(_collection).doc(id).update(expense.toMap());
  }

  Future<void> markPersonPaid(String expenseId, int personIndex) async {
    if (_currentUserId == null) throw Exception('User not logged in');

    final doc = await _firestore.collection(_collection).doc(expenseId).get();
    if (!doc.exists) return;

    final expense = SplitExpenseModel.fromFirestore(doc);
    final updatedSplits = List<SplitPerson>.from(expense.splits);
    updatedSplits[personIndex] =
        updatedSplits[personIndex].copyWith(isPaid: true);

    // Check if all paid
    final allPaid = updatedSplits.every((s) => s.isPaid);

    await _firestore.collection(_collection).doc(expenseId).update({
      'splits': updatedSplits.map((s) => s.toMap()).toList(),
      'isSettled': allPaid,
    });
  }

  Future<void> deleteSplitExpense(String id) async {
    if (_currentUserId == null) throw Exception('User not logged in');
    await _firestore.collection(_collection).doc(id).delete();
  }
}
