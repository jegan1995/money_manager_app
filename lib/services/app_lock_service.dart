import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AppLockService {
  static final AppLockService _instance = AppLockService._internal();
  factory AppLockService() => _instance;
  AppLockService._internal();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _localAuth = LocalAuthentication();

  static const _pinKey            = 'app_lock_pin';
  static const _enabledKey        = 'app_lock_enabled';
  static const _biometricKey      = 'app_lock_biometric';
  static const _failedAttemptsKey = 'app_lock_failed_attempts';

  // ── Unlock state ─────────────────────────────────────────────────────────
  bool _isUnlocked = false;
  DateTime? _unlockedAt;
  static const _lockAfterMinutes = 5;

  bool get isUnlocked => _isUnlocked;

  void markUnlocked() {
    _isUnlocked = true;
    _unlockedAt = DateTime.now();
  }

  void lock() {
    _isUnlocked = false;
    _unlockedAt = null;
  }

  bool shouldLock() {
    if (!_isUnlocked) return true;
    if (_unlockedAt == null) return true;
    return DateTime.now().difference(_unlockedAt!).inMinutes >= _lockAfterMinutes;
  }

  // ── PIN ──────────────────────────────────────────────────────────────────
  Future<bool> isLockEnabled() async {
    if (kIsWeb) return false;
    return await _storage.read(key: _enabledKey) == 'true';
  }

  Future<void> setLockEnabled(bool v) async =>
      _storage.write(key: _enabledKey, value: v.toString());

  Future<bool> hasPin() async {
    if (kIsWeb) return false;
    final p = await _storage.read(key: _pinKey);
    return p != null && p.length == 4;
  }

  Future<void> savePin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
    await setLockEnabled(true);
    await _resetFailedAttempts();
  }

  Future<void> deletePin() async {
    await _storage.delete(key: _pinKey);
    await _storage.delete(key: _enabledKey);
    await _storage.delete(key: _failedAttemptsKey);
  }

  Future<bool> verifyPin(String input) async {
    final saved = await _storage.read(key: _pinKey);
    final ok = saved == input;
    if (ok) {
      await _resetFailedAttempts();
      markUnlocked();
    } else {
      await _incrementFailedAttempts();
    }
    return ok;
  }

  Future<int> getFailedAttempts() async {
    final v = await _storage.read(key: _failedAttemptsKey);
    return int.tryParse(v ?? '0') ?? 0;
  }

  Future<void> _incrementFailedAttempts() async {
    final c = await getFailedAttempts();
    await _storage.write(key: _failedAttemptsKey, value: '${c + 1}');
  }

  Future<void> _resetFailedAttempts() async =>
      _storage.write(key: _failedAttemptsKey, value: '0');

  // ── Biometric ────────────────────────────────────────────────────────────
  Future<bool> isBiometricEnabled() async {
    if (kIsWeb) return false;
    return await _storage.read(key: _biometricKey) == 'true';
  }

  Future<void> setBiometricEnabled(bool v) async =>
      _storage.write(key: _biometricKey, value: v.toString());

  /// Simple check — just ask the OS if device supports biometrics
  Future<bool> isBiometricAvailable() async {
    if (kIsWeb) return false;
    try {
      // isDeviceSupported = has biometric hardware + enrolled credentials
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      debugPrint('isBiometricAvailable error: $e');
      return false;
    }
  }

  /// Authenticate — returns result with helpful error messages
  Future<BiometricResult> authenticateWithBiometric() async {
    if (kIsWeb) {
      return BiometricResult(success: false, error: 'Not supported on web');
    }

    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) {
        return BiometricResult(
          success: false,
          error: 'This device does not support biometric authentication.',
        );
      }

      // Go straight to authenticate — don't gate on canCheckBiometrics
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Use fingerprint to unlock Money Manager',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,   // allows device PIN as fallback
          sensitiveTransaction: false,
        ),
      );

      if (authenticated) {
        markUnlocked();
        return BiometricResult(success: true);
      } else {
        // User cancelled or dismissed
        return BiometricResult(success: false, error: null);
      }
    } catch (e) {
      debugPrint('Biometric auth exception: $e');
      final msg = _friendlyError(e.toString());
      return BiometricResult(success: false, error: msg);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('NotEnrolled') || raw.contains('not_enrolled')) {
      return 'No fingerprint enrolled. Go to phone Settings → Security → Fingerprint.';
    }
    if (raw.contains('PermanentlyLockedOut') || raw.contains('LockedOut')) {
      return 'Biometric locked out. Use device PIN to unlock it first.';
    }
    if (raw.contains('NotAvailable') || raw.contains('HardwareUnavailable')) {
      return 'Biometric hardware not available right now. Try again.';
    }
    if (raw.contains('PasscodeNotSet')) {
      return 'Set a device screen lock first (Settings → Security).';
    }
    return 'Biometric failed. Please use PIN instead.';
  }
}

class BiometricResult {
  final bool success;
  final String? error; // null = cancelled silently (no toast needed)
  const BiometricResult({required this.success, this.error});
}