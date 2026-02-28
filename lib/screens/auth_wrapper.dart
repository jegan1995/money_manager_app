// lib/screens/auth_wrapper.dart
// App entry point — layers in order:
// 1. Force update check  (blocks if min_version not met)
// 2. Onboarding check    (shows slides on first install only)
// 3. Auth state          (login or main navigation)
// 4. Soft update banner  (dismissable, shown to logged-in users)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/force_update_service.dart';
import '../services/notification_service.dart';
import '../services/onboarding_service.dart';
import 'login_screen.dart';
import 'force_update_screen.dart';
import 'onboarding_screen.dart';
import 'main_navigation.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // null = still checking, true = show onboarding, false = skip
  bool? _showOnboarding;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Run in parallel — notifications + onboarding check
    final results = await Future.wait([
      _initNotifications(),
      OnboardingService.isComplete(),
    ]);

    final onboardingDone = results[1] as bool;

    if (mounted) {
      setState(() => _showOnboarding = !onboardingDone);
    }
  }

  Future<bool> _initNotifications() async {
    try { await NotificationService.initialize(); } catch (_) {}
    try { await NotificationService.subscribeToUpdates(); } catch (_) {}
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // ── Layer 1: Force update ────────────────────────────────────────────────
    return StreamBuilder<AppVersionInfo?>(
      stream: ForceUpdateService.watchUpdateStatus(),
      builder: (ctx, updateSnap) {
        final info = updateSnap.data;

        if (info != null && info.needsForceUpdate) {
          return ForceUpdateScreen(info: info);
        }

        // ── Layer 2: Onboarding ──────────────────────────────────────────────
        // Still loading prefs → show splash
        if (_showOnboarding == null) {
          return const _SplashScreen();
        }

        // First install → onboarding
        if (_showOnboarding == true) {
          return const OnboardingScreen();
        }

        // ── Layer 3: Auth state ──────────────────────────────────────────────
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (ctx, authSnap) {
            if (authSnap.connectionState == ConnectionState.waiting) {
              return const _SplashScreen();
            }

            final Widget body = authSnap.hasData
                ? const MainNavigation()
                : const LoginScreen();

            // ── Layer 4: Soft update banner ────────────────────────────────
            if (info != null && info.needsSoftUpdate && authSnap.hasData) {
              return _SoftUpdateWrapper(info: info, child: body);
            }

            return body;
          },
        );
      },
    );
  }
}

// ── Branded splash ───────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center,
              children: [
            // Logo
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withOpacity(0.3), width: 2),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 30, offset: const Offset(0, 10))],
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: 42),
            ),
            const SizedBox(height: 20),
            const Text('Money Manager',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5)),
            const SizedBox(height: 6),
            Text('Smart Finance Tracker',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13)),
            const SizedBox(height: 40),
            const SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Soft update banner (dismissable) ─────────────────────────────────────────
class _SoftUpdateWrapper extends StatefulWidget {
  final AppVersionInfo info;
  final Widget child;
  const _SoftUpdateWrapper({required this.info, required this.child});
  @override
  State<_SoftUpdateWrapper> createState() => _SoftUpdateWrapperState();
}

class _SoftUpdateWrapperState extends State<_SoftUpdateWrapper> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return widget.child;

    return Stack(children: [
      widget.child,
      Positioned(
        left: 12, right: 12, bottom: 88,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(14),
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                  color: const Color(0xFF667eea).withOpacity(0.4),
                  blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Row(children: [
              const Icon(Icons.system_update_alt_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Update Available',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  Text('Version ${widget.info.minVersion} is ready',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 11)),
                ],
              )),
              TextButton(
                onPressed: () async {
                  try {
                    final uri = Uri.parse(widget.info.updateUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  } catch (_) {}
                },
                style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6)),
                child: const Text('Update',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() => _dismissed = true),
                child: Icon(Icons.close,
                    color: Colors.white.withOpacity(0.7), size: 18),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}