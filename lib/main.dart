import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // ── FIX: Ad blocker bypass for web ─────────────────────────────────────────
  // Some ad blockers block Firestore's WebChannel (persistent HTTP connection).
  // experimentalAutoDetectLongPolling makes Firestore automatically fall back
  // to regular HTTP polling when WebChannel is blocked — fixes ERR_BLOCKED_BY_CLIENT.
  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
      // Force long-polling — bypasses ad blockers blocking WebChannel
      // This is safe: slightly more latency but 100% reliable
      webExperimentalForceLongPolling: true,
    );
  }

  // Initialize theme service
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
          themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const AppInitializer(),
          routes: {
            '/accounts':  (context) => const AccountsScreen(),
            '/recurring': (context) => RecurringTransactionsScreen(),
          },
        );
      },
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});
  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _initialized = false;
  bool _error       = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final recurringTxnSvc      = RecurringTransactionService();
      final recurringTransferSvc = RecurringTransferService();

      await recurringTxnSvc.checkAndExecuteRecurring();
      await recurringTransferSvc.processRecurringTransfers();

      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (mounted) setState(() => _error = true);
      debugPrint('Initialization error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Scaffold(
        body: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('Could not connect.',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Check your internet or disable\nyour ad blocker for this site.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() {
                _error = false;
                _initialized = false;
                _initializeApp();
              }),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        )),
      );
    }

    if (!_initialized) {
      return Scaffold(
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
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.3), width: 2),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: Colors.white, size: 38),
              ),
              const SizedBox(height: 20),
              const Text('Money Manager',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Setting things up...',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 13)),
              const SizedBox(height: 36),
              const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            ],
          )),
        ),
      );
    }

    return const AuthWrapper();
  }
}