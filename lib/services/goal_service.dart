import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/goal_model.dart';

class GoalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _collection = 'goals';

  String? get _currentUserId => _auth.currentUser?.uid;

  Stream<QuerySnapshot> getGoals() {
    final userId = _currentUserId;
    if (userId == null) return const Stream.empty();
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  Future<void> addGoal(GoalModel goal) async {
    if (_currentUserId == null) throw Exception('User not logged in');
    await _firestore.collection(_collection).add(goal.toMap());
  }

  Future<void> updateGoal(String id, GoalModel goal) async {
    if (_currentUserId == null) throw Exception('User not logged in');
    await _firestore.collection(_collection).doc(id).update(goal.toMap());
  }

  Future<void> deleteGoal(String id) async {
    if (_currentUserId == null) throw Exception('User not logged in');
    await _firestore.collection(_collection).doc(id).delete();
  }

  Future<void> addAmountToGoal(String id, double amount) async {
    if (_currentUserId == null) throw Exception('User not logged in');
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        final goal = GoalModel.fromMap(doc.data()!, doc.id);
        final newAmount = goal.currentAmount + amount;
        await _firestore.collection(_collection).doc(id).update({
          'currentAmount': newAmount,
          'isCompleted': newAmount >= goal.targetAmount,
        });
      }
    } catch (e) {
      throw Exception('Failed to add amount: $e');
    }
  }
}
