import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/app_lock_service.dart';
import 'app_lock_screen.dart';
import 'login_screen.dart';
import 'main_navigation.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper>
    with WidgetsBindingObserver {
  final _lockService = AppLockService();
  bool _checkingLock = true;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-lock when app comes back from background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLock();
    } else if (state == AppLifecycleState.paused) {
      // Record when app went to background
    }
  }

  Future<void> _checkLock() async {
    final lockEnabled = await _lockService.isLockEnabled();
    if (!lockEnabled) {
      setState(() {
        _locked = false;
        _checkingLock = false;
      });
      return;
    }

    final shouldLock = _lockService.shouldLock();
    setState(() {
      _locked = shouldLock;
      _checkingLock = false;
    });
  }

  void _onUnlocked() {
    _lockService.markUnlocked();
    setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingLock) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Not logged in → show login
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // Logged in but locked → show lock screen
        if (_locked) {
          return AppLockScreen(onUnlocked: _onUnlocked);
        }

        // All good → main app
        return const MainNavigation();
      },
    );
  }
}