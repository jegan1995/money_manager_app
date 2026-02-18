import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/auth_wrapper.dart';
import 'screens/accounts_screen.dart'; // ✅ ADD THIS LINE
import 'providers/theme_provider.dart';
import 'services/recurring_transaction_service.dart';
import 'services/recurring_transfer_service.dart';
import 'screens/recurring_transactions_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Money Manager',
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const AppInitializer(),
      debugShowCheckedModeBanner: false,
      // ✅ ADD THESE 3 LINES:
      routes: {
        '/accounts': (context) => const AccountsScreen(),
        '/recurring': (context) => RecurringTransactionsScreen(),
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
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Process recurring transactions
      final recurringTransactionService = RecurringTransactionService();
      final recurringTransferService = RecurringTransferService();

      await recurringTransactionService.checkAndExecuteRecurring();
      await recurringTransferService.processRecurringTransfers();

      setState(() {
        _initialized = true;
      });
    } catch (e) {
      setState(() {
        _error = true;
      });
      print('Initialization error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return const Scaffold(
        body: Center(
          child: Text('Error initializing app'),
        ),
      );
    }

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
