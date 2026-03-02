// lib/services/net_worth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/net_worth_model.dart';

class NetWorthService {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('net_worth_items');

  // ── Streams ───────────────────────────────────────────────────────────────
  Stream<List<NetWorthItem>> getItems() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _col
        .where('userId', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(NetWorthItem.fromFirestore).toList());
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────
  Future<void> addItem(NetWorthItem item) async {
    final uid = _uid;
    if (uid == null) return;
    await _col.add(item.copyWith(userId: uid).toMap());
  }

  Future<void> updateItem(NetWorthItem item) async {
    if (item.id == null) return;
    await _col.doc(item.id).update({
      ...item.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteItem(String id) =>
      _col.doc(id).delete();
}