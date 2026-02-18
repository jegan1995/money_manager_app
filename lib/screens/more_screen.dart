import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/transaction_service.dart';
import '../services/export_service.dart';
import '../services/budget_alert_service.dart';
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
import 'alerts_screen.dart';
import '../services/recurring_transfer_service.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final alertService = BudgetAlertService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
      ),
      body: ListView(
        children: [
          // Budget Alerts (with notification badge)
          StreamBuilder<int>(
            stream: alertService.getUnreadCount(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;

              return _buildMenuItem(
                context,
                icon: Icons.notifications,
                title: 'Budget Alerts',
                subtitle: unreadCount > 0
                    ? '$unreadCount new alert${unreadCount > 1 ? 's' : ''}'
                    : 'View budget notifications',
                color: unreadCount > 0 ? Colors.red : Colors.blue,
                badge: unreadCount > 0 ? unreadCount : null,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AlertsScreen()),
                ),
              );
            },
          ),
          const Divider(),

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

          // ✅ FIXED: Added missing closing parenthesis
          _buildMenuItem(
            context,
            icon: Icons.repeat,
            title: 'Recurring Transactions',
            subtitle: 'Automatic transactions',
            color: Colors.purple,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const RecurringTransactionsScreen()),
            ),
          ),
          const Divider(),

          _buildMenuItem(
            context,
            icon: Icons.insights,
            title: 'Transfer Analytics',
            subtitle: 'Analyze transfer patterns',
            color: Colors.purple,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const TransferAnalyticsScreen()),
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
          const Divider(),

          _buildMenuItem(
            context,
            icon: Icons.pie_chart,
            title: 'Budget Management',
            subtitle: 'Set and track budgets',
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
            icon: Icons.flag,
            title: 'Financial Goals',
            subtitle: 'Track savings goals',
            color: Colors.green,
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
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
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
    int? badge,
  }) {
    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: color),
          if (badge != null && badge > 0)
            Positioned(
              right: -8,
              top: -8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Text(
                  badge > 99 ? '99+' : badge.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
