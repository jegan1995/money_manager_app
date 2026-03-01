// lib/services/biometric_service.dart
// PIN stored securely using flutter_secure_storage (already in your pubspec).
// On web: secure storage falls back to localStorage — PIN lock disabled on web.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final _auth    = LocalAuthentication();
  static const _secure  = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyBioEnabled  = 'biometric_enabled';
  static const _keyPinEnabled  = 'pin_enabled';
  static const _keyPin         = 'app_pin_value';   // stored encrypted
  static const _keyLockTime    = 'app_lock_timeout';
  static const _keyLastActive  = 'last_active';

  // ── Biometric availability ────────────────────────────────────────────────
  static Future<bool> isBiometricAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
    } catch (_) { return false; }
  }

  static Future<List<String>> availableTypes() async {
    if (kIsWeb) return [];
    try {
      final types = await _auth.getAvailableBiometrics();
      return types.map((t) => switch (t) {
        BiometricType.fingerprint => 'Fingerprint',
        BiometricType.face        => 'Face ID',
        BiometricType.iris        => 'Iris',
        _                         => 'Biometric',
      }).toList();
    } catch (_) { return []; }
  }

  // ── Biometric toggle ──────────────────────────────────────────────────────
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

  // ── PIN management ────────────────────────────────────────────────────────
  static Future<bool> isPinEnabled() async {
    if (kIsWeb) return false;
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(_keyPinEnabled) ?? false;
    } catch (_) { return false; }
  }

  /// Saves PIN as encrypted value via flutter_secure_storage
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
      return stored == pin;
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

  // ── Is any lock enabled ───────────────────────────────────────────────────
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

  static Future<void> updateLastActive() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_keyLastActive, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  static Future<bool> isLockRequired() async {
    if (!await isAnyLockEnabled()) return false;
    try {
      final p       = await SharedPreferences.getInstance();
      final last    = p.getInt(_keyLastActive) ?? 0;
      final timeout = await getLockTimeout();
      final elapsed = DateTime.now().millisecondsSinceEpoch - last;
      return elapsed > timeout * 60 * 1000;
    } catch (_) { return false; }
  }

  // ── Biometric auth ────────────────────────────────────────────────────────
  static Future<bool> authenticateBiometric({
    String reason = 'Authenticate to open Money Manager',
  }) async {
    if (kIsWeb) return false;
    if (!await isBiometricEnabled()) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth:           true,
          biometricOnly:        true, // PIN handled in-app separately
          useErrorDialogs:      true,
          sensitiveTransaction: false,
        ),
      );
    } on PlatformException { return false; }
    catch (_) { return false; }
  }
}