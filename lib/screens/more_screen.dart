import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/transaction_service.dart';
import '../services/export_service.dart';
import '../models/transaction_model.dart';
import 'transfers_screen.dart';
import 'budget_management_screen.dart';
import 'recurring_transactions_screen.dart';
import 'goals_screen.dart';
import 'filter_screen.dart';
import 'settings_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
      ),
      body: ListView(
        children: [
          // Section: Transactions
          _buildSectionHeader('Transactions'),
          _buildMenuItem(
            context,
            icon: Icons.swap_horiz,
            title: 'Transfers',
            subtitle: 'Move money between accounts',
            color: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TransfersScreen()),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.repeat,
            title: 'Recurring Transactions',
            subtitle: 'Auto-generate bills & income',
            color: Colors.purple,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const RecurringTransactionsScreen()),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.filter_list,
            title: 'Advanced Filter',
            subtitle: 'Filter by multiple criteria',
            color: Colors.indigo,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FilterScreen()),
              );
            },
          ),

          const Divider(height: 32),

          // Section: Planning
          _buildSectionHeader('Planning & Goals'),
          _buildMenuItem(
            context,
            icon: Icons.pie_chart,
            title: 'Budget Management',
            subtitle: 'Manage category budgets',
            color: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const BudgetManagementScreen()),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.emoji_events,
            title: 'Financial Goals',
            subtitle: 'Track your savings goals',
            color: Colors.amber,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GoalsScreen()),
              );
            },
          ),

          const Divider(height: 32),

          // Section: Data
          _buildSectionHeader('Data Management'),
          _buildMenuItem(
            context,
            icon: Icons.download,
            title: 'Export to CSV',
            subtitle: 'Download your transactions',
            color: Colors.green,
            onTap: () => _exportTransactions(context),
          ),

          const Divider(height: 32),

          // Section: Settings
          _buildSectionHeader('Settings'),
          _buildMenuItem(
            context,
            icon: Icons.settings,
            title: 'App Settings',
            subtitle: 'Theme, currency & preferences',
            color: Colors.grey,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),

          const Divider(height: 32),

          // Section: About
          _buildSectionHeader('About'),
          _buildMenuItem(
            context,
            icon: Icons.info_outline,
            title: 'About App',
            subtitle: 'Version 1.0.0',
            color: Colors.teal,
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Money Manager',
                applicationVersion: '1.0.0',
                applicationIcon:
                    const Icon(Icons.account_balance_wallet, size: 48),
                children: const [
                  Text('A comprehensive money management app'),
                  SizedBox(height: 8),
                  Text('Built with Flutter & Firebase'),
                  SizedBox(height: 8),
                  Text('Features: Budgets, Goals, Analytics & More'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Future<void> _exportTransactions(BuildContext context) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final TransactionService transactionService = TransactionService();
      final ExportService exportService = ExportService();

      // Get all transactions
      final snapshot = await transactionService.getTransactions().first;
      final transactions = snapshot.docs
          .map((doc) => TransactionModel.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .toList();

      // Export to CSV
      final filePath = await exportService.exportTransactionsToCSV(transactions);

      if (context.mounted) {
        Navigator.pop(context); // Close loading

        if (filePath != null) {
          // Show share dialog
          await exportService.shareCSV(filePath);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transactions exported successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
