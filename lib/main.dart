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
        // ThemeService is the single source of truth for dark mode
        ChangeNotifierProvider<ThemeService>.value(value: themeService),
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
    // Consumer<ThemeService> rebuilds MaterialApp when toggleDarkMode() is called
    return Consumer<ThemeService>(
      builder: (context, theme, _) {
        return MaterialApp(
          title: 'Money Manager',
          debugShowCheckedModeBanner: false,
          theme: theme.lightTheme,
          darkTheme: theme.darkTheme,
          themeMode: theme.isDarkMode ? ThemeMode.dark : ThemeMode.light,
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
    _init();
  }

  Future<void> _init() async {
    try {
      await RecurringTransactionService().checkAndExecuteRecurring();
      await RecurringTransferService().processRecurringTransfers();
    } catch (e) {
      debugPrint('Recurring init error: $e');
    }
    if (mounted) setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return const AuthWrapper();
  }
}