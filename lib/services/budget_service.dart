import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/budget.dart';

class BudgetService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collectionName = 'budgets';

  Future<void> addBudget(Budget budget) async {
    await _db.collection(_collectionName).add(budget.toMap());
  }

  Stream<List<Budget>> getBudgets() {
    return _db.collection(_collectionName).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => Budget.fromFirestore(doc)).toList(),
    );
  }

  Future<void> updateBudget(String id, Budget budget) async {
    await _db.collection(_collectionName).doc(id).update(budget.toMap());
  }

  Future<void> deleteBudget(String id) async {
    await _db.collection(_collectionName).doc(id).delete();
  }
}
