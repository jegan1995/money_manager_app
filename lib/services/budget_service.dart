import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/budget_model.dart';

class BudgetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _collection = 'budgets';

  String? get _currentUserId => _auth.currentUser?.uid;

  Stream<QuerySnapshot> getBudgets() {
    final userId = _currentUserId;
    if (userId == null) return const Stream.empty();
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  Stream<QuerySnapshot> getBudgetsForMonth(int month, int year) {
    final userId = _currentUserId;
    if (userId == null) return const Stream.empty();
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .snapshots();
  }

  Future<void> addBudget(BudgetModel budget) async {
    if (_currentUserId == null) throw Exception('User not logged in');
    await _firestore.collection(_collection).add(budget.toMap());
  }

  Future<void> updateBudget(String id, BudgetModel budget) async {
    if (_currentUserId == null) throw Exception('User not logged in');
    await _firestore.collection(_collection).doc(id).update(budget.toMap());
  }

  Future<void> deleteBudget(String id) async {
    if (_currentUserId == null) throw Exception('User not logged in');
    await _firestore.collection(_collection).doc(id).delete();
  }

  Future<BudgetModel?> getBudgetById(String id) async {
    if (_currentUserId == null) throw Exception('User not logged in');
    final doc = await _firestore.collection(_collection).doc(id).get();
    return doc.exists ? BudgetModel.fromFirestore(doc) : null;
  }
}
