import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/goal_model.dart';

class GoalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'goals';

  Stream<QuerySnapshot> getGoals() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  Future<void> addGoal(GoalModel goal) async {
    try {
      await _firestore.collection(_collection).add(goal.toMap());
    } catch (e) {
      throw Exception('Failed to add goal: $e');
    }
  }

  Future<void> updateGoal(String id, GoalModel goal) async {
    try {
      await _firestore.collection(_collection).doc(id).update(goal.toMap());
    } catch (e) {
      throw Exception('Failed to update goal: $e');
    }
  }

  Future<void> deleteGoal(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete goal: $e');
    }
  }

  Future<void> addAmountToGoal(String id, double amount) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        final goal = GoalModel.fromMap(doc.data()!, doc.id);
        final newAmount = goal.currentAmount + amount;
        final isCompleted = newAmount >= goal.targetAmount;

        await _firestore.collection(_collection).doc(id).update({
          'currentAmount': newAmount,
          'isCompleted': isCompleted,
        });
      }
    } catch (e) {
      throw Exception('Failed to add amount to goal: $e');
    }
  }
}
