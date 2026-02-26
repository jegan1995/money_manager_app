import 'package:flutter/material.dart';
import '../services/budget_alert_service.dart';
import '../services/admin_service.dart';
import 'admin_panel_screen.dart';
import 'transfers_screen.dart';
import 'budget_management_screen.dart';
import 'budget_screen.dart';
import 'recurring_transactions_screen.dart';
import 'goals_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'calendar_screen.dart';
import 'export_screen.dart';
import 'transfer_analytics_screen.dart';
import 'alerts_screen.dart';
import 'search_transactions_screen.dart';
import 'theme_settings_screen.dart';
import 'currency_settings_screen.dart';
import 'import_transactions_screen.dart';
import 'emi_calculator_screen.dart';
import 'custom_categories_screen.dart';
import 'pdf_report_screen.dart';
import 'pwa_install_screen.dart';
import 'net_worth_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final _admin = AdminService();
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    _admin.updateLastActive(); // track activity
  }

  Future<void> _checkAdmin() async {
    final admin = await _admin.checkIsAdmin();
    if (mounted) setState(() => _isAdmin = admin);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alertService = BudgetAlertService();

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('More'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [

          // ── ADMIN PANEL (only visible to admin) ──────────────────────────────
          if (_isAdmin) ...[
            _sectionLabel('Admin'),
            _card(isDark, children: [
              _item(context,
                icon: Icons.admin_panel_settings,
                title: 'Master Control Panel',
                subtitle: 'Manage users, access & app stats',
                color: const Color(0xFF1A237E),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const AdminPanelScreen()))),
            ]),
            const SizedBox(height: 16),
          ],

          // ── FINANCE ────────────────────────────────────────────────────
          _sectionLabel('Finance'),
          _card(isDark, children: [
            _item(context,
              icon: Icons.account_balance,
              title: 'Net Worth Tracker',
              subtitle: 'Assets vs liabilities',
              color: const Color(0xFF1A237E),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NetWorthScreen()))),
            _divider(),
            _item(context,
              icon: Icons.pie_chart,
              title: 'Budget Management',
              subtitle: 'Set & track category budgets',
              color: const Color(0xFFF57F17),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const BudgetManagementScreen()))),
            _divider(),
            _item(context,
              icon: Icons.bar_chart,
              title: 'Budget Overview',
              subtitle: 'View budget progress',
              color: const Color(0xFFE65100),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const BudgetScreen()))),
            _divider(),
            _item(context,
              icon: Icons.flag,
              title: 'Financial Goals',
              subtitle: 'Track savings goals',
              color: const Color(0xFF2E7D32),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const GoalsScreen()))),
            _divider(),
            // Budget Alerts with badge
            StreamBuilder<int>(
              stream: alertService.getUnreadCount(),
              builder: (ctx, snap) {
                final count = snap.data ?? 0;
                return _item(ctx,
                  icon: Icons.notifications_outlined,
                  title: 'Budget Alerts',
                  subtitle: count > 0
                      ? '$count new alert${count > 1 ? 's' : ''}'
                      : 'Budget notifications',
                  color: count > 0
                      ? const Color(0xFFC62828)
                      : const Color(0xFF1565C0),
                  badge: count > 0 ? count : null,
                  onTap: () => Navigator.push(ctx,
                      MaterialPageRoute(
                          builder: (_) => const AlertsScreen())));
              },
            ),
          ]),

          const SizedBox(height: 16),

          // ── TRANSACTIONS ───────────────────────────────────────────────
          _sectionLabel('Transactions'),
          _card(isDark, children: [
            _item(context,
              icon: Icons.swap_horiz,
              title: 'Transfers',
              subtitle: 'Transfer between accounts',
              color: const Color(0xFF1565C0),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TransfersScreen()))),
            _divider(),
            _item(context,
              icon: Icons.repeat,
              title: 'Recurring Transactions',
              subtitle: 'Auto-scheduled transactions',
              color: const Color(0xFF7B1FA2),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const RecurringTransactionsScreen()))),
            _divider(),
            _item(context,
              icon: Icons.search,
              title: 'Search Transactions',
              subtitle: 'Advanced search & filters',
              color: const Color(0xFF00695C),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const SearchTransactionsScreen()))),
            _divider(),
            _item(context,
              icon: Icons.calendar_month,
              title: 'Calendar View',
              subtitle: 'Transactions by date',
              color: const Color(0xFF283593),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const CalendarScreen()))),
          ]),

          const SizedBox(height: 16),

          // ── ANALYTICS ─────────────────────────────────────────────────
          _sectionLabel('Analytics'),
          _card(isDark, children: [
            _item(context,
              icon: Icons.analytics_outlined,
              title: 'Statistics',
              subtitle: 'Detailed charts & insights',
              color: const Color(0xFF00838F),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const StatisticsScreen()))),
            _divider(),
            _item(context,
              icon: Icons.insights,
              title: 'Transfer Analytics',
              subtitle: 'Analyze transfer patterns',
              color: const Color(0xFF6A1B9A),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const TransferAnalyticsScreen()))),
            _divider(),
            _item(context,
              icon: Icons.picture_as_pdf,
              title: 'Monthly PDF Report',
              subtitle: 'Generate & share financial summary',
              color: const Color(0xFF1565C0),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const PdfReportScreen()))),
          ]),

          const SizedBox(height: 16),

          // ── DATA ──────────────────────────────────────────────────────
          _sectionLabel('Data'),
          _card(isDark, children: [
            _item(context,
              icon: Icons.file_upload_outlined,
              title: 'Import Transactions',
              subtitle: 'Import from Excel / CSV',
              color: const Color(0xFF283593),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const ImportTransactionsScreen()))),
            _divider(),
            _item(context,
              icon: Icons.download_outlined,
              title: 'Export & Backup',
              subtitle: 'Download transaction history',
              color: const Color(0xFFE65100),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const ExportScreen()))),
            _divider(),
            _item(context,
              icon: Icons.label_outline,
              title: 'Custom Categories',
              subtitle: 'Create your own categories',
              color: const Color(0xFF6A1B9A),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const CustomCategoriesScreen()))),
          ]),

          const SizedBox(height: 16),

          // ── TOOLS ─────────────────────────────────────────────────────
          _sectionLabel('Tools'),
          _card(isDark, children: [
            _item(context,
              icon: Icons.calculate_outlined,
              title: 'EMI Calculator',
              subtitle: 'Calculate loan EMIs',
              color: const Color(0xFF00695C),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const EmiCalculatorScreen()))),
            _divider(),
            _item(context,
              icon: Icons.install_mobile_outlined,
              title: 'Install App',
              subtitle: 'Add to iPhone / Android home screen',
              color: const Color(0xFF00897B),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const PwaInstallScreen()))),
          ]),

          const SizedBox(height: 16),

          // ── SETTINGS ──────────────────────────────────────────────────
          _sectionLabel('Settings'),
          _card(isDark, children: [
            _item(context,
              icon: Icons.palette_outlined,
              title: 'Theme',
              subtitle: 'Light / Dark / System',
              color: const Color(0xFF7B1FA2),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const ThemeSettingsScreen()))),
            _divider(),
            _item(context,
              icon: Icons.currency_exchange,
              title: 'Currency',
              subtitle: 'Change display currency',
              color: const Color(0xFF2E7D32),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const CurrencySettingsScreen()))),
            _divider(),
            _item(context,
              icon: Icons.settings_outlined,
              title: 'App Settings',
              subtitle: 'Preferences & account',
              color: const Color(0xFF546E7A),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const SettingsScreen()))),
          ]),

        ],
      ),
    );
  }

  // ── Builders ───────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey[500],
              letterSpacing: 1.2),
        ),
      );

  Widget _card(bool isDark, {required List<Widget> children}) =>
      Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2530) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(children: children),
      );

  Widget _divider() => Divider(
      height: 1, indent: 64, color: Colors.grey.withOpacity(0.12));

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    int? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(child: Icon(icon, color: color, size: 20)),
                if (badge != null && badge > 0)
                  Positioned(
                    right: -4, top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500])),
              ],
            ),
          ),
          Icon(Icons.chevron_right,
              color: Colors.grey[300], size: 18),
        ]),
      ),
    );
  }
}