import 'package:flutter/material.dart';
import '../services/onboarding_service.dart';
import 'onboarding_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/theme_provider.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';
import '../services/export_service.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext ctx) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      showDialog(context: ctx, barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()));
      await AuthService().signOut();
      if (ctx.mounted) Navigator.pop(ctx);
      if (kIsWeb) html.window.location.reload();
    } catch (_) {
      if (kIsWeb) html.window.location.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final theme   = Provider.of<ThemeProvider>(context);
    final auth    = AuthService();
    final user    = FirebaseAuth.instance.currentUser;
    final name    = user?.displayName ?? user?.email?.split('@').first ?? 'User';
    final email   = user?.email ?? '';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    final bg   = isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4FF);
    final card = isDark ? const Color(0xFF1E2530) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFF667eea),
            foregroundColor: Colors.white,
            title: const Text('Settings',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              child: Column(children: [

                // ── Profile card ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(
                        color: const Color(0xFF667eea).withOpacity(0.4),
                        blurRadius: 16, offset: const Offset(0, 8))],
                  ),
                  child: Row(children: [
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.4), width: 2),
                      ),
                      child: Center(
                        child: Text(initials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 24)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 17)),
                        const SizedBox(height: 2),
                        Text(email,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12)),
                      ],
                    )),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Free',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ),

                const SizedBox(height: 24),

                // ── About ──────────────────────────────────────────────
                _label('About', isDark),
                const SizedBox(height: 8),
                _section(card, isDark, [
                  _navTile(
                    icon: Icons.info_outline,
                    iconColor: const Color(0xFF7B1FA2),
                    title: 'Version',
                    subtitle: 'Money Manager v1.2.0',
                    isDark: isDark,
                    onTap: null,
                  ),
                  _divider(isDark),
                  _navTile(
                    icon: Icons.auto_awesome_outlined,
                    iconColor: const Color(0xFF667eea),
                    title: 'Replay Onboarding',
                    subtitle: 'See the intro slides again',
                    isDark: isDark,
                    onTap: () async {
                      await OnboardingService.reset();
                      if (!context.mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const OnboardingScreen()),
                        (route) => false,
                      );
                    },
                  ),
                  _divider(isDark),
                  _navTile(
                    icon: Icons.privacy_tip_outlined,
                    iconColor: Colors.teal,
                    title: 'Privacy Policy',
                    subtitle: 'How we handle your data',
                    isDark: isDark,
                    onTap: null,
                  ),
                ]),

                const SizedBox(height: 20),

                // ── Sign out ───────────────────────────────────────────
                _section(card, isDark, [
                  _navTile(
                    icon: Icons.logout,
                    iconColor: Colors.red,
                    title: 'Sign Out',
                    subtitle: 'Sign out of your account',
                    isDark: isDark,
                    titleColor: Colors.red,
                    onTap: () => _logout(context),
                  ),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _label(String text, bool isDark) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 0),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey[500],
                letterSpacing: 1.1)),
      );

  Widget _section(Color card, bool isDark, List<Widget> children) =>
      Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        ),
        child: Column(children: children),
      );

  Widget _divider(bool isDark) => Divider(
      height: 1, indent: 60,
      color: isDark
          ? Colors.white.withOpacity(0.06)
          : Colors.grey.shade100);

  Widget _switchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
    required Color card,
  }) =>
      SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 4),
        secondary: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF667eea),
      );

  Widget _navTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback? onTap,
    Color? titleColor,
  }) =>
      ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 4),
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: titleColor)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        trailing: onTap != null
            ? Icon(Icons.chevron_right,
                color: Colors.grey[300], size: 18)
            : null,
        onTap: onTap,
      );

  // ── Export helpers ─────────────────────────────────────────────────────────
  Future<void> _exportCSV(BuildContext ctx) async {
    final txnSvc = TransactionService();
    final accSvc = AccountService();
    final expSvc = ExportService();
    try {
      showDialog(context: ctx, barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()));
      final txns = await txnSvc.getTransactionsList();
      final accs = await accSvc.getAccountsList().first;
      final path = await expSvc.exportTransactionsToCSV(
          txns, accs,
          includeTransfers: true,
          includeIncome: true,
          includeExpense: true);
      if (ctx.mounted) {
        Navigator.pop(ctx);
        if (path != null) {
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Text('Exported: $path'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          ));
        }
      }
    } catch (e) {
      if (ctx.mounted) {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        ));
      }
    }
  }

  Future<void> _exportExcel(BuildContext ctx) async {
    final txnSvc = TransactionService();
    final accSvc = AccountService();
    final expSvc = ExportService();
    try {
      showDialog(context: ctx, barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()));
      final txns = await txnSvc.getTransactionsList();
      final accs = await accSvc.getAccountsList().first;
      final path = await expSvc.exportTransactionsToExcel(
          txns, accs,
          includeTransfers: true,
          includeIncome: true,
          includeExpense: true);
      if (ctx.mounted) {
        Navigator.pop(ctx);
        if (path != null) {
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Text('Exported: $path'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          ));
        }
      }
    } catch (e) {
      if (ctx.mounted) {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        ));
      }
    }
  }
}