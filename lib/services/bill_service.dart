// lib/services/bill_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bill_model.dart';

class BillService {
  final _db   = FirebaseFirestore.instance;
  final _auth  = FirebaseAuth.instance;
  String get _uid => _auth.currentUser?.uid ?? '';
  CollectionReference get _col => _db.collection('bill_reminders');

  Stream<List<BillModel>> getBills() =>
      _col.where('userId', isEqualTo: _uid)
          .snapshots()
          .map((s) => s.docs.map((d) => BillModel.fromFirestore(d)).toList()
            ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate)));

  Future<void> add(BillModel b) async => await _col.add(b.toMap());

  Future<void> update(String id, BillModel b) async =>
      await _col.doc(id).update(b.toMap());

  Future<void> delete(String id) async => await _col.doc(id).delete();

  Future<void> markPaid(String id) async {
    await _col.doc(id).update({
      'status': 'paid',
      'paidDate': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> markUnpaid(String id) async {
    await _col.doc(id).update({
      'status': 'pending',
      'paidDate': null,
    });
  }
}