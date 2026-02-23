import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;
import '../providers/theme_provider.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';
import '../services/export_service.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _geminiKeyController = TextEditingController();
  bool _keyObscured = true;
  bool _keySaved = false;
  bool _keyLoading = true;

  static const _geminiPrefKey = 'gemini_api_key';

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  @override
  void dispose() {
    _geminiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_geminiPrefKey) ?? '';
    setState(() {
      _geminiKeyController.text = key;
      _keySaved = key.isNotEmpty;
      _keyLoading = false;
    });
  }

  Future<void> _saveKey() async {
    final key = _geminiKeyController.text.trim();
    if (key.isEmpty) {
      _snack('Please enter your Gemini API key', Colors.red);
      return;
    }
    if (!key.startsWith('AIza')) {
      _snack('Invalid key — Gemini keys start with "AIza"', Colors.orange);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_geminiPrefKey, key);
    setState(() => _keySaved = true);
    _snack('✅ Gemini API key saved! AI features are now active.', Colors.green);
  }

  Future<void> _deleteKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_geminiPrefKey);
    setState(() {
      _geminiKeyController.clear();
      _keySaved = false;
    });
    _snack('API key removed', Colors.grey);
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    ));
  }

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Logout error: $e'),
          backgroundColor: Colors.red,
        ));
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
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 10),

          // ── Account ──────────────────────────────────────────────────────────
          _header('Account'),
          FutureBuilder<String?>(
            future: authService.getUserName(),
            builder: (context, snapshot) {
              final name = snapshot.data ?? authService.currentUser?.email ?? 'User';
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Text(name[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.blue, fontWeight: FontWeight.bold)),
                ),
                title: Text(name),
                subtitle: Text(authService.currentUser?.email ?? ''),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Logout',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirm == true) await _performLogout(context);
            },
          ),
          const Divider(),

          // ── Gemini AI ────────────────────────────────────────────────────────
          _header('🤖 Gemini AI Settings'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status banner
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _keySaved
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _keySaved
                          ? Colors.green.withOpacity(0.4)
                          : Colors.orange.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(_keySaved ? '✅' : '⚠️',
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _keySaved
                              ? 'AI features active — Receipt Scanner, SIP Advisor, Predict Savings, Voice Input'
                              : 'Add your Gemini API key to enable all AI features',
                          style: TextStyle(
                              fontSize: 12,
                              color: _keySaved
                                  ? Colors.green[700]
                                  : Colors.orange[800]),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Key input field
                _keyLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : TextFormField(
                        controller: _geminiKeyController,
                        obscureText: _keyObscured,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Gemini API Key',
                          hintText: 'AIzaSy...',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.key, color: Colors.blue),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(_keyObscured
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                                onPressed: () => setState(
                                    () => _keyObscured = !_keyObscured),
                                tooltip: 'Show/Hide key',
                              ),
                              if (_geminiKeyController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.copy_outlined,
                                      size: 18),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(
                                        text: _geminiKeyController.text));
                                    _snack('Copied!', Colors.blue);
                                  },
                                  tooltip: 'Copy key',
                                ),
                            ],
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),

                const SizedBox(height: 10),

                // Action buttons row
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _saveKey,
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: const Text('Save Key'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    if (_keySaved) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _deleteKey,
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          label: const Text('Remove',
                              style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 12),

                // How to get key info
                GestureDetector(
                  onTap: () => _showGetKeyDialog(context),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.blue.withOpacity(0.08)
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.help_outline,
                            size: 18, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'How to get a free Gemini API key? Tap here.',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // ── Appearance ───────────────────────────────────────────────────────
          _header('Appearance'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Enable dark theme'),
            secondary: Icon(
                themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode),
            value: themeProvider.isDarkMode,
            onChanged: (_) => themeProvider.toggleTheme(),
          ),
          const Divider(),

          // ── Data ─────────────────────────────────────────────────────────────
          _header('Data'),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export to CSV'),
            subtitle: const Text('Download transactions as CSV'),
            onTap: () async {
              try {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) =>
                      const Center(child: CircularProgressIndicator()),
                );
                final transactions = await transactionService.getTransactionsList();
                final accounts = await accountService.getAccountsList().first;
                final path = await exportService.exportTransactionsToCSV(
                  transactions, accounts,
                  includeTransfers: true,
                  includeIncome: true,
                  includeExpense: true,
                );
                if (context.mounted) Navigator.pop(context);
                if (path != null) {
                  _snack('Exported: $path', Colors.green);
                }
              } catch (e) {
                if (context.mounted) Navigator.pop(context);
                _snack('Export failed: $e', Colors.red);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.table_chart),
            title: const Text('Export to Excel'),
            subtitle: const Text('Download detailed Excel report'),
            onTap: () async {
              try {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) =>
                      const Center(child: CircularProgressIndicator()),
                );
                final transactions = await transactionService.getTransactionsList();
                final accounts = await accountService.getAccountsList().first;
                final path = await exportService.exportTransactionsToExcel(
                  transactions, accounts,
                  includeTransfers: true,
                  includeIncome: true,
                  includeExpense: true,
                );
                if (context.mounted) Navigator.pop(context);
                if (path != null) {
                  _snack('Exported: $path', Colors.green);
                }
              } catch (e) {
                if (context.mounted) Navigator.pop(context);
                _snack('Export failed: $e', Colors.red);
              }
            },
          ),
          const Divider(),

          // ── About ────────────────────────────────────────────────────────────
          _header('About'),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('Version'),
            subtitle: Text('1.2.0 — Smart Dashboard + AI Scanner'),
          ),
          const ListTile(
            leading: Icon(Icons.account_balance_wallet),
            title: Text('Money Manager'),
            subtitle: Text('Track income, expenses & grow savings'),
          ),
          const ListTile(
            leading: Icon(Icons.person),
            title: Text('Developer'),
            subtitle: Text('Built by Jegan'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _header(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue)),
      );

  void _showGetKeyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🤖 Get Free Gemini API Key'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Follow these steps:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            _Step('1', 'Open Google AI Studio'),
            _Step('2', 'Go to: aistudio.google.com'),
            _Step('3', 'Sign in with your Google account'),
            _Step('4', 'Click "Get API Key" → "Create API Key"'),
            _Step('5', 'Copy the key (starts with AIza...)'),
            _Step('6', 'Paste it here and tap Save Key'),
            SizedBox(height: 10),
            Text(
              '✅ Free tier: 15 requests/min — more than enough!',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String text;
  const _Step(this.number, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(number,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}