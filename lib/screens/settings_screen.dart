// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import 'app_lock_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth    = AuthService();
  String _name   = '';
  String _email  = '';
  String _version = '';
  bool   _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final name    = await _auth.getUserName();
    final pkgInfo = await PackageInfo.fromPlatform().catchError((_) =>
        PackageInfo(appName: '', packageName: '', version: '1.3.0', buildNumber: ''));
    if (mounted) setState(() {
      _name    = name ?? _auth.currentUser?.displayName ?? 'User';
      _email   = _auth.currentUser?.email ?? '';
      _version = pkgInfo.version;
      _loading  = false;
    });
  }

  // ── Edit Profile ─────────────────────────────────────────────────────────
  void _showEditProfile() {
    final nameCtrl = TextEditingController(text: _name);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        bool saving = false;
        String? error;
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              const Text('Edit Profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              // Avatar initial
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFF667eea).withOpacity(0.15),
                child: Text(
                  (_name.isNotEmpty ? _name[0] : 'U').toUpperCase(),
                  style: const TextStyle(
                      fontSize: 28, color: Color(0xFF667eea),
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
                textCapitalization: TextCapitalization.words,
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
              const SizedBox(height: 12),
              // Email (read-only)
              TextField(
                enabled: false,
                controller: TextEditingController(text: _email),
                decoration: InputDecoration(
                  labelText: 'Email (cannot change)',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: saving ? null : () async {
                    final newName = nameCtrl.text.trim();
                    if (newName.isEmpty) {
                      setSheetState(() => error = 'Name cannot be empty');
                      return;
                    }
                    setSheetState(() { saving = true; error = null; });
                    try {
                      await _auth.updateUserName(newName);
                      if (mounted) {
                        setState(() => _name = newName);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Profile updated ✅'),
                              backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      setSheetState(() {
                        saving = false;
                        error  = 'Failed to update: $e';
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: saving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Save Changes',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> _performLogout() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      await _auth.signOut();
      if (!mounted) return;
      if (kIsWeb) {
        html.window.location.reload();
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      if (kIsWeb) {
        html.window.location.reload();
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Logout failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1E2530) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(children: [

              // ── Profile card ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2530) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF667eea).withOpacity(0.15),
                      child: Text(
                        (_name.isNotEmpty ? _name[0] : 'U').toUpperCase(),
                        style: const TextStyle(
                            fontSize: 22, color: Color(0xFF667eea),
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_name, style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(_email, style: TextStyle(
                            color: Colors.grey[500], fontSize: 12)),
                      ],
                    )),
                    // Edit profile button
                    IconButton(
                      onPressed: _showEditProfile,
                      icon: const Icon(Icons.edit_outlined,
                          color: Color(0xFF667eea)),
                      tooltip: 'Edit profile',
                    ),
                  ]),
                ),
              ),

              // ── Logout ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2530) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.logout_rounded,
                          color: Colors.red, size: 18),
                    ),
                    title: const Text('Logout',
                        style: TextStyle(color: Colors.red,
                            fontWeight: FontWeight.w600)),
                    subtitle: const Text('Sign out of your account'),
                    trailing: const Icon(Icons.chevron_right,
                        color: Colors.red, size: 18),
                    onTap: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Logout'),
                          content: const Text('Are you sure you want to logout?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white),
                              child: const Text('Logout')),
                          ],
                        ),
                      );
                      if (ok == true) _performLogout();
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),
              _sectionHeader('Appearance', isDark),

              // ── Dark Mode ─────────────────────────────────────────────
              _card(isDark, child: SwitchListTile(
                secondary: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    color: Colors.indigo, size: 18),
                ),
                title: const Text('Dark Mode',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Switch between light and dark theme'),
                value: themeProvider.isDarkMode,
                activeColor: const Color(0xFF667eea),
                onChanged: (_) => themeProvider.toggleTheme(),
              )),

              const SizedBox(height: 20),
              _sectionHeader('Security', isDark),
              _card(isDark, child: const BiometricSettingsTile()),

              const SizedBox(height: 20),
              _sectionHeader('About', isDark),
              _card(isDark, child: Column(children: [
                _aboutTile(
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: const Color(0xFF667eea),
                  title: 'Money Manager',
                  subtitle: 'Smart Personal Finance Tracker',
                  isDark: isDark,
                ),
                Divider(height: 1, indent: 60,
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100),
                _aboutTile(
                  icon: Icons.new_releases_outlined,
                  iconColor: Colors.green,
                  title: 'Version',
                  subtitle: _version.isEmpty ? '1.3.0' : _version,
                  isDark: isDark,
                ),
                Divider(height: 1, indent: 60,
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100),
                _aboutTile(
                  icon: Icons.person_rounded,
                  iconColor: Colors.orange,
                  title: 'Developer',
                  subtitle: 'Jegan — Built with Flutter & Firebase',
                  isDark: isDark,
                ),
                Divider(height: 1, indent: 60,
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100),
                _aboutTile(
                  icon: Icons.privacy_tip_outlined,
                  iconColor: Colors.blue,
                  title: 'Privacy',
                  subtitle: 'Your data stays on your device & Firebase',
                  isDark: isDark,
                ),
              ])),

              const SizedBox(height: 32),
            ]),
    );
  }

  Widget _sectionHeader(String title, bool isDark) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
    child: Text(title, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.bold,
        color: isDark ? Colors.white54 : Colors.grey[500],
        letterSpacing: 0.8)),
  );

  Widget _card(bool isDark, {required Widget child}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    ),
  );

  Widget _aboutTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
  }) =>
      ListTile(
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 11,
                color: isDark ? Colors.white54 : Colors.grey[500])),
      );
}