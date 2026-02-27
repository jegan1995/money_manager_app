// lib/screens/auth_wrapper.dart
// Entry point after Firebase init:
// 1. Checks force update (blocks if needed)
// 2. Listens to auth state → routes to Login or Main

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/force_update_service.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';
import 'force_update_screen.dart';
import 'main_navigation.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Init notifications silently — never block app load
    Future.microtask(() async {
      try { await NotificationService.initialize(); } catch (_) {}
      try { await NotificationService.subscribeToUpdates(); } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    // ── Layer 1: Force update check ──────────────────────────────────────────
    return StreamBuilder<AppVersionInfo?>(
      stream: ForceUpdateService.watchUpdateStatus(),
      builder: (ctx, updateSnap) {
        final info = updateSnap.data;

        // If force update needed → show blocking screen (ignores auth state)
        if (info != null && info.needsForceUpdate) {
          return ForceUpdateScreen(info: info);
        }

        // ── Layer 2: Auth state ────────────────────────────────────────────
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (ctx, authSnap) {
            if (authSnap.connectionState == ConnectionState.waiting) {
              return const _SplashScreen();
            }

            final Widget body = authSnap.hasData
                ? const MainNavigation()
                : const LoginScreen();

            // Soft update banner on top of main content (dismissable)
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

// ── Splash screen shown while checking auth ──────────────────────────────────
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
          child: Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center,
                children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.3), width: 2),
                ),
                child: const Icon(Icons.account_balance_wallet,
                    color: Colors.white, size: 38),
              ),
              const SizedBox(height: 20),
              const Text('Money Manager',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            ]),
          ),
        ),
      );
}

// ── Soft update banner wrapper (dismissable) ─────────────────────────────────
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
      // Update banner at bottom
      Positioned(
        left: 12, right: 12, bottom: 90,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(14),
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              const Icon(Icons.system_update_alt,
                  color: Colors.white, size: 20),
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
                    // Use url_launcher to open store
                  } catch (_) {}
                },
                style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
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
                    color: Colors.white.withOpacity(0.7), size: 16),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}