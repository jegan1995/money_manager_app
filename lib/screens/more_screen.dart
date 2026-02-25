import 'package:flutter/material.dart';
import '../services/budget_alert_service.dart';
import '../services/bill_reminder_service.dart';
import '../services/app_lock_service.dart';
import 'transfers_screen.dart';
import 'budget_management_screen.dart';
import 'recurring_transactions_screen.dart';
import 'goals_screen.dart';
import 'settings_screen.dart';
import 'calendar_screen.dart';
import 'enhanced_reports_screen.dart';
import 'export_screen.dart';
import 'transfer_analytics_screen.dart';
import 'alerts_screen.dart';
import 'search_transactions_screen.dart';
import 'theme_settings_screen.dart';
import 'currency_settings_screen.dart';
import 'import_transactions_screen.dart';
import 'bill_reminders_screen.dart';
import 'financial_insights_screen.dart';
import 'sip_insurance_screen.dart';
import 'predict_savings_screen.dart';
import 'notification_settings_screen.dart';
import 'pin_setup_screen.dart';
import 'emi_calculator_screen.dart';
import 'custom_categories_screen.dart';
import 'net_worth_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final alertService = BudgetAlertService();
    final billService  = BillReminderService();

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [

          // ── Budget Alerts ──────────────────────────────────────────────────
          StreamBuilder<int>(
            stream: alertService.getUnreadCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return _item(context,
                icon: Icons.notifications,
                title: 'Budget Alerts',
                subtitle: count > 0
                    ? '$count new alert${count > 1 ? 's' : ''}'
                    : 'View budget notifications',
                color: count > 0 ? Colors.red : Colors.blue,
                badge: count > 0 ? count : null,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AlertsScreen())));
            },
          ),

          // ── App Lock ───────────────────────────────────────────────────────
          _appLockTile(context),

          // ── Notification Settings ──────────────────────────────────────────
          _item(context,
            icon: Icons.notifications_active,
            title: 'Notification Settings',
            subtitle: 'Bills, daily summary & goal alerts',
            color: const Color(0xFF00838F),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()))),

          // ── Bill Reminders ─────────────────────────────────────────────────
          StreamBuilder<int>(
            stream: billService.getOverdueCount(),
            builder: (context, snapshot) {
              final overdue = snapshot.data ?? 0;
              return _item(context,
                icon: Icons.calendar_month,
                title: 'Bill Reminders',
                subtitle: overdue > 0
                    ? '$overdue bill${overdue > 1 ? 's' : ''} overdue!'
                    : 'Track bills & due dates',
                color: overdue > 0 ? Colors.red : const Color(0xFF1565C0),
                badge: overdue > 0 ? overdue : null,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const BillRemindersScreen())));
            },
          ),

          // ── EMI Calculator ─────────────────────────────────────────────────
          _item(context,
            icon: Icons.calculate,
            title: 'EMI Calculator',
            subtitle: 'Home, car & personal loan calculator',
            color: const Color(0xFF1565C0),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EmiCalculatorScreen()))),

          _item(context,
            icon: Icons.account_balance,
            title: 'Net Worth Tracker',
            subtitle: 'Assets vs liabilities — your true wealth',
            color: const Color(0xFF1A237E),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NetWorthScreen()))),

          _item(context,
            icon: Icons.label,
            title: 'Custom Categories',
            subtitle: 'Create your own expense & income categories',
            color: const Color(0xFF6A1B9A),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CustomCategoriesScreen()))),

          const Divider(),

          // ── Transfers ──────────────────────────────────────────────────────
          _item(context,
            icon: Icons.swap_horiz,
            title: 'Transfers',
            subtitle: 'Transfer between accounts',
            color: Colors.blue,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TransfersScreen()))),

          _item(context,
            icon: Icons.search,
            title: 'Search Transactions',
            subtitle: 'Advanced search & filters',
            color: Colors.teal,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SearchTransactionsScreen()))),

          _item(context,
            icon: Icons.repeat,
            title: 'Recurring Transactions',
            subtitle: 'Automatic transactions',
            color: Colors.purple,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RecurringTransactionsScreen()))),

          const Divider(),

          _item(context,
            icon: Icons.insights,
            title: 'Transfer Analytics',
            subtitle: 'Analyze transfer patterns',
            color: Colors.purple,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TransferAnalyticsScreen()))),

          _item(context,
            icon: Icons.file_upload,
            title: 'Import Transactions',
            subtitle: 'Import from Excel file',
            color: Colors.indigo,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ImportTransactionsScreen()))),

          _item(context,
            icon: Icons.download,
            title: 'Export & Backup',
            subtitle: 'Download transaction history',
            color: Colors.orange,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ExportScreen()))),

          const Divider(),

          _item(context,
            icon: Icons.pie_chart,
            title: 'Budget Management',
            subtitle: 'Set and track budgets',
            color: Colors.orange,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BudgetManagementScreen()))),

          _item(context,
            icon: Icons.flag,
            title: 'Financial Goals',
            subtitle: 'Track savings goals',
            color: Colors.green,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const GoalsScreen()))),

          const Divider(),

          _item(context,
            icon: Icons.calendar_today,
            title: 'Calendar View',
            subtitle: 'View transactions by date',
            color: Colors.teal,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CalendarScreen()))),

          _item(context,
            icon: Icons.auto_awesome,
            title: 'Financial Insights',
            subtitle: 'Trends, patterns & smart tips',
            color: const Color(0xFF6A1B9A),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const FinancialInsightsScreen()))),

          _item(context,
            icon: Icons.savings,
            title: 'SIP & Insurance Advisor',
            subtitle: 'AI-powered investment suggestions',
            color: const Color(0xFF4527A0),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SipInsuranceScreen()))),

          _item(context,
            icon: Icons.show_chart,
            title: 'Predict Future Savings',
            subtitle: 'Forecast & goal timeline simulator',
            color: const Color(0xFF00695C),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PredictSavingsScreen()))),

          _item(context,
            icon: Icons.bar_chart,
            title: 'Enhanced Reports',
            subtitle: 'Detailed analytics & charts',
            color: Colors.indigo,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EnhancedReportsScreen()))),

          const Divider(),

          _item(context,
            icon: Icons.palette,
            title: 'Theme Settings',
            subtitle: 'Colors, dark mode, fonts',
            color: Colors.pink,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ThemeSettingsScreen()))),

          _item(context,
            icon: Icons.currency_exchange,
            title: 'Currency Settings',
            subtitle: 'Change currency',
            color: Colors.amber[700]!,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CurrencySettingsScreen()))),

          _item(context,
            icon: Icons.settings,
            title: 'Settings',
            subtitle: 'App preferences & Gemini API key',
            color: Colors.grey,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()))),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── App Lock tile (reads live state) ──────────────────────────────────────
  Widget _appLockTile(BuildContext context) {
    return FutureBuilder<bool>(
      future: AppLockService().isLockEnabled(),
      builder: (context, snapshot) {
        final isEnabled = snapshot.data ?? false;
        return _item(context,
          icon: isEnabled ? Icons.lock : Icons.lock_open,
          title: 'App Lock',
          subtitle: isEnabled
              ? 'PIN lock is ON — tap to manage'
              : 'Protect app with PIN & biometric',
          color: const Color(0xFF37474F),
          onTap: () async {
            final svc = AppLockService();
            final hasPin = await svc.hasPin();
            if (!context.mounted) return;
            if (hasPin) {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20))),
                builder: (_) => _AppLockSheet(svc: svc),
              );
            } else {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PinSetupScreen()),
              );
              if (result == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('✅ App lock enabled!'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ));
              }
            }
          });
      },
    );
  }

  // ── Generic menu item ──────────────────────────────────────────────────────
  Widget _item(
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
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          if (badge != null)
            Positioned(
              top: -4, right: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                constraints:
                    const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  badge > 9 ? '9+' : '$badge',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      trailing: Icon(Icons.chevron_right,
          color: Colors.grey[400], size: 20),
      onTap: onTap,
    );
  }
}

// ── App Lock manage bottom sheet ───────────────────────────────────────────
class _AppLockSheet extends StatelessWidget {
  final AppLockService svc;
  const _AppLockSheet({required this.svc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('App Lock',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('PIN lock is active',
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 20),

          ListTile(
            leading: const Icon(Icons.lock_reset, color: Colors.blue),
            title: const Text('Change PIN'),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const PinSetupScreen(isChangingPin: true)));
            },
          ),

          ListTile(
            leading: const Icon(Icons.fingerprint, color: Colors.teal),
            title: const Text('Biometric Unlock'),
            trailing: FutureBuilder<bool>(
              future: svc.isBiometricEnabled(),
              builder: (ctx, snap) => Switch(
                value: snap.data ?? false,
                activeColor: Colors.teal,
                onChanged: (v) async {
                  await svc.setBiometricEnabled(v);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.no_encryption, color: Colors.red),
            title: const Text('Remove PIN Lock',
                style: TextStyle(color: Colors.red)),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Remove App Lock?'),
                  content: const Text(
                      'Anyone will be able to open the app without a PIN.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Remove',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (ok == true) {
                await svc.deletePin();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('App lock removed'),
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              }
            },
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}