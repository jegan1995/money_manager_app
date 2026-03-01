// lib/main.dart
// FIX: Recurring check now runs in background — never blocks app startup.
// This was causing Android first-install login to hang on splash screen.
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

  // Web: force long-polling to bypass ad blockers blocking WebChannel
  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
      webExperimentalForceLongPolling: true,
    );
  }

  final themeService = ThemeService();
  await themeService.loadSettings();

  // ── Recurring checks run in background — NEVER block app startup ──────────
  // This was the cause of Android first-install login hanging on splash screen.
  // If the user isn't logged in yet, Firestore queries silently return nothing.
  Future.microtask(() async {
    try {
      await RecurringTransactionService().checkAndExecuteRecurring();
      await RecurringTransferService().processRecurringTransfers();
    } catch (_) {
      // Silently ignore — will retry on next launch
    }
  });

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
          // ── FIX: AuthWrapper is directly the home — no AppInitializer wrapper ──
          // AppInitializer was creating a Navigator stack conflict:
          // Onboarding → Navigator.pushReplacement(LoginScreen) puts LoginScreen
          // ON TOP of AuthWrapper. After login, AuthWrapper rebuilds but LoginScreen
          // stays on top. On Android restart there's no push so it works.
          home: const AuthWrapper(),
          routes: {
            '/accounts':  (context) => const AccountsScreen(),
            '/recurring': (context) => RecurringTransactionsScreen(),
          },
        );
      },
    );
  }
}