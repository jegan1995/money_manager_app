import 'package:flutter/material.dart';
import 'transfers_screen.dart';
import 'budget_management_screen.dart';
import 'recurring_transactions_screen.dart';
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

          const Divider(height: 32),

          // Section: Planning
          _buildSectionHeader('Planning'),
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

          const Divider(height: 32),

          // Section: Settings
          _buildSectionHeader('Settings'),
          _buildMenuItem(
            context,
            icon: Icons.settings,
            title: 'App Settings',
            subtitle: 'Preferences & configurations',
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
                applicationIcon: const Icon(Icons.account_balance_wallet, size: 48),
                children: [
                  const Text('A comprehensive money management app'),
                  const SizedBox(height: 8),
                  const Text('Built with Flutter & Firebase'),
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
}
