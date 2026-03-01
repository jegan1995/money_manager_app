import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;
import '../providers/theme_provider.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';
import '../services/export_service.dart';
import '../services/auth_service.dart';
import 'app_lock_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _performLogout(BuildContext context) async {
    final authService = AuthService();

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      await authService.signOut();

      if (!context.mounted) return;

      if (kIsWeb) {
        // Web: full page reload clears state and navigator instantly
        html.window.location.reload();
      } else {
        // ── ANDROID FIX ──────────────────────────────────────────────────────
        // AuthWrapper's StreamBuilder detects signout and rebuilds with
        // LoginScreen — but Settings/other screens are pushed ON TOP via
        // Navigator.push, so they block LoginScreen from showing.
        // popUntil(first) clears the entire stack → AuthWrapper's LoginScreen
        // is now visible and the auth stream fires into it correctly.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!context.mounted) return;
      if (kIsWeb) {
        html.window.location.reload();
      } else {
        // Close loading dialog if still open
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Logout failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final transactionService = TransactionService();
    final accountService = AccountService();
    final exportService = ExportService();
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 10),

          // User Info Section
          _buildSectionHeader('Account'),
          FutureBuilder<String?>(
            future: authService.getUserName(),
            builder: (context, snapshot) {
              final name =
                  snapshot.data ?? authService.currentUser?.email ?? 'User';
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(name),
                subtitle: Text(authService.currentUser?.email ?? ''),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Logout',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await _performLogout(context);
              }
            },
          ),
          const Divider(),

          _buildSectionHeader('Appearance'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Enable dark theme'),
            secondary: Icon(
              themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
            ),
            value: themeProvider.isDarkMode,
            onChanged: (value) {
              themeProvider.toggleTheme();
            },
          ),
          const Divider(),

          _buildSectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export to CSV'),
            subtitle: const Text('Download transactions as CSV'),
            onTap: () async {
              try {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                final transactions =
                    await transactionService.getTransactionsList();
                final accounts = await accountService.getAccountsList().first;

                final path = await exportService.exportTransactionsToCSV(
                  transactions,
                  accounts,
                  includeTransfers: true,
                  includeIncome: true,
                  includeExpense: true,
                );

                Navigator.pop(context);

                if (path != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Exported successfully: $path'),
                      duration: const Duration(seconds: 5),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Export failed: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.table_chart),
            title: const Text('Export to Excel'),
            subtitle: const Text('Download detailed Excel report'),
            onTap: () async {
              try {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                final transactions =
                    await transactionService.getTransactionsList();
                final accounts = await accountService.getAccountsList().first;

                final path = await exportService.exportTransactionsToExcel(
                  transactions,
                  accounts,
                  includeTransfers: true,
                  includeIncome: true,
                  includeExpense: true,
                );

                Navigator.pop(context);

                if (path != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Exported successfully: $path'),
                      duration: const Duration(seconds: 5),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Export failed: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
          const Divider(),

          _buildSectionHeader('Security'),
          const BiometricSettingsTile(),
          const Divider(),

          _buildSectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('Version'),
            subtitle: Text('1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.account_balance_wallet),
            title: Text('Money Manager'),
            subtitle: Text('Track your income and expenses'),
          ),
          const ListTile(
            leading: Icon(Icons.person),
            title: Text('Developer'),
            subtitle: Text('Built by Jegan'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }
}