import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/net_worth_model.dart';

class NetWorthService {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // ── Items ──────────────────────────────────────────────────────────────────
  Stream<List<NetWorthItem>> getItems() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _db
        .collection('net_worth_items')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(NetWorthItem.fromFirestore).toList());
  }

  Future<void> addItem(NetWorthItem item) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');
    // Inject real userId before saving
    final map = item.toMap();
    map['userId'] = uid;
    await _db.collection('net_worth_items').add(map);
  }

  Future<void> updateItem(NetWorthItem item) async {
    if (_uid == null || item.id == null) return;
    await _db
        .collection('net_worth_items')
        .doc(item.id)
        .update(item.toMap());
  }

  Future<void> deleteItem(String id) async {
    if (_uid == null) return;
    await _db.collection('net_worth_items').doc(id).delete();
  }

  // ── Snapshots (monthly history) ────────────────────────────────────────────
  Stream<List<NetWorthSnapshot>> getSnapshots() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _db
        .collection('net_worth_snapshots')
        .where('userId', isEqualTo: uid)
        .orderBy('date', descending: false)
        .snapshots()
        .map((s) => s.docs.map(NetWorthSnapshot.fromFirestore).toList());
  }

  /// Save a snapshot for today — overwrites if one exists this month
  Future<void> saveSnapshot({
    required double totalAssets,
    required double totalLiabilities,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final now   = DateTime.now();
    final month = DateTime(now.year, now.month, 1);

    // Check if a snapshot already exists for this month
    final existing = await _db
        .collection('net_worth_snapshots')
        .where('userId', isEqualTo: uid)
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(month),
            isLessThan: Timestamp.fromDate(
                DateTime(now.year, now.month + 1, 1)))
        .get();

    final snap = NetWorthSnapshot(
      userId:           uid,
      totalAssets:      totalAssets,
      totalLiabilities: totalLiabilities,
      netWorth:         totalAssets - totalLiabilities,
      date:             now,
    );

    if (existing.docs.isNotEmpty) {
      await _db
          .collection('net_worth_snapshots')
          .doc(existing.docs.first.id)
          .update(snap.toMap());
    } else {
      await _db.collection('net_worth_snapshots').add(snap.toMap());
    }
  }
}