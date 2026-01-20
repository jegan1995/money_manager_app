import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/budget_model.dart';

class BudgetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'budgets';

  // Get budgets as QuerySnapshot Stream
  Stream<QuerySnapshot> getBudgets() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get budgets for specific month/year as QuerySnapshot
  Stream<QuerySnapshot> getBudgetsForMonth(int month, int year) {
    return _firestore
        .collection(_collection)
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .snapshots();
  }

  // Add budget
  Future<void> addBudget(BudgetModel budget) async {
    await _firestore.collection(_collection).add(budget.toMap());
  }

  // Update budget
  Future<void> updateBudget(String id, BudgetModel budget) async {
    await _firestore.collection(_collection).doc(id).update(budget.toMap());
  }

  // Delete budget
  Future<void> deleteBudget(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  // Get budget by ID
  Future<BudgetModel?> getBudgetById(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    return doc.exists ? BudgetModel.fromFirestore(doc) : null;
  }
}
