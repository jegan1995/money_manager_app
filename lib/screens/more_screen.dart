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
import 'budget_screen.dart';
import 'statistics_screen.dart';
import 'calendar_screen.dart';
import 'enhanced_reports_screen.dart';
import 'export_screen.dart';
import 'transfer_analytics_screen.dart';
import '../services/recurring_transfer_service.dart';

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
          _buildMenuItem(
            context,
            icon: Icons.swap_horiz,
            title: 'Transfers',
            subtitle: 'Transfer between accounts',
            color: Colors.blue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TransfersScreen()),
            ),
          ),
          _buildMenuItem(
            context,
            icon: Icons.insights,
            title: 'Transfer Analytics',
            subtitle: 'Analyze transfer patterns',
            color: Colors.purple,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TransferAnalyticsScreen()),
            ),
          ),
          _buildMenuItem(
            context,
            icon: Icons.download,
            title: 'Export & Backup',
            subtitle: 'Download transaction history',
            color: Colors.orange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ExportScreen()),
            ),
          ),
          // _buildMenuItem(
          //   context,
          //   icon: Icons.swap_horiz,
          //   title: 'Transfers',
          //   subtitle: 'Move money between accounts',
          //   color: Colors.blue,
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //           builder: (context) => const BudgetManagementScreen()),
          //     );
          //   },
          // ),
          const Divider(),
          _buildMenuItem(
            context,
            icon: Icons.pie_chart,
            title: 'Budget',
            subtitle: 'Manage your budgets',
            color: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GoalsScreen()),
              );
            },
          ),
          const Divider(),
          _buildMenuItem(
            context,
            icon: Icons.analytics,
            title: 'Statistics',
            subtitle: 'Detailed analytics & insights',
            color: Colors.teal,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const StatisticsScreen()),
              );
            },
          ),
          const Divider(),
          // ✅ NEW: Calendar menu item
          _buildMenuItem(
            context,
            icon: Icons.calendar_month,
            title: 'Calendar',
            subtitle: 'View transactions by date',
            color: Colors.indigo,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CalendarScreen()),
              );
            },
          ),
          const Divider(),
          _buildMenuItem(
            context,
            icon: Icons.settings,
            title: 'Settings',
            subtitle: 'App preferences',
            color: Colors.grey,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
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
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}