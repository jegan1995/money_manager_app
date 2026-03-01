// lib/services/subscription_service.dart
// FIX: Removed .orderBy('nextBilling') — that combination with .where('userId')
// requires a Firestore composite index which causes silent empty results.
// Sorting is now done client-side after fetch.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/subscription_model.dart';

class SubscriptionService {
  final _db   = FirebaseFirestore.instance;
  final _auth  = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';
  CollectionReference get _col => _db.collection('subscriptions');

  Stream<List<SubscriptionModel>> getSubscriptions() =>
      _col
          .where('userId', isEqualTo: _uid)
          // ── NO .orderBy() here — would need composite index ──────────────
          .snapshots()
          .map((s) {
            final list = s.docs
                .map((d) => SubscriptionModel.fromFirestore(d))
                .toList();
            // Sort client-side by nextBilling date ascending
            list.sort((a, b) => a.nextBilling.compareTo(b.nextBilling));
            return list;
          });

  Future<void> add(SubscriptionModel s) async {
    await _col.add(s.copyWith(userId: _uid).toMap());
  }

  Future<void> update(String id, SubscriptionModel s) async {
    await _col.doc(id).update(s.toMap());
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  Future<void> updateStatus(String id, String status) async {
    await _col.doc(id).update({'status': status});
  }

  Future<void> renewSubscription(SubscriptionModel s) async {
    if (s.id == null) return;
    final next = s.nextBillingAfter(
        DateTime.now().add(const Duration(days: 1)));
    await _col.doc(s.id).update({'nextBilling': Timestamp.fromDate(next)});
  }
}