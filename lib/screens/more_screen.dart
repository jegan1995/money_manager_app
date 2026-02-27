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
  final _admin    = AdminService();
  final _alertSvc = BudgetAlertService();

  @override
  void initState() {
    super.initState();
    _admin.updateLastActive();
    _admin.ensureAdminRecord();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Real-time stream: rebuilds INSTANTLY when admin changes anything ────
    return StreamBuilder<UserAccessInfo>(
      stream: _admin.watchCurrentUserAccess(),
      builder: (context, snap) {
        // Show loading only on very first load
        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return Scaffold(
            backgroundColor: isDark
                ? const Color(0xFF0D1117)
                : const Color(0xFFF5F6FA),
            appBar: _appBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final access   = snap.data ?? UserAccessInfo.full();
        final isAdmin  = _admin.isAdminSync;

        // Suspended screen
        if (access.isSuspended) {
          return _suspendedScreen(isDark);
        }

        return Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF0D1117)
              : const Color(0xFFF5F6FA),
          appBar: _appBar(),
          body: _buildBody(context, access, isAdmin, isDark),
        );
      },
    );
  }

  AppBar _appBar() => AppBar(
        title: const Text('More'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      );

  Widget _buildBody(BuildContext context, UserAccessInfo access,
      bool isAdmin, bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [

        // ── Access banner for restricted users ──────────────────────────
        if (!isAdmin && (access.isLimited || access.isReadOnly)) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.lock, color: Colors.orange, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  access.isReadOnly
                      ? 'Read-only mode — viewing only, no changes allowed'
                      : 'Limited access — some features are restricted',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.orange),
                ),
              ),
            ]),
          ),
        ],

        // ── ADMIN (only YOUR account sees this) ─────────────────────────
        if (isAdmin) ...[
          _sectionLabel('Admin'),
          _card(isDark, children: [
            _item(context,
              icon: Icons.admin_panel_settings,
              title: 'Master Control Panel',
              subtitle: 'Manage users, access & app stats',
              color: const Color(0xFF1A237E),
              locked: false,
              access: access,
              feature: 'admin',
              screen: const AdminPanelScreen()),
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
            locked: !access.isFeatureEnabled('netWorth'),
            access: access,
            feature: 'netWorth',
            screen: const NetWorthScreen()),
          _divider(),
          _item(context,
            icon: Icons.pie_chart,
            title: 'Budget Management',
            subtitle: 'Set & track category budgets',
            color: const Color(0xFFF57F17),
            locked: !access.isFeatureEnabled('budget'),
            access: access,
            feature: 'budget',
            screen: const BudgetManagementScreen()),
          _divider(),
          _item(context,
            icon: Icons.bar_chart,
            title: 'Budget Overview',
            subtitle: 'View budget progress',
            color: const Color(0xFFE65100),
            locked: !access.isFeatureEnabled('budget'),
            access: access,
            feature: 'budget',
            screen: const BudgetScreen()),
          _divider(),
          _item(context,
            icon: Icons.flag,
            title: 'Financial Goals',
            subtitle: 'Track savings goals',
            color: const Color(0xFF2E7D32),
            locked: !access.isFeatureEnabled('goals'),
            access: access,
            feature: 'goals',
            screen: const GoalsScreen()),
          _divider(),
          StreamBuilder<int>(
            stream: _alertSvc.getUnreadCount(),
            builder: (ctx, snap) {
              final count = snap.data ?? 0;
              return _rawItem(
                ctx,
                icon: Icons.notifications_outlined,
                title: 'Budget Alerts',
                subtitle: count > 0
                    ? '$count new alert${count > 1 ? 's' : ''}'
                    : 'Budget notifications',
                color: count > 0
                    ? const Color(0xFFC62828)
                    : const Color(0xFF1565C0),
                badge: count > 0 ? count : null,
                locked: false,
                isDark: Theme.of(ctx).brightness == Brightness.dark,
                onTap: () => Navigator.push(ctx,
                    MaterialPageRoute(
                        builder: (_) => const AlertsScreen())),
              );
            },
          ),
        ]),

        const SizedBox(height: 16),

        // ── TRANSACTIONS ────────────────────────────────────────────────
        _sectionLabel('Transactions'),
        _card(isDark, children: [
          _item(context,
            icon: Icons.swap_horiz,
            title: 'Transfers',
            subtitle: 'Transfer between accounts',
            color: const Color(0xFF1565C0),
            locked: !access.isFeatureEnabled('transfers'),
            access: access,
            feature: 'transfers',
            screen: const TransfersScreen()),
          _divider(),
          _item(context,
            icon: Icons.repeat,
            title: 'Recurring Transactions',
            subtitle: 'Auto-scheduled transactions',
            color: const Color(0xFF7B1FA2),
            locked: !access.isFeatureEnabled('recurring'),
            access: access,
            feature: 'recurring',
            screen: const RecurringTransactionsScreen()),
          _divider(),
          _item(context,
            icon: Icons.search,
            title: 'Search Transactions',
            subtitle: 'Advanced search & filters',
            color: const Color(0xFF00695C),
            locked: false,
            access: access,
            feature: 'search',
            screen: const SearchTransactionsScreen()),
          _divider(),
          _item(context,
            icon: Icons.calendar_month,
            title: 'Calendar View',
            subtitle: 'Transactions by date',
            color: const Color(0xFF283593),
            locked: false,
            access: access,
            feature: 'calendar',
            screen: const CalendarScreen()),
        ]),

        const SizedBox(height: 16),

        // ── ANALYTICS ──────────────────────────────────────────────────
        _sectionLabel('Analytics'),
        _card(isDark, children: [
          _item(context,
            icon: Icons.analytics_outlined,
            title: 'Statistics',
            subtitle: 'Detailed charts & insights',
            color: const Color(0xFF00838F),
            locked: !access.isFeatureEnabled('reports'),
            access: access,
            feature: 'reports',
            screen: const StatisticsScreen()),
          _divider(),
          _item(context,
            icon: Icons.insights,
            title: 'Transfer Analytics',
            subtitle: 'Analyze transfer patterns',
            color: const Color(0xFF6A1B9A),
            locked: !access.isFeatureEnabled('reports'),
            access: access,
            feature: 'reports',
            screen: const TransferAnalyticsScreen()),
          _divider(),
          _item(context,
            icon: Icons.picture_as_pdf,
            title: 'Monthly PDF Report',
            subtitle: 'Generate & share financial summary',
            color: const Color(0xFF1565C0),
            locked: !access.isFeatureEnabled('pdfReport'),
            access: access,
            feature: 'pdfReport',
            screen: const PdfReportScreen()),
        ]),

        const SizedBox(height: 16),

        // ── DATA ───────────────────────────────────────────────────────
        _sectionLabel('Data'),
        _card(isDark, children: [
          _item(context,
            icon: Icons.file_upload_outlined,
            title: 'Import Transactions',
            subtitle: 'Import from Excel / CSV',
            color: const Color(0xFF283593),
            locked: !access.isFeatureEnabled('import'),
            access: access,
            feature: 'import',
            screen: const ImportTransactionsScreen()),
          _divider(),
          _item(context,
            icon: Icons.download_outlined,
            title: 'Export & Backup',
            subtitle: 'Download transaction history',
            color: const Color(0xFFE65100),
            locked: !access.isFeatureEnabled('export'),
            access: access,
            feature: 'export',
            screen: const ExportScreen()),
          _divider(),
          _item(context,
            icon: Icons.label_outline,
            title: 'Custom Categories',
            subtitle: 'Create your own categories',
            color: const Color(0xFF6A1B9A),
            locked: false,
            access: access,
            feature: 'categories',
            screen: const CustomCategoriesScreen()),
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
            locked: !access.isFeatureEnabled('emiCalc'),
            access: access,
            feature: 'emiCalc',
            screen: const EmiCalculatorScreen()),
          _divider(),
          _item(context,
            icon: Icons.install_mobile_outlined,
            title: 'Install App',
            subtitle: 'Add to iPhone / Android home screen',
            color: const Color(0xFF00897B),
            locked: false,
            access: access,
            feature: 'install',
            screen: const PwaInstallScreen()),
        ]),

        const SizedBox(height: 16),

        // ── SETTINGS ─────────────────────────────────────────────────
        _sectionLabel('Settings'),
        _card(isDark, children: [
          _item(context,
            icon: Icons.palette_outlined,
            title: 'Theme',
            subtitle: 'Light / Dark / System',
            color: const Color(0xFF7B1FA2),
            locked: false,
            access: access,
            feature: 'theme',
            screen: const ThemeSettingsScreen()),
          _divider(),
          _item(context,
            icon: Icons.currency_exchange,
            title: 'Currency',
            subtitle: 'Change display currency',
            color: const Color(0xFF2E7D32),
            locked: false,
            access: access,
            feature: 'currency',
            screen: const CurrencySettingsScreen()),
          _divider(),
          _item(context,
            icon: Icons.settings_outlined,
            title: 'App Settings',
            subtitle: 'Preferences & account',
            color: const Color(0xFF546E7A),
            locked: false,
            access: access,
            feature: 'settings',
            screen: const SettingsScreen()),
        ]),
      ],
    );
  }

  // ── Suspended screen ──────────────────────────────────────────────────────
  Widget _suspendedScreen(bool isDark) => Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F6FA),
        appBar: _appBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.block,
                      color: Colors.red, size: 40),
                ),
                const SizedBox(height: 20),
                const Text('Account Suspended',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22)),
                const SizedBox(height: 10),
                Text(
                  'Your account has been suspended by the administrator.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
      );

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold,
                color: Colors.grey[500], letterSpacing: 1.2)),
      );

  Widget _card(bool isDark, {required List<Widget> children}) =>
      Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2530) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        ),
        child: Column(children: children),
      );

  Widget _divider() =>
      Divider(height: 1, indent: 64,
          color: Colors.grey.withOpacity(0.12));

  // Smart item — uses locked bool directly
  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool locked,
    required UserAccessInfo access,
    required String feature,
    required Widget screen,
    int? badge,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _rawItem(
      context,
      icon: icon,
      title: title,
      subtitle: subtitle,
      color: color,
      badge: badge,
      locked: locked,
      isDark: isDark,
      onTap: () {
        if (locked) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.lock, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(
                  '$title — Access restricted by admin')),
            ]),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          ));
        } else {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => screen));
        }
      },
    );
  }

  Widget _rawItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool locked,
    required bool isDark,
    required VoidCallback onTap,
    int? badge,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          child: Row(children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: locked
                      ? Colors.grey.withOpacity(0.08)
                      : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    color: locked ? Colors.grey[400] : color,
                    size: 20),
              ),
              if (badge != null && badge > 0)
                Positioned(
                  right: -4, top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: Text('$badge',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: locked ? Colors.grey[400] : null)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
            locked
                ? const Icon(Icons.lock_outline,
                    color: Colors.grey, size: 16)
                : Icon(Icons.chevron_right,
                    color: Colors.grey[300], size: 18),
          ]),
        ),
      );
}