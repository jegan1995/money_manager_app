import 'package:flutter/material.dart';
import 'goals_screen.dart';
import 'recurring_screen.dart';
import 'accounts_screen.dart';
import 'settings_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          _buildMenuSection('Finances', [
            _buildMenuItem(
              context,
              icon: Icons.flag,
              title: 'Goals',
              subtitle: 'Track your savings goals',
              color: Colors.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GoalsScreen()),
              ),
            ),
            _buildMenuItem(
              context,
              icon: Icons.replay,
              title: 'Recurring Transactions',
              subtitle: 'Manage recurring bills & income',
              color: Colors.purple,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RecurringScreen()),
              ),
            ),
            _buildMenuItem(
              context,
              icon: Icons.account_balance,
              title: 'Accounts',
              subtitle: 'Manage your accounts',
              color: Colors.teal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AccountsScreen()),
              ),
            ),
          ]),
          const Divider(),
          _buildMenuSection('Settings', [
            _buildMenuItem(
              context,
              icon: Icons.settings,
              title: 'Settings',
              subtitle: 'App preferences & data',
              color: Colors.grey,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildMenuSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
        ...items,
      ],
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
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
