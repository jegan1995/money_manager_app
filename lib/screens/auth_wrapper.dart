import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_service.dart';
import 'login_screen.dart';
import 'main_navigation.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {

        if (authSnap.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        // Not logged in → show login
        if (!authSnap.hasData || authSnap.data == null) {
          return const LoginScreen();
        }

        final user = authSnap.data!;

        // Admin always gets in without status check
        if (user.uid == kAdminUID) {
          return const MainNavigation();
        }

        // ── Real-time suspension watch ─────────────────────────────────
        // Watches the user's Firestore doc. If status becomes 'suspended',
        // forces immediate sign-out across ALL screens instantly.
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, docSnap) {

            // While loading the user doc — show the app
            if (!docSnap.hasData) {
              return const MainNavigation();
            }

            // If doc doesn't exist yet (new user) — allow in
            if (!docSnap.data!.exists) {
              return const MainNavigation();
            }

            final data   = docSnap.data!.data() as Map<String, dynamic>?;
            final status = data?['status'] ?? 'active';

            // SUSPENDED → force sign out + show suspended message
            if (status == 'suspended') {
              // Sign out asynchronously
              Future.microtask(() async {
                await FirebaseAuth.instance.signOut();
              });

              return const _SuspendedScreen();
            }

            // Active → normal app
            return const MainNavigation();
          },
        );
      },
    );
  }
}

// ── Loading splash ─────────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF667eea),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.account_balance_wallet,
                  color: Colors.white, size: 44),
            ),
            const SizedBox(height: 20),
            const Text('Money Manager',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white70)),
          ],
        ),
      ),
    );
  }
}

// ── Suspended screen ───────────────────────────────────────────────────────────
class _SuspendedScreen extends StatelessWidget {
  const _SuspendedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.block,
                    color: Colors.red, size: 48),
              ),
              const SizedBox(height: 24),
              const Text('Account Suspended',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Color(0xFF1A1A2E))),
              const SizedBox(height: 12),
              Text(
                'Your account has been suspended by the administrator.\n'
                'Please contact support for assistance.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                    height: 1.5),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  side: const BorderSide(color: Colors.red),
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}