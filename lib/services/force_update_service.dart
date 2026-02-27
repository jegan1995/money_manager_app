// lib/services/force_update_service.dart
//
// HOW IT WORKS:
// 1. Admin sets the Firestore doc: app_config/version
//    { min_version: "1.3.0", current_version: "1.3.0",
//      force_update: true, update_message: "...", update_url: "..." }
// 2. This service compares app's current version against min_version
// 3. If app version < min_version → show ForceUpdateScreen (full block)
// 4. If update available but not forced → show optional banner

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionInfo {
  final String currentVersion;   // e.g. "1.2.0"
  final String minVersion;        // minimum required
  final bool   forceUpdate;
  final bool   softUpdate;
  final String updateMessage;
  final String updateUrl;         // Play Store / App Store link
  final String whatsNew;

  const AppVersionInfo({
    required this.currentVersion,
    required this.minVersion,
    required this.forceUpdate,
    required this.softUpdate,
    required this.updateMessage,
    required this.updateUrl,
    required this.whatsNew,
  });

  bool get needsForceUpdate => forceUpdate && _isOlderThan(currentVersion, minVersion);
  bool get needsSoftUpdate  => softUpdate  && _isOlderThan(currentVersion, minVersion) && !needsForceUpdate;

  static bool _isOlderThan(String current, String min) {
    try {
      final c = current.split('.').map(int.parse).toList();
      final m = min.split('.').map(int.parse).toList();
      while (c.length < 3) c.add(0);
      while (m.length < 3) m.add(0);
      for (int i = 0; i < 3; i++) {
        if (c[i] < m[i]) return true;
        if (c[i] > m[i]) return false;
      }
      return false; // equal
    } catch (_) {
      return false;
    }
  }
}

class ForceUpdateService {
  static final _db = FirebaseFirestore.instance;

  // Stream — auto-updates when admin changes Firestore
  static Stream<AppVersionInfo?> watchUpdateStatus() {
    return _db.collection('app_config').doc('version').snapshots().asyncMap(
      (snap) async {
        if (!snap.exists) return null;
        final data = snap.data()!;

        PackageInfo info;
        try {
          info = await PackageInfo.fromPlatform();
        } catch (_) {
          // On web preview, package_info might fail → use hardcoded version
          return AppVersionInfo(
            currentVersion: '1.2.0',
            minVersion: data['min_version'] ?? '1.0.0',
            forceUpdate: data['force_update'] ?? false,
            softUpdate:  data['soft_update']  ?? false,
            updateMessage: data['update_message'] ?? 'A new update is available.',
            updateUrl: data['update_url'] ?? '',
            whatsNew: data['whats_new'] ?? '',
          );
        }

        return AppVersionInfo(
          currentVersion: info.version,
          minVersion: data['min_version'] ?? '1.0.0',
          forceUpdate: data['force_update'] ?? false,
          softUpdate:  data['soft_update']  ?? false,
          updateMessage: data['update_message'] ?? 'A new update is available.',
          updateUrl: data['update_url'] ?? '',
          whatsNew: data['whats_new'] ?? '',
        );
      },
    );
  }

  // ── Admin helpers ──────────────────────────────────────────────────────────

  /// Set a forced update (blocks old users)
  static Future<void> setForceUpdate({
    required String minVersion,
    required String currentVersion,
    required String updateMessage,
    required String updateUrl,
    String whatsNew = '',
  }) async {
    await _db.collection('app_config').doc('version').set({
      'min_version':     minVersion,
      'current_version': currentVersion,
      'force_update':    true,
      'soft_update':     false,
      'update_message':  updateMessage,
      'update_url':      updateUrl,
      'whats_new':       whatsNew,
      'updated_at':      FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Set a gentle update nudge (dismissable)
  static Future<void> setSoftUpdate({
    required String currentVersion,
    required String updateUrl,
    String whatsNew = '',
  }) async {
    await _db.collection('app_config').doc('version').set({
      'current_version': currentVersion,
      'force_update':    false,
      'soft_update':     true,
      'update_url':      updateUrl,
      'whats_new':       whatsNew,
      'updated_at':      FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Clear all update flags
  static Future<void> clearUpdate() async {
    await _db.collection('app_config').doc('version').set({
      'force_update': false,
      'soft_update':  false,
      'updated_at':   FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}