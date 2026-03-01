// lib/screens/auth_wrapper.dart
// ROOT of the app — pure setState routing, no Navigator stack conflicts.
//
// KEY FIX (Android loading forever + login not navigating):
//   Notifications are fired with unawaited() — they NEVER block _init().
//   _init() now only awaits OnboardingService.isComplete() — takes <5ms.
//   This means _onboardingDone flips immediately, inner auth StreamBuilder
//   mounts right away, and auth state changes are always detected.
//
// Flow:
//  App open → _init() (instant) → shows correct screen immediately
//  Login → authStateChanges() fires → MainNavigation shows ✅

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/force_update_service.dart';
import '../services/notification_service.dart';
import '../services/onboarding_service.dart';
import 'login_screen.dart';
import 'force_update_screen.dart';
import 'onboarding_screen.dart';
import 'main_navigation.dart';
import 'app_lock_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool? _onboardingDone; // null = checking, true/false = done

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // ── Only await the one fast thing we NEED before showing UI ──────────────
    // OnboardingService reads SharedPreferences — takes <5ms on all platforms.
    final done = await OnboardingService.isComplete();
    if (mounted) setState(() => _onboardingDone = done);

    // ── Notifications fire in background — NEVER block app startup ────────────
    // NotificationService.initialize() calls requestPermission() on Android
    // which shows a system dialog and WAITS for user to respond.
    // Awaiting this kept _onboardingDone = null forever → splash stuck.
    // Awaiting this also prevented the auth StreamBuilder from mounting,
    // so login events were silently ignored → signin appeared broken.
    _initNotificationsBackground();
  }

  void _initNotificationsBackground() {
    // Fire and forget — errors silently ignored
    Future.microtask(() async {
      try { await NotificationService.initialize(); } catch (_) {}
      try { await NotificationService.subscribeToUpdates(); } catch (_) {}
    });
  }

  void _onOnboardingComplete() {
    setState(() => _onboardingDone = true);
  }

  @override
  Widget build(BuildContext context) {
    // ── Layer 1: Force update (wraps everything, checks Firestore) ───────────
    return StreamBuilder<AppVersionInfo?>(
      stream: ForceUpdateService.watchUpdateStatus(),
      builder: (ctx, updateSnap) {
        final info = updateSnap.data;

        // Force update blocks the app entirely
        if (info != null && info.needsForceUpdate) {
          return ForceUpdateScreen(info: info);
        }

        // ── Layer 2: Loading onboarding pref ─────────────────────────────────
        // This is now near-instant (SharedPreferences read only)
        if (_onboardingDone == null) return const _SplashScreen();

        // ── Layer 3: Onboarding — first install only ──────────────────────────
        if (_onboardingDone == false) {
          return OnboardingScreen(onComplete: _onOnboardingComplete);
        }

        // ── Layer 4: Auth state ───────────────────────────────────────────────
        // This StreamBuilder is now mounted immediately after _init() completes.
        // So login events from LoginScreen are always caught and reflected here.
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (ctx, authSnap) {
            // Brief Firebase auth initialization — show splash
            if (authSnap.connectionState == ConnectionState.waiting) {
              return const _SplashScreen();
            }

            // Not logged in
            if (!authSnap.hasData) return const LoginScreen();

            // Logged in → wrap with app lock → main app
            final Widget body = AppLockScreen(child: const MainNavigation());

            // Optional soft update banner
            if (info != null && info.needsSoftUpdate) {
              return _SoftUpdateWrapper(info: info, child: body);
            }

            return body;
          },
        );
      },
    );
  }
}

// ── Splash ────────────────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withOpacity(0.3), width: 2),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: Colors.white, size: 42),
          ),
          const SizedBox(height: 20),
          const Text('Money Manager',
              style: TextStyle(
                  color: Colors.white, fontSize: 24,
                  fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text('Smart Finance Tracker',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7), fontSize: 13)),
          const SizedBox(height: 40),
          const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2)),
        ],
      )),
    ),
  );
}

// ── Soft update banner ────────────────────────────────────────────────────────
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
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Version ${widget.info.minVersion} is ready',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8), fontSize: 11)),
                ],
              )),
              TextButton(
                onPressed: () async {
                  try {
                    final uri = Uri.parse(widget.info.updateUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 12)),
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