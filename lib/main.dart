import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
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
            '/accounts':   (context) => const AccountsScreen(),
            '/recurring':  (context) => RecurringTransactionsScreen(),
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

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // ── Run recurring checks silently ──────────────────────────────────
    // These run in background ONLY when a user is already logged in.
    // Any failure (permission denied, network error, not logged in) is
    // caught and ignored — it must NEVER block the app from loading.
    _runRecurringChecks();

    // App is ready — show login or home immediately
    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  Future<void> _runRecurringChecks() async {
    try {
      final recurringTxnSvc = RecurringTransactionService();
      final recurringTrfSvc = RecurringTransferService();
      await recurringTxnSvc.checkAndExecuteRecurring();
      await recurringTrfSvc.processRecurringTransfers();
    } catch (_) {
      // Silently ignore — user may not be logged in yet, or network issue.
      // Recurring checks will run again next time user opens the app.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading Money Manager...',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return const AuthWrapper();
  }
}