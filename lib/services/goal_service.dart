import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/goal.dart';

class GoalService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addGoal(Goal goal) async {
    await _db.collection('goals').add(goal.toMap());
  }

  Stream<List<Goal>> getGoals() {
    return _db.collection('goals').snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => Goal.fromFirestore(doc)).toList(),
    );
  }

  Future<void> updateGoalSaved(String id, double amount) async {
    await _db.collection('goals').doc(id).update({'savedAmount': amount});
  }

  Future<void> deleteGoal(String id) async {
    await _db.collection('goals').doc(id).delete();
  }
}
