// lib/services/investment_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/investment_model.dart';

class InvestmentService {
  final _db   = FirebaseFirestore.instance;
  final _auth  = FirebaseAuth.instance;
  String get _uid => _auth.currentUser?.uid ?? '';
  CollectionReference get _col => _db.collection('investments');

  Stream<List<InvestmentModel>> getInvestments() =>
      _col.where('userId', isEqualTo: _uid)
          .snapshots()
          .map((s) => s.docs
              .map((d) => InvestmentModel.fromFirestore(d))
              .toList()
            ..sort((a, b) => b.currentValue.compareTo(a.currentValue)));

  Future<void> add(InvestmentModel inv) async =>
      await _col.add(inv.toMap());

  Future<void> update(String id, InvestmentModel inv) async =>
      await _col.doc(id).update(inv.toMap());

  Future<void> updateCurrentValue(String id, double value) async =>
      await _col.doc(id).update({'currentValue': value});

  Future<void> delete(String id) async => await _col.doc(id).delete();
}