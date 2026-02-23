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

  static const _pinKey = 'app_lock_pin';
  static const _enabledKey = 'app_lock_enabled';
  static const _biometricKey = 'app_lock_biometric';
  static const _failedAttemptsKey = 'app_lock_failed_attempts';

  // ── In-memory unlock state (reset on app kill) ───────────────────────────────
  bool _isUnlocked = false;
  DateTime? _unlockedAt;
  static const _lockAfterMinutes = 5; // auto-lock after 5 min background

  bool get isUnlocked => _isUnlocked;

  void markUnlocked() {
    _isUnlocked = true;
    _unlockedAt = DateTime.now();
  }

  void lock() {
    _isUnlocked = false;
    _unlockedAt = null;
  }

  /// Call when app resumes from background
  bool shouldLock() {
    if (!_isUnlocked) return true;
    if (_unlockedAt == null) return true;
    final elapsed = DateTime.now().difference(_unlockedAt!);
    return elapsed.inMinutes >= _lockAfterMinutes;
  }

  // ── PIN Management ───────────────────────────────────────────────────────────
  Future<bool> isLockEnabled() async {
    if (kIsWeb) return false;
    final val = await _storage.read(key: _enabledKey);
    return val == 'true';
  }

  Future<void> setLockEnabled(bool enabled) async {
    await _storage.write(key: _enabledKey, value: enabled.toString());
  }

  Future<bool> hasPin() async {
    if (kIsWeb) return false;
    final pin = await _storage.read(key: _pinKey);
    return pin != null && pin.length == 4;
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
    final correct = saved == input;
    if (correct) {
      await _resetFailedAttempts();
      markUnlocked();
    } else {
      await _incrementFailedAttempts();
    }
    return correct;
  }

  // ── Failed attempts ──────────────────────────────────────────────────────────
  Future<int> getFailedAttempts() async {
    final val = await _storage.read(key: _failedAttemptsKey);
    return int.tryParse(val ?? '0') ?? 0;
  }

  Future<void> _incrementFailedAttempts() async {
    final current = await getFailedAttempts();
    await _storage.write(
        key: _failedAttemptsKey, value: (current + 1).toString());
  }

  Future<void> _resetFailedAttempts() async {
    await _storage.write(key: _failedAttemptsKey, value: '0');
  }

  // ── Biometric ────────────────────────────────────────────────────────────────
  Future<bool> isBiometricEnabled() async {
    if (kIsWeb) return false;
    final val = await _storage.read(key: _biometricKey);
    return val == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricKey, value: enabled.toString());
  }

  Future<bool> isBiometricAvailable() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  Future<bool> authenticateWithBiometric() async {
    if (kIsWeb) return false;
    try {
      final result = await _localAuth.authenticate(
        localizedReason: 'Unlock Money Manager',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      if (result) markUnlocked();
      return result;
    } catch (_) {
      return false;
    }
  }
}