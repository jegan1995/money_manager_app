import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ── Your admin UID — set this to YOUR Firebase UID ────────────────────────────
// To find your UID: Firebase Console → Authentication → Users → copy your UID
const String kAdminUID = '2HhYuuNPWUSJiHRYtL4UUfNNWfp2';

class AdminService {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // ── Is current user admin? ──────────────────────────────────────────────────
  bool get isAdmin => _uid == kAdminUID;

  Future<bool> checkIsAdmin() async {
    if (_uid == null) return false;
    if (_uid == kAdminUID) return true;
    try {
      final doc = await _db.collection('admins').doc(_uid).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  // ── Get all users ───────────────────────────────────────────────────────────
  Stream<List<AppUser>> getAllUsers() {
    return _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AppUser.fromFirestore(d))
            .toList());
  }

  // ── Get app-wide stats ──────────────────────────────────────────────────────
  Future<AppStats> getAppStats() async {
    try {
      final usersSnap = await _db.collection('users').get();
      final totalUsers = usersSnap.docs.length;
      
      int totalTransactions = 0;
      int activeToday = 0;
      double totalVolume = 0;

      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      for (final userDoc in usersSnap.docs) {
        // Count transactions per user
        try {
          final txnSnap = await _db
              .collection('users')
              .doc(userDoc.id)
              .collection('transactions')
              .get();
          totalTransactions += txnSnap.docs.length;
          for (final t in txnSnap.docs) {
            final amt = (t.data()['amount'] ?? 0).toDouble();
            totalVolume += amt;
          }
        } catch (_) {}

        // Check last active
        final lastActive = userDoc.data()['lastActive'] as Timestamp?;
        if (lastActive != null &&
            lastActive.toDate().isAfter(todayStart)) {
          activeToday++;
        }
      }

      return AppStats(
        totalUsers: totalUsers,
        totalTransactions: totalTransactions,
        activeToday: activeToday,
        totalVolume: totalVolume,
      );
    } catch (e) {
      return AppStats(
          totalUsers: 0,
          totalTransactions: 0,
          activeToday: 0,
          totalVolume: 0);
    }
  }

  // ── Update user status ──────────────────────────────────────────────────────
  Future<void> updateUserStatus(String uid, String status) async {
    await _db.collection('users').doc(uid).update({'status': status});
  }

  // ── Update user access level ────────────────────────────────────────────────
  Future<void> updateUserAccess(String uid, String access) async {
    await _db.collection('users').doc(uid).update({'access': access});
  }

  // ── Update individual feature flags ────────────────────────────────────────
  Future<void> updateUserFeatures(
      String uid, Map<String, bool> features) async {
    await _db.collection('users').doc(uid).update({'features': features});
  }

  // ── Get current user's access level (used by other screens) ────────────────
  Future<UserAccess> getCurrentUserAccess() async {
    if (_uid == null) return UserAccess.full;
    if (_uid == kAdminUID) return UserAccess.full;
    try {
      final doc = await _db.collection('users').doc(_uid).get();
      final data = doc.data();
      if (data == null) return UserAccess.full;

      final status = data['status'] ?? 'active';
      if (status == 'suspended') return UserAccess.suspended;

      final access = data['access'] ?? 'full';
      switch (access) {
        case 'readonly': return UserAccess.readonly;
        case 'limited':  return UserAccess.limited;
        default:         return UserAccess.full;
      }
    } catch (_) {
      return UserAccess.full;
    }
  }

  // ── Check if a specific feature is enabled for current user ─────────────────
  Future<bool> isFeatureEnabled(String feature) async {
    if (_uid == null) return false;
    if (_uid == kAdminUID) return true;
    try {
      final doc = await _db.collection('users').doc(_uid).get();
      final features = doc.data()?['features'] as Map<String, dynamic>?;
      if (features == null) return true; // default: all enabled
      return features[feature] ?? true;
    } catch (_) {
      return true;
    }
  }

  // ── Send broadcast message to all users ─────────────────────────────────────
  Future<void> sendBroadcast(String title, String message) async {
    await _db.collection('broadcasts').add({
      'title':     title,
      'message':   message,
      'sentAt':    FieldValue.serverTimestamp(),
      'sentBy':    _uid,
    });
  }

  // ── Update lastActive for current user ──────────────────────────────────────
  Future<void> updateLastActive() async {
    if (_uid == null) return;
    try {
      await _db.collection('users').doc(_uid).set(
        {'lastActive': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  // ── Initialize admin record in Firestore ─────────────────────────────────────
  Future<void> ensureAdminRecord() async {
    if (_uid != kAdminUID) return;
    await _db.collection('admins').doc(_uid).set(
      {'role': 'superadmin', 'uid': _uid},
      SetOptions(merge: true),
    );
  }
}

// ── Models ──────────────────────────────────────────────────────────────────

enum UserAccess { full, limited, readonly, suspended }

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String status;
  final String access;
  final Map<String, bool> features;
  final DateTime? createdAt;
  final DateTime? lastActive;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.status,
    required this.access,
    required this.features,
    this.createdAt,
    this.lastActive,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final rawFeatures =
        d['features'] as Map<String, dynamic>? ?? {};
    return AppUser(
      uid:        doc.id,
      name:       d['name']   ?? 'Unknown',
      email:      d['email']  ?? '',
      status:     d['status'] ?? 'active',
      access:     d['access'] ?? 'full',
      features:   rawFeatures.map(
          (k, v) => MapEntry(k, v == true)),
      createdAt:  (d['createdAt'] as Timestamp?)?.toDate(),
      lastActive: (d['lastActive'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, bool> get defaultFeatures => {
    'budget':    true,
    'reports':   true,
    'export':    true,
    'import':    true,
    'pdfReport': true,
    'goals':     true,
    'transfers': true,
    'recurring': true,
    'emiCalc':   true,
    'netWorth':  true,
  };

  Map<String, bool> get effectiveFeatures {
    final def = defaultFeatures;
    def.addAll(features);
    return def;
  }
}

class AppStats {
  final int totalUsers;
  final int totalTransactions;
  final int activeToday;
  final double totalVolume;

  AppStats({
    required this.totalUsers,
    required this.totalTransactions,
    required this.activeToday,
    required this.totalVolume,
  });
}