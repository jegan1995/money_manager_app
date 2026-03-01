// lib/services/biometric_service.dart
//
// iOS PWA FIX:
//   kIsWeb = true on iOS PWA. Previously ALL pin functions had
//   "if (kIsWeb) return" → PIN was never saved → always looked fresh.
//   
//   Fix: PIN uses SharedPreferences on ALL platforms (web + mobile).
//   SharedPreferences → localStorage on web, which DOES persist in iOS PWA.
//   Biometric (fingerprint/FaceID) remains mobile-only (not available on web/PWA).
//   FlutterSecureStorage is only used on mobile (Android/iOS app) for extra security.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final _localAuth = LocalAuthentication();
  static const _secure    = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // SharedPreferences keys
  static const _keyBioEnabled  = 'biometric_enabled';
  static const _keyPinEnabled  = 'pin_enabled';
  static const _keyPinWeb      = 'pin_value_web';   // web: SharedPrefs (localStorage)
  static const _keyPinMobile   = 'app_pin_value';   // mobile: FlutterSecureStorage
  static const _keyLockTime    = 'app_lock_timeout';
  static const _keyLastActive  = 'last_active_ms';

  // ── Biometric (mobile only) ───────────────────────────────────────────────
  static Future<bool> isBiometricAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _localAuth.canCheckBiometrics &&
             await _localAuth.isDeviceSupported();
    } catch (_) { return false; }
  }

  static Future<List<String>> availableTypes() async {
    if (kIsWeb) return [];
    try {
      final types = await _localAuth.getAvailableBiometrics();
      return types.map((t) => switch (t) {
        BiometricType.fingerprint => 'Fingerprint',
        BiometricType.face        => 'Face ID',
        BiometricType.iris        => 'Iris',
        _                         => 'Biometric',
      }).toList();
    } catch (_) { return []; }
  }

  static Future<bool> isBiometricEnabled() async {
    if (kIsWeb) return false; // biometric not available on web/PWA
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(_keyBioEnabled) ?? false;
    } catch (_) { return false; }
  }

  static Future<void> setBiometricEnabled(bool v) async {
    if (kIsWeb) return;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_keyBioEnabled, v);
    } catch (_) {}
  }

  // ── PIN (works on ALL platforms including iOS PWA) ────────────────────────
  // Web/PWA: stored in SharedPreferences → localStorage → persists in iOS PWA
  // Mobile:  stored in FlutterSecureStorage → encrypted on device
  static Future<bool> isPinEnabled() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(_keyPinEnabled) ?? false;
    } catch (_) { return false; }
  }

  static Future<void> setPin(String pin) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (kIsWeb) {
        // Web/iOS PWA: store in localStorage via SharedPreferences
        // Not encrypted but acceptable for PWA context
        await p.setString(_keyPinWeb, pin);
      } else {
        // Mobile: store encrypted via FlutterSecureStorage
        await _secure.write(key: _keyPinMobile, value: pin);
      }
      await p.setBool(_keyPinEnabled, true);
    } catch (_) {}
  }

  static Future<bool> verifyPin(String pin) async {
    try {
      if (kIsWeb) {
        final p      = await SharedPreferences.getInstance();
        final stored = p.getString(_keyPinWeb);
        return stored != null && stored == pin;
      } else {
        final stored = await _secure.read(key: _keyPinMobile);
        return stored != null && stored == pin;
      }
    } catch (_) { return false; }
  }

  static Future<void> removePin() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (kIsWeb) {
        await p.remove(_keyPinWeb);
      } else {
        await _secure.delete(key: _keyPinMobile);
      }
      await p.setBool(_keyPinEnabled, false);
    } catch (_) {}
  }

  // ── Any lock enabled ──────────────────────────────────────────────────────
  static Future<bool> isAnyLockEnabled() async {
    return await isBiometricEnabled() || await isPinEnabled();
  }

  // ── Timeout ───────────────────────────────────────────────────────────────
  static Future<int> getLockTimeout() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getInt(_keyLockTime) ?? 1;
    } catch (_) { return 1; }
  }

  static Future<void> setLockTimeout(int minutes) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_keyLockTime, minutes);
    } catch (_) {}
  }

  static Future<void> markUnlocked() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_keyLastActive, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  static Future<void> markBackgrounded() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_keyLastActive, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  static Future<bool> isLockRequired() async {
    if (!await isAnyLockEnabled()) return false;
    try {
      final p    = await SharedPreferences.getInstance();
      final last = p.getInt(_keyLastActive);
      if (last == null) return true; // never unlocked → require lock
      final timeout = await getLockTimeout();
      final elapsed = DateTime.now().millisecondsSinceEpoch - last;
      return elapsed > timeout * 60 * 1000;
    } catch (_) { return true; } // fail-safe: lock on error
  }

  // ── Biometric auth for ENABLING (no existing-enabled check) ──────────────
  // Used by the toggle in settings — confirms identity BEFORE enabling.
  static Future<bool> confirmWithBiometricForSetup() async {
    if (kIsWeb) return false;
    if (!await isBiometricAvailable()) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Confirm identity to enable biometric lock',
        options: const AuthenticationOptions(
          stickyAuth:           true,
          biometricOnly:        true,
          useErrorDialogs:      true,
          sensitiveTransaction: false,
        ),
      );
    } on PlatformException { return false; }
    catch (_) { return false; }
  }

  // ── Biometric auth — called by AppLockScreen when lock is showing ─────────
  static Future<bool> authenticateBiometric({
    String reason = 'Authenticate to open Money Manager',
  }) async {
    if (kIsWeb) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth:           true,
          biometricOnly:        true,
          useErrorDialogs:      true,
          sensitiveTransaction: false,
        ),
      );
    } on PlatformException { return false; }
    catch (_) { return false; }
  }
}