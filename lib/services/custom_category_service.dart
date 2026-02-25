import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/custom_category_model.dart';

class CustomCategoryService {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  static const _col = 'custom_categories';

  String? get _uid => _auth.currentUser?.uid;

  // ── Streams ────────────────────────────────────────────────────────────────
  Stream<List<CustomCategory>> getCategories({String? type}) {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    var query = _db
        .collection(_col)
        .where('userId', isEqualTo: uid);

    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }

    return query
        .snapshots()
        .map((s) => s.docs.map(CustomCategory.fromFirestore).toList());
  }

  // ── One-time fetch ─────────────────────────────────────────────────────────
  Future<List<CustomCategory>> getCategoriesOnce({String? type}) async {
    final uid = _uid;
    if (uid == null) return [];

    var query = _db
        .collection(_col)
        .where('userId', isEqualTo: uid);

    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }

    final snap = await query.get();
    return snap.docs.map(CustomCategory.fromFirestore).toList();
  }

  // ── Just names for category picker ─────────────────────────────────────────
  Future<List<String>> getCategoryNames({required String type}) async {
    final cats = await getCategoriesOnce(type: type);
    return cats.map((c) => c.name).toList();
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────
  Future<void> addCategory(CustomCategory cat) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');
    final map = cat.toMap()..['userId'] = uid;
    await _db.collection(_col).add(map);
  }

  Future<void> updateCategory(CustomCategory cat) async {
    if (_uid == null || cat.id == null) return;
    await _db.collection(_col).doc(cat.id).update(cat.toMap());
  }

  Future<void> deleteCategory(String id) async {
    if (_uid == null) return;
    await _db.collection(_col).doc(id).delete();
  }

  // ── Check name uniqueness (client-side to avoid composite index) ───────────
  Future<bool> nameExists(String name, String type, {String? excludeId}) async {
    final cats = await getCategoriesOnce(type: type);
    return cats.any((c) =>
        c.name.toLowerCase() == name.trim().toLowerCase() &&
        c.id != excludeId);
  }
}