import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/firestore_service.dart';
import '../services/export_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final firestoreService = FirestoreService();
    final exportService = ExportService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 10),
          
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
            title: const Text('Export Transactions'),
            subtitle: const Text('Download as CSV file'),
            onTap: () async {
              try {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
                
                final transactions = await firestoreService.getTransactions().first;
                final path = await exportService.exportToCSV(transactions);
                
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Exported to: $path'),
                    duration: const Duration(seconds: 5),
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Export failed: $e')),
                );
              }
            },
          ),
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
