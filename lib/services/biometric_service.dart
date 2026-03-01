// lib/services/biometric_service.dart
// Handles biometric / PIN lock for the app.
// Uses local_auth package for fingerprint/Face ID.
// Falls back gracefully on web.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// local_auth is only available on mobile — import conditionally
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final _auth = LocalAuthentication();

  static const _keyEnabled  = 'biometric_enabled';
  static const _keyLockTime = 'app_lock_timeout'; // minutes

  // ── Availability ────────────────────────────────────────────────────────────
  static Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  static Future<List<String>> availableTypes() async {
    if (kIsWeb) return [];
    try {
      final types = await _auth.getAvailableBiometrics();
      return types.map((t) {
        switch (t) {
          case BiometricType.fingerprint: return 'Fingerprint';
          case BiometricType.face:        return 'Face ID';
          case BiometricType.iris:        return 'Iris';
          default:                        return 'Biometric';
        }
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Settings ────────────────────────────────────────────────────────────────
  static Future<bool> isEnabled() async {
    if (kIsWeb) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyEnabled) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyEnabled, value);
    } catch (_) {}
  }

  static Future<int> getLockTimeout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyLockTime) ?? 1; // default 1 minute
    } catch (_) {
      return 1;
    }
  }

  static Future<void> setLockTimeout(int minutes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLockTime, minutes);
    } catch (_) {}
  }

  // ── Authenticate ─────────────────────────────────────────────────────────────
  /// Returns true if authentication passed (or biometrics not enabled)
  static Future<bool> authenticate({
    String reason = 'Authenticate to open Money Manager',
  }) async {
    if (kIsWeb) return true;
    if (!await isEnabled()) return true;

    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth:  true,
          biometricOnly: false, // allow PIN fallback
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Last active time (for timeout) ───────────────────────────────────────────
  static Future<void> updateLastActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          'last_active', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  static Future<bool> isLockRequired() async {
    if (!await isEnabled()) return false;
    try {
      final prefs  = await SharedPreferences.getInstance();
      final last   = prefs.getInt('last_active') ?? 0;
      final timeout = await getLockTimeout(); // minutes
      final elapsed = DateTime.now().millisecondsSinceEpoch - last;
      return elapsed > timeout * 60 * 1000;
    } catch (_) {
      return false;
    }
  }
}