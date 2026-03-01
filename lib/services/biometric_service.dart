// lib/services/biometric_service.dart
// FIX 1: Removed chicken-and-egg bug — enabling biometric no longer
//         requires biometric to already be enabled to confirm.
// FIX 2: updateLastActive() only called AFTER successful unlock,
//         not on every lock check — PIN now actually triggers on restart.
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

  static const _keyBioEnabled = 'biometric_enabled';
  static const _keyPinEnabled = 'pin_enabled';
  static const _keyPin        = 'app_pin_value';
  static const _keyLockTime   = 'app_lock_timeout';
  static const _keyLastActive = 'last_active_ms';

  // ── Availability ──────────────────────────────────────────────────────────
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

  // ── Biometric on/off ──────────────────────────────────────────────────────
  static Future<bool> isBiometricEnabled() async {
    if (kIsWeb) return false;
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(_keyBioEnabled) ?? false;
    } catch (_) { return false; }
  }

  static Future<void> setBiometricEnabled(bool v) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_keyBioEnabled, v);
    } catch (_) {}
  }

  // ── PIN ───────────────────────────────────────────────────────────────────
  static Future<bool> isPinEnabled() async {
    if (kIsWeb) return false;
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(_keyPinEnabled) ?? false;
    } catch (_) { return false; }
  }

  static Future<void> setPin(String pin) async {
    if (kIsWeb) return;
    try {
      await _secure.write(key: _keyPin, value: pin);
      final p = await SharedPreferences.getInstance();
      await p.setBool(_keyPinEnabled, true);
    } catch (_) {}
  }

  static Future<bool> verifyPin(String pin) async {
    if (kIsWeb) return false;
    try {
      final stored = await _secure.read(key: _keyPin);
      return stored != null && stored == pin;
    } catch (_) { return false; }
  }

  static Future<void> removePin() async {
    if (kIsWeb) return;
    try {
      await _secure.delete(key: _keyPin);
      final p = await SharedPreferences.getInstance();
      await p.setBool(_keyPinEnabled, false);
    } catch (_) {}
  }

  // ── Any lock enabled? ─────────────────────────────────────────────────────
  static Future<bool> isAnyLockEnabled() async {
    if (kIsWeb) return false;
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

  // ── FIX 2: updateLastActive only called after SUCCESSFUL unlock ───────────
  // Previously was called even when lock was NOT required (every app open),
  // so the timer always reset, PIN/biometric never triggered on next open.
  static Future<void> markUnlocked() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_keyLastActive, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  // Called when app goes to background — records the "paused at" time
  static Future<void> markBackgrounded() async {
    try {
      final p = await SharedPreferences.getInstance();
      // Store 0 to force lock on next open (will be overwritten by markUnlocked)
      // Actually store current time — isLockRequired computes elapsed
      await p.setInt(_keyLastActive, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  static Future<bool> isLockRequired() async {
    if (!await isAnyLockEnabled()) return false;
    try {
      final p       = await SharedPreferences.getInstance();
      final last    = p.getInt(_keyLastActive);
      // Never unlocked before → always require lock
      if (last == null) return true;
      final timeout = await getLockTimeout();
      final elapsed = DateTime.now().millisecondsSinceEpoch - last;
      return elapsed > timeout * 60 * 1000;
    } catch (_) { return true; } // Fail safe: lock on error
  }

  // ── FIX 1: Biometric auth for ENABLING (no existing-enabled check) ─────────
  // Previously: authenticateBiometric() → checks isBiometricEnabled() first
  //             → returns false immediately because it's not enabled yet!
  // Now: separate method for confirming identity before enabling.
  static Future<bool> confirmWithBiometricForSetup() async {
    if (kIsWeb) return false;
    if (!await isBiometricAvailable()) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Confirm your identity to enable biometric lock',
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

  // Regular auth — used by AppLockScreen (only called if biometric IS enabled)
  static Future<bool> authenticateBiometric({
    String reason = 'Authenticate to open Money Manager',
  }) async {
    if (kIsWeb) return false;
    // NO check for isBiometricEnabled here — caller is responsible
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