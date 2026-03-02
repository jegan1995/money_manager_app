// lib/services/loan_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/loan_model.dart';

class LoanService {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('loans');

  // ── Streams ───────────────────────────────────────────────────────────────
  Stream<List<LoanModel>> getLoans() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _col
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(LoanModel.fromFirestore).toList());
  }

  Stream<List<LoanModel>> getActiveLoans() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _col
        .where('userId',   isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(LoanModel.fromFirestore).toList());
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────
  Future<void> addLoan(LoanModel loan) async {
    final uid = _uid;
    if (uid == null) return;
    await _col.add(loan.copyWith(userId: uid).toMap());
  }

  Future<void> updateLoan(LoanModel loan) async {
    if (loan.id == null) return;
    await _col.doc(loan.id).update(loan.toMap());
  }

  Future<void> deleteLoan(String id) => _col.doc(id).delete();

  // Record a prepayment — adds to extraPayments
  Future<void> recordPrepayment(LoanModel loan, double amount) async {
    if (loan.id == null) return;
    await _col.doc(loan.id).update({
      'extraPayments': loan.extraPayments + amount,
    });
  }

  // Mark loan as closed
  Future<void> closeLoan(String id) async =>
      _col.doc(id).update({'isActive': false});
}