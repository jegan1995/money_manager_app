import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;
import '../providers/theme_provider.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';
import '../services/export_service.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _performLogout(BuildContext context) async {
    final authService = AuthService();
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      await authService.signOut();
      if (context.mounted) Navigator.pop(context);
      if (kIsWeb) html.window.location.reload();
    } catch (e) {
      if (kIsWeb) {
        html.window.location.reload();
      } else if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final transactionService = TransactionService();
    final accountService = AccountService();
    final exportService = ExportService();
    final authService = AuthService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // ── Account Section ──────────────────────────────────────────
          _sectionHeader('Account', isDark),
          _buildCard(
            isDark,
            children: [
              FutureBuilder<String?>(
                future: authService.getUserName(),
                builder: (context, snapshot) {
                  final name = snapshot.data ?? authService.currentUser?.email ?? 'User';
                  return _buildTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    title: name,
                    subtitle: authService.currentUser?.email ?? '',
                    isDark: isDark,
                  );
                },
              ),
              _divider(isDark),
              _buildTile(
                leading: const Icon(Icons.logout, color: Colors.red, size: 20),
                title: 'Logout',
                titleColor: Colors.red,
                isDark: isDark,
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Logout', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) await _performLogout(context);
                },
              ),
            ],
          ),

          // ── Appearance Section ────────────────────────────────────────
          _sectionHeader('Appearance', isDark),
          _buildCard(
            isDark,
            children: [
              // Dark Mode Toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      size: 20,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dark Mode',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : Colors.grey[900])),
                          Text('Switch between light and dark theme',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[500])),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: themeProvider.isDarkMode,
                      onChanged: (_) => themeProvider.toggleTheme(),
                    ),
                  ],
                ),
              ),
              _divider(isDark),

              // Font Size Selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.text_fields, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Font Size',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white : Colors.grey[900])),
                              Text('Current: ${themeProvider.fontSizeLabel}',
                                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[500])),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _fontSizeChip('Small', AppFontSize.small, themeProvider, isDark),
                        const SizedBox(width: 8),
                        _fontSizeChip('Medium', AppFontSize.medium, themeProvider, isDark),
                        const SizedBox(width: 8),
                        _fontSizeChip('Large', AppFontSize.large, themeProvider, isDark),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Live preview
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.preview, size: 14, color: isDark ? Colors.grey[500] : Colors.grey[500]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Preview: ₹12,500 • Food & Dining',
                              style: TextStyle(
                                fontSize: 13, // base size — scaling applied by MediaQuery
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Data Section ──────────────────────────────────────────────
          _sectionHeader('Data', isDark),
          _buildCard(
            isDark,
            children: [
              _buildTile(
                leading: Icon(Icons.download, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                title: 'Export to CSV',
                subtitle: 'Download transactions as CSV file',
                isDark: isDark,
                onTap: () async {
                  try {
                    _showLoading(context);
                    final transactions = await transactionService.getTransactionsList();
                    final accounts = await accountService.getAccountsList().first;
                    final path = await exportService.exportTransactionsToCSV(
                      transactions, accounts,
                      includeTransfers: true, includeIncome: true, includeExpense: true,
                    );
                    Navigator.pop(context);
                    if (path != null && context.mounted) {
                      _showSnack(context, 'Exported: $path', isSuccess: true);
                    }
                  } catch (e) {
                    Navigator.pop(context);
                    if (context.mounted) _showSnack(context, 'Export failed: $e');
                  }
                },
              ),
              _divider(isDark),
              _buildTile(
                leading: Icon(Icons.table_chart, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                title: 'Export to Excel',
                subtitle: 'Download detailed Excel report',
                isDark: isDark,
                onTap: () async {
                  try {
                    _showLoading(context);
                    final transactions = await transactionService.getTransactionsList();
                    final accounts = await accountService.getAccountsList().first;
                    final path = await exportService.exportTransactionsToExcel(
                      transactions, accounts,
                      includeTransfers: true, includeIncome: true, includeExpense: true,
                    );
                    Navigator.pop(context);
                    if (path != null && context.mounted) {
                      _showSnack(context, 'Exported: $path', isSuccess: true);
                    }
                  } catch (e) {
                    Navigator.pop(context);
                    if (context.mounted) _showSnack(context, 'Export failed: $e');
                  }
                },
              ),
            ],
          ),

          // ── About Section ─────────────────────────────────────────────
          _sectionHeader('About', isDark),
          _buildCard(
            isDark,
            children: [
              _buildTile(
                leading: Icon(Icons.info_outline, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                title: 'Version',
                subtitle: '1.2.0',
                isDark: isDark,
              ),
              _divider(isDark),
              _buildTile(
                leading: Icon(Icons.account_balance_wallet, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                title: 'Money Manager',
                subtitle: 'Track your income and expenses',
                isDark: isDark,
              ),
              _divider(isDark),
              _buildTile(
                leading: Icon(Icons.person_outline, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                title: 'Developer',
                subtitle: 'Built by Jegan',
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── Reusable widgets ────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.blue[300] : Colors.blue[700],
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCard(bool isDark, {required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTile({
    required Widget leading,
    required String title,
    String? subtitle,
    Color? titleColor,
    bool isDark = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: titleColor ?? (isDark ? Colors.white : Colors.grey[900]),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right,
                  size: 16, color: isDark ? Colors.grey[600] : Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(
      height: 1,
      indent: 46,
      color: isDark ? Colors.grey[800] : Colors.grey[100],
    );
  }

  Widget _fontSizeChip(
      String label, AppFontSize value, ThemeProvider provider, bool isDark) {
    final isSelected = provider.fontSize == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => provider.setFontSize(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.blue
                : (isDark ? Colors.grey[800] : Colors.grey[100]),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.transparent,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _showSnack(BuildContext context, String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isSuccess ? Colors.green : Colors.red,
      duration: const Duration(seconds: 4),
    ));
  }
}