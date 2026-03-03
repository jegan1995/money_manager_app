// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/auth_wrapper.dart';
import 'screens/accounts_screen.dart';
import 'providers/theme_provider.dart';
import 'services/theme_service.dart';
import 'services/recurring_transaction_service.dart';
import 'services/recurring_transfer_service.dart';
import 'screens/recurring_transactions_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Load theme — fast, local SharedPreferences only
  final themeService = ThemeService();
  await themeService.loadSettings();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: MyApp(themeService: themeService),
    ),
  );
}

class MyApp extends StatelessWidget {
  final ThemeService themeService;
  const MyApp({super.key, required this.themeService});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeService,
      builder: (context, child) {
        return MaterialApp(
          title: 'Money Manager',
          debugShowCheckedModeBanner: false,
          theme: themeService.lightTheme,
          darkTheme: themeService.darkTheme,
          themeMode:
              themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const AppInitializer(),
          routes: {
            '/accounts': (context) => const AccountsScreen(),
            '/recurring': (context) => RecurringTransactionsScreen(),
          },
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});
  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer>
    with SingleTickerProviderStateMixin {
  bool _ready = false;
  late AnimationController _anim;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _anim.forward();
    _init();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // ── KEY FIX ───────────────────────────────────────────────────────────
    // The old code awaited checkAndExecuteRecurring() BEFORE auth — causing
    // the app to hang forever because Firestore needs an authenticated user.
    //
    // Fix: wait for auth state (max 3s), then run recurring checks in the
    // BACKGROUND after the app is already visible. Never block startup.
    // ─────────────────────────────────────────────────────────────────────

    // Wait for Firebase Auth to restore session from browser storage
    // Timeout after 3 seconds so we never hang
    await Future.any([
      FirebaseAuth.instance.authStateChanges().first,
      Future.delayed(const Duration(seconds: 3)),
    ]);

    // Start recurring checks in background if user is logged in
    if (FirebaseAuth.instance.currentUser != null) {
      _runRecurringInBackground();
    }

    // Mark ready — show the app immediately
    if (mounted) setState(() => _ready = true);
  }

  // Fire-and-forget — NEVER blocks the UI thread
  void _runRecurringInBackground() {
    Future.microtask(() async {
      try {
        await RecurringTransactionService()
            .checkAndExecuteRecurring()
            .timeout(const Duration(seconds: 10));
      } catch (_) {}
      try {
        await RecurringTransferService()
            .processRecurringTransfers()
            .timeout(const Duration(seconds: 10));
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    // Already initialised — go straight to auth screen
    if (_ready) return const AuthWrapper();

    // Beautiful splash while waiting for auth restore
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo card
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667eea).withOpacity(0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('💰', style: TextStyle(fontSize: 42)),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Money Manager',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your financial command centre',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: const Color(0xFF667eea).withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Starting up...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}