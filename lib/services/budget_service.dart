import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/budget_model.dart';

class BudgetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'budgets';

  // Get all budgets
  Stream<QuerySnapshot> getBudgets() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get budgets for specific month/year
  Stream<QuerySnapshot> getBudgetsForMonth(int month, int year) {
    return _firestore
        .collection(_collection)
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .snapshots();
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

  // Get budget for specific category
  Future<BudgetModel?> getBudgetForCategory(String category, int month, int year) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('category', isEqualTo: category)
          .where('month', isEqualTo: month)
          .where('year', isEqualTo: year)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return BudgetModel.fromMap(
          snapshot.docs.first.data(),
          snapshot.docs.first.id,
        );
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get budget: $e');
    }
  }
}
