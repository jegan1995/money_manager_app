import 'package:flutter/material.dart';
import '../services/budget_alert_service.dart';
import '../services/admin_service.dart';
import 'admin_panel_screen.dart';
import 'admin_force_update_screen.dart';
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
import 'family_screen.dart';

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

    return StreamBuilder<UserAccessInfo>(
      stream: _admin.watchCurrentUserAccess(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return Scaffold(
            backgroundColor:
                isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4FF),
            appBar: _appBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final access  = snap.data ?? UserAccessInfo.full();
        final isAdmin = _admin.isAdminSync;

        if (access.isSuspended) return _suspendedScreen(isDark);

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4FF),
          appBar: _appBar(),
          body: _buildBody(context, access, isAdmin, isDark),
        );
      },
    );
  }

  AppBar _appBar() => AppBar(
        title: const Text('More',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
      );

  // ── Main body ──────────────────────────────────────────────────────────────
  Widget _buildBody(BuildContext context, UserAccessInfo access,
      bool isAdmin, bool isDark) {

    // Helper: build a card section; returns null if ALL items are hidden
    Widget? section(String label, List<Widget?> items) {
      // Filter out null (hidden) items; insert dividers between visible ones
      final visible = items.where((w) => w != null).cast<Widget>().toList();
      if (visible.isEmpty) return null;

      final withDividers = <Widget>[];
      for (var i = 0; i < visible.length; i++) {
        withDividers.add(visible[i]);
        if (i < visible.length - 1) {
          withDividers.add(
            Divider(height: 1, indent: 64,
                color: Colors.grey.withOpacity(0.12)));
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(label.toUpperCase(),
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold,
                    color: Colors.grey[500], letterSpacing: 1.2)),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2530) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            ),
            child: Column(children: withDividers),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    // Helper: item — returns null when feature is disabled (completely hidden)
    Widget? item({
      required String feature,
      required bool locked,
      required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
      required Widget screen,
      int? badge,
    }) {
      // When locked: hide entirely from non-admin users
      if (locked) return null;

      return _rawItem(
        context,
        icon: icon,
        title: title,
        subtitle: subtitle,
        color: color,
        badge: badge,
        locked: false,
        isDark: isDark,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => screen)),
      );
    }

    final sections = <Widget>[];

    // ── Access banner ─────────────────────────────────────────────────────
    if (!isAdmin && (access.isLimited || access.isReadOnly)) {
      sections.add(Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.lock, color: Colors.orange, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              access.isReadOnly
                  ? 'Read-only mode — viewing only, no changes allowed'
                  : 'Limited access — some features are restricted',
              style: const TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
        ]),
      ));
    }

    // ── ADMIN ─────────────────────────────────────────────────────────────
    if (isAdmin) {
      final s = section('Admin', [
        item(
          feature: 'admin', locked: false,
          icon: Icons.admin_panel_settings,
          title: 'Master Control Panel',
          subtitle: 'Manage users, access & app stats',
          color: const Color(0xFF1A237E),
          screen: const AdminPanelScreen()),
        item(
          feature: 'forceUpdate', locked: false,
          icon: Icons.system_update_alt,
          title: 'Force Update Control',
          subtitle: 'Push update & block old versions',
          color: const Color(0xFFC62828),
          screen: AdminForceUpdateScreen()),
      ]);
      if (s != null) sections.add(s);
    }

    // ── FAMILY ────────────────────────────────────────────────────────────
    {
      final s = section('Family', [
        item(
          feature: 'family', locked: false,
          icon: Icons.people_alt,
          title: 'Family Mode',
          subtitle: 'Share finances with family members',
          color: const Color(0xFF7B1FA2),
          screen: const FamilyScreen()),
      ]);
      if (s != null) sections.add(s);
    }

    // ── FINANCE ───────────────────────────────────────────────────────────
    {
      // Budget Alerts (always visible — uses StreamBuilder)
      final alertsWidget = StreamBuilder<int>(
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
            isDark: isDark,
            onTap: () => Navigator.push(ctx,
                MaterialPageRoute(builder: (_) => const AlertsScreen())),
          );
        },
      );

      final s = section('Finance', [
        item(
          feature: 'netWorth',
          locked: !access.isFeatureEnabled('netWorth'),
          icon: Icons.account_balance,
          title: 'Net Worth Tracker',
          subtitle: 'Assets vs liabilities',
          color: const Color(0xFF1A237E),
          screen: const NetWorthScreen()),
        item(
          feature: 'budget',
          locked: !access.isFeatureEnabled('budget'),
          icon: Icons.pie_chart,
          title: 'Budget Management',
          subtitle: 'Set & track category budgets',
          color: const Color(0xFFF57F17),
          screen: const BudgetManagementScreen()),
        item(
          feature: 'budget2',
          locked: !access.isFeatureEnabled('budget'),
          icon: Icons.bar_chart,
          title: 'Budget Overview',
          subtitle: 'View budget progress',
          color: const Color(0xFFE65100),
          screen: const BudgetScreen()),
        item(
          feature: 'goals',
          locked: !access.isFeatureEnabled('goals'),
          icon: Icons.flag,
          title: 'Financial Goals',
          subtitle: 'Track savings goals',
          color: const Color(0xFF2E7D32),
          screen: const GoalsScreen()),
        alertsWidget, // always visible
      ]);
      if (s != null) sections.add(s);
    }

    // ── TRANSACTIONS ──────────────────────────────────────────────────────
    {
      final s = section('Transactions', [
        item(
          feature: 'transfers',
          locked: !access.isFeatureEnabled('transfers'),
          icon: Icons.swap_horiz,
          title: 'Transfers',
          subtitle: 'Transfer between accounts',
          color: const Color(0xFF1565C0),
          screen: const TransfersScreen()),
        item(
          feature: 'recurring',
          locked: !access.isFeatureEnabled('recurring'),
          icon: Icons.repeat,
          title: 'Recurring Transactions',
          subtitle: 'Auto-scheduled transactions',
          color: const Color(0xFF7B1FA2),
          screen: const RecurringTransactionsScreen()),
        item(
          feature: 'search', locked: false,
          icon: Icons.search,
          title: 'Search Transactions',
          subtitle: 'Advanced search & filters',
          color: const Color(0xFF00695C),
          screen: const SearchTransactionsScreen()),
        item(
          feature: 'calendar', locked: false,
          icon: Icons.calendar_month,
          title: 'Calendar View',
          subtitle: 'Transactions by date',
          color: const Color(0xFF283593),
          screen: const CalendarScreen()),
      ]);
      if (s != null) sections.add(s);
    }

    // ── ANALYTICS ─────────────────────────────────────────────────────────
    {
      final s = section('Analytics', [
        item(
          feature: 'reports',
          locked: !access.isFeatureEnabled('reports'),
          icon: Icons.analytics_outlined,
          title: 'Statistics',
          subtitle: 'Detailed charts & insights',
          color: const Color(0xFF00838F),
          screen: const StatisticsScreen()),
        item(
          feature: 'reports2',
          locked: !access.isFeatureEnabled('reports'),
          icon: Icons.insights,
          title: 'Transfer Analytics',
          subtitle: 'Analyze transfer patterns',
          color: const Color(0xFF6A1B9A),
          screen: const TransferAnalyticsScreen()),
        item(
          feature: 'pdfReport',
          locked: !access.isFeatureEnabled('pdfReport'),
          icon: Icons.picture_as_pdf,
          title: 'Monthly PDF Report',
          subtitle: 'Generate & share financial summary',
          color: const Color(0xFF1565C0),
          screen: const PdfReportScreen()),
      ]);
      if (s != null) sections.add(s);
    }

    // ── DATA ──────────────────────────────────────────────────────────────
    {
      final s = section('Data', [
        item(
          feature: 'import',
          locked: !access.isFeatureEnabled('import'),
          icon: Icons.file_upload_outlined,
          title: 'Import Transactions',
          subtitle: 'Import from Excel / CSV',
          color: const Color(0xFF283593),
          screen: const ImportTransactionsScreen()),
        item(
          feature: 'export',
          locked: !access.isFeatureEnabled('export'),
          icon: Icons.download_outlined,
          title: 'Export & Backup',
          subtitle: 'Download transaction history',
          color: const Color(0xFFE65100),
          screen: const ExportScreen()),
        item(
          feature: 'categories', locked: false,
          icon: Icons.label_outline,
          title: 'Custom Categories',
          subtitle: 'Create your own categories',
          color: const Color(0xFF6A1B9A),
          screen: const CustomCategoriesScreen()),
      ]);
      if (s != null) sections.add(s);
    }

    // ── TOOLS ─────────────────────────────────────────────────────────────
    {
      final s = section('Tools', [
        item(
          feature: 'emiCalc',
          locked: !access.isFeatureEnabled('emiCalc'),
          icon: Icons.calculate_outlined,
          title: 'EMI Calculator',
          subtitle: 'Calculate loan EMIs',
          color: const Color(0xFF00695C),
          screen: const EmiCalculatorScreen()),
        item(
          feature: 'install', locked: false,
          icon: Icons.install_mobile_outlined,
          title: 'Install App',
          subtitle: 'Add to iPhone / Android home screen',
          color: const Color(0xFF00897B),
          screen: const PwaInstallScreen()),
      ]);
      if (s != null) sections.add(s);
    }

    // ── SETTINGS ──────────────────────────────────────────────────────────
    {
      final s = section('Settings', [
        item(
          feature: 'theme', locked: false,
          icon: Icons.palette_outlined,
          title: 'Theme',
          subtitle: 'Light / Dark / System',
          color: const Color(0xFF7B1FA2),
          screen: const ThemeSettingsScreen()),
        item(
          feature: 'currency', locked: false,
          icon: Icons.currency_exchange,
          title: 'Currency',
          subtitle: 'Change display currency',
          color: const Color(0xFF2E7D32),
          screen: const CurrencySettingsScreen()),
        item(
          feature: 'settings', locked: false,
          icon: Icons.settings_outlined,
          title: 'App Settings',
          subtitle: 'Preferences & account',
          color: const Color(0xFF546E7A),
          screen: const SettingsScreen()),
      ]);
      if (s != null) sections.add(s);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: sections,
    );
  }

  // ── Suspended screen ──────────────────────────────────────────────────────
  Widget _suspendedScreen(bool isDark) => Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4FF),
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
                  child: const Icon(Icons.block, color: Colors.red, size: 40),
                ),
                const SizedBox(height: 20),
                const Text('Account Suspended',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 22)),
                const SizedBox(height: 10),
                Text(
                  'Your account has been suspended by the administrator.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
      );

  // ── Raw item widget ───────────────────────────────────────────────────────
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
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
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[300], size: 18),
          ]),
        ),
      );
}