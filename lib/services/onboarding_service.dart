// lib/services/onboarding_service.dart
// Tracks whether the user has completed onboarding.
// Uses SharedPreferences — persists across app restarts.

import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const _key = 'onboarding_complete';

  /// Returns true if user has already seen onboarding
  static Future<bool> isComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Call this when user taps "Get Started" at end of onboarding
  static Future<void> markComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {}
  }

  /// Reset onboarding — useful for testing or when user logs out
  static Future<void> reset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}