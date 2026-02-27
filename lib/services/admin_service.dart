import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ── YOUR Admin UID ────────────────────────────────────────────────────────────
// HOW TO FIND: Firebase Console → Authentication → Users → copy UID column
const String kAdminUID = '2HhYuuNPWUSJiHRYtL4UUfNNWfp2';

class AdminService {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // ── Is current user admin ────────────────────────────────────────────────
  bool get isAdminSync => _uid == kAdminUID;

  Future<bool> checkIsAdmin() async {
    return _uid == kAdminUID;
  }

  // ── REAL-TIME stream of current user's access info ────────────────────────
  // This stream fires instantly whenever admin changes anything in Firestore
  Stream<UserAccessInfo> watchCurrentUserAccess() {
    final uid = _uid;
    if (uid == null) {
      return Stream.value(UserAccessInfo.suspended());
    }
    if (uid == kAdminUID) {
      return Stream.value(UserAccessInfo.fullAdmin());
    }
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) {
        return UserAccessInfo.full();
      }
      final data    = doc.data()!;
      final status  = (data['status']  ?? 'active') as String;
      final access  = (data['access']  ?? 'full')   as String;
      final rawF    = data['features'] as Map<String, dynamic>? ?? {};
      final features = rawF.map((k, v) => MapEntry(k, v == true));

      return UserAccessInfo(
        status:      status,
        access:      access,
        features:    features,
        isSuspended: status == 'suspended',
        isReadOnly:  access == 'readonly',
        isLimited:   access == 'limited',
      );
    });
  }

  // ── One-time fetch (kept for admin screens) ───────────────────────────────
  Future<UserAccessInfo> getCurrentUserAccess() async {
    final uid = _uid;
    if (uid == null) return UserAccessInfo.suspended();
    if (uid == kAdminUID) return UserAccessInfo.fullAdmin();
    try {
      final doc  = await _db.collection('users').doc(uid).get();
      final data = doc.data();
      if (data == null) return UserAccessInfo.full();
      final status  = (data['status']  ?? 'active') as String;
      final access  = (data['access']  ?? 'full')   as String;
      final rawF    = data['features'] as Map<String, dynamic>? ?? {};
      final features = rawF.map((k, v) => MapEntry(k, v == true));
      return UserAccessInfo(
        status:      status,
        access:      access,
        features:    features,
        isSuspended: status == 'suspended',
        isReadOnly:  access == 'readonly',
        isLimited:   access == 'limited',
      );
    } catch (_) {
      return UserAccessInfo.full();
    }
  }

  // ── No cache — removed entirely ──────────────────────────────────────────
  void clearCache() {} // kept for compatibility, does nothing now

  // ── Get all users ─────────────────────────────────────────────────────────
  Stream<List<AppUser>> getAllUsers() {
    return _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => AppUser.fromFirestore(d)).toList());
  }

  // ── App stats ─────────────────────────────────────────────────────────────
  Future<AppStats> getAppStats() async {
    try {
      final snap = await _db.collection('users').get();
      int txnTotal = 0, activeToday = 0;
      double volume = 0;
      final todayStart = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      for (final doc in snap.docs) {
        final lastActive =
            (doc.data()['lastActive'] as Timestamp?)?.toDate();
        if (lastActive != null && lastActive.isAfter(todayStart)) {
          activeToday++;
        }
        try {
          final txns = await _db
              .collection('users').doc(doc.id)
              .collection('transactions').get();
          txnTotal += txns.docs.length;
          for (final t in txns.docs) {
            volume += (t.data()['amount'] ?? 0.0).toDouble();
          }
        } catch (_) {}
      }
      return AppStats(
          totalUsers: snap.docs.length,
          totalTransactions: txnTotal,
          activeToday: activeToday,
          totalVolume: volume);
    } catch (_) {
      return AppStats(
          totalUsers: 0, totalTransactions: 0,
          activeToday: 0, totalVolume: 0);
    }
  }

  // ── Admin write actions ────────────────────────────────────────────────────
  Future<void> updateUserStatus(String uid, String status) =>
      _db.collection('users').doc(uid).set(
        {'status': status}, SetOptions(merge: true));

  Future<void> updateUserAccess(String uid, String access) =>
      _db.collection('users').doc(uid).set(
        {'access': access}, SetOptions(merge: true));

  Future<void> updateUserFeatures(String uid, Map<String, bool> f) =>
      _db.collection('users').doc(uid).set(
        {'features': f}, SetOptions(merge: true));

  Future<void> sendBroadcast(String title, String msg) =>
      _db.collection('broadcasts').add({
        'title': title, 'message': msg,
        'sentAt': FieldValue.serverTimestamp(), 'sentBy': _uid,
      });

  Future<void> updateLastActive() async {
    if (_uid == null || _uid == kAdminUID) return;
    try {
      await _db.collection('users').doc(_uid).set(
        {'lastActive': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  Future<void> ensureAdminRecord() async {
    if (_uid != kAdminUID) return;
    await _db.collection('admins').doc(_uid)
        .set({'role': 'superadmin'}, SetOptions(merge: true));
  }
}

// ── UserAccessInfo ─────────────────────────────────────────────────────────────
class UserAccessInfo {
  final String status;
  final String access;
  final Map<String, bool> features;
  final bool isSuspended;
  final bool isReadOnly;
  final bool isLimited;
  final bool isAdmin;

  const UserAccessInfo({
    required this.status,
    required this.access,
    required this.features,
    required this.isSuspended,
    required this.isReadOnly,
    required this.isLimited,
    this.isAdmin = false,
  });

  factory UserAccessInfo.full() => const UserAccessInfo(
      status: 'active', access: 'full', features: {},
      isSuspended: false, isReadOnly: false, isLimited: false);

  factory UserAccessInfo.fullAdmin() => const UserAccessInfo(
      status: 'active', access: 'full', features: {},
      isSuspended: false, isReadOnly: false, isLimited: false,
      isAdmin: true);

  factory UserAccessInfo.suspended() => const UserAccessInfo(
      status: 'suspended', access: 'none', features: {},
      isSuspended: true, isReadOnly: false, isLimited: false);

  bool isFeatureEnabled(String feature) {
    if (isSuspended) return false;
    if (isAdmin) return true;
    if (features.containsKey(feature)) return features[feature]!;
    if (isLimited) {
      const blocked = ['export', 'import', 'pdfReport'];
      if (blocked.contains(feature)) return false;
    }
    if (isReadOnly) {
      const blocked = ['export', 'import', 'pdfReport',
                       'budget', 'goals', 'transfers', 'recurring'];
      if (blocked.contains(feature)) return false;
    }
    return true;
  }
}

// ── AppUser ────────────────────────────────────────────────────────────────────
class AppUser {
  final String uid, name, email, status, access;
  final Map<String, bool> features;
  final DateTime? createdAt, lastActive;

  AppUser({
    required this.uid, required this.name, required this.email,
    required this.status, required this.access,
    required this.features, this.createdAt, this.lastActive,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final raw = d['features'] as Map<String, dynamic>? ?? {};
    return AppUser(
      uid:        doc.id,
      name:       d['name']       ?? 'Unknown',
      email:      d['email']      ?? '',
      status:     d['status']     ?? 'active',
      access:     d['access']     ?? 'full',
      features:   raw.map((k, v) => MapEntry(k, v == true)),
      createdAt:  (d['createdAt']  as Timestamp?)?.toDate(),
      lastActive: (d['lastActive'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, bool> get defaultFeatures => {
    'budget': true, 'reports': true, 'export': true,
    'import': true, 'pdfReport': true, 'goals': true,
    'transfers': true, 'recurring': true,
    'emiCalc': true, 'netWorth': true,
  };

  Map<String, bool> get effectiveFeatures {
    final m = Map<String, bool>.from(defaultFeatures);
    m.addAll(features);
    return m;
  }
}

// ── AppStats ───────────────────────────────────────────────────────────────────
class AppStats {
  final int totalUsers, totalTransactions, activeToday;
  final double totalVolume;
  const AppStats({
    required this.totalUsers, required this.totalTransactions,
    required this.activeToday, required this.totalVolume,
  });
}