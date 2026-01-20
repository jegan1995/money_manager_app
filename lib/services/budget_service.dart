import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/budget_model.dart';

class BudgetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'budgets';

  // Get budgets as Stream
  Stream<List<BudgetModel>> getBudgets() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BudgetModel.fromFirestore(doc))
            .toList());
  }

  // Add budget
  Future<void> addBudget(BudgetModel budget) async {
    try {
      await _firestore.collection(_collection).add(budget.toMap());
    } catch (e) {
      throw Exception('Failed to add budget: $e');
    }
  }

  // Update budget
  Future<void> updateBudget(String id, BudgetModel budget) async {
    try {
      await _firestore.collection(_collection).doc(id).update(budget.toMap());
    } catch (e) {
      throw Exception('Failed to update budget: $e');
    }
  }

  // Delete budget
  Future<void> deleteBudget(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete budget: $e');
    }
  }

  // Get budget by ID
  Future<BudgetModel?> getBudgetById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return BudgetModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get budget: $e');
    }
  }
}

  // Get budgets for specific month/year
  Stream<List<BudgetModel>> getBudgetsForMonth(int month, int year) {
    return _firestore
        .collection(_collection)
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BudgetModel.fromFirestore(doc))
            .toList());
  }
