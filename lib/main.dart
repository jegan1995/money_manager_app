import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/main_navigation.dart';
import 'screens/login_screen.dart';
import 'providers/theme_provider.dart';
import 'services/recurring_service.dart';
import 'services/auth_service.dart';
import 'services/budget_alert_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
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
      home: const FirebaseInitializer(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class FirebaseInitializer extends StatefulWidget {
  const FirebaseInitializer({super.key});

  @override
  State<FirebaseInitializer> createState() => _FirebaseInitializerState();
}

class _FirebaseInitializerState extends State<FirebaseInitializer> {
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    initializeApp();
  }

  Future<void> initializeApp() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      setState(() {
        _initialized = true;
      });
    } catch (e) {
      setState(() {
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return const Scaffold(
        body: Center(
          child: Text('Error initializing Firebase'),
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

    // Once Firebase is initialized, show auth-aware UI
    return const AuthWrapper();
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // User is logged in
        if (snapshot.hasData) {
          return const AppInitializer();
        }

        // User is not logged in
        return const LoginScreen();
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
  bool _servicesInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Generate recurring transactions
      final recurringService = RecurringService();
      await recurringService.generateDueTransactions();
      
      // Check budgets and generate alerts
      final budgetAlertService = BudgetAlertService();
      await budgetAlertService.checkBudgets();
      await budgetAlertService.cleanupOldAlerts();
      
      setState(() {
        _servicesInitialized = true;
      });
    } catch (e) {
      // If services fail, still show the app
      setState(() {
        _servicesInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_servicesInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Setting up your account...',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return const MainNavigation();
  }
}