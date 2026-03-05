// lib/screens/settings_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import 'app_lock_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth      = AuthService();
  final _firestore = FirebaseFirestore.instance;
  final _picker    = ImagePicker();

  String    _name         = '';
  String    _email        = '';
  String    _version      = '';
  bool      _loading      = true;
  bool      _photoLoading = false;
  Uint8List? _photoBytes;   // in-memory photo bytes

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final name    = await _auth.getUserName();
    final pkgInfo = await PackageInfo.fromPlatform().catchError((_) =>
        PackageInfo(appName: '', packageName: '', version: '1.3.0', buildNumber: ''));
    // Load profile photo from Firestore
    final uid = FirebaseAuth.instance.currentUser?.uid;
    Uint8List? photo;
    if (uid != null) {
      try {
        final doc = await _firestore.collection('users').doc(uid).get();
        final b64 = doc.data()?['photoBase64'] as String?;
        if (b64 != null && b64.isNotEmpty) {
          photo = base64Decode(b64);
        }
      } catch (_) {}
    }
    if (mounted) setState(() {
      _name        = name ?? _auth.currentUser?.displayName ?? 'User';
      _email       = _auth.currentUser?.email ?? '';
      _version     = pkgInfo.version;
      _photoBytes  = photo;
      _loading     = false;
    });
  }

  // ── Pick profile photo ────────────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    if (kIsWeb) {
      // Web: use HTML file input
      final input = html.FileUploadInputElement()
        ..accept = 'image/*'
        ..click();
      await input.onChange.first;
      if (input.files == null || input.files!.isEmpty) return;
      final file = input.files![0];
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;
      final bytes = reader.result as Uint8List?;
      if (bytes != null) await _savePhoto(bytes);
    } else {
      // Mobile: use image_picker
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400, maxHeight: 400,
        imageQuality: 70,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      await _savePhoto(bytes);
    }
  }

  Future<void> _takePhoto() async {
    if (kIsWeb) { _pickPhoto(); return; }
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 400, maxHeight: 400,
      imageQuality: 70,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    await _savePhoto(bytes);
  }

  Future<void> _savePhoto(Uint8List bytes) async {
    // Limit size to 500KB
    if (bytes.lengthInBytes > 500 * 1024) {
      _snack('Image too large. Please choose a smaller image.', false);
      return;
    }
    setState(() => _photoLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not logged in');
      final b64 = base64Encode(bytes);
      await _firestore.collection('users').doc(uid).set(
        {'photoBase64': b64}, SetOptions(merge: true));
      if (mounted) {
        setState(() { _photoBytes = bytes; _photoLoading = false; });
        _snack('Profile photo updated ✅', true);
      }
    } catch (e) {
      if (mounted) { setState(() => _photoLoading = false); _snack('Error: $e', false); }
    }
  }

  Future<void> _removePhoto() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _photoLoading = true);
    try {
      await _firestore.collection('users').doc(uid).set(
        {'photoBase64': ''}, SetOptions(merge: true));
      if (mounted) {
        setState(() { _photoBytes = null; _photoLoading = false; });
        _snack('Photo removed', true);
      }
    } catch (e) {
      if (mounted) { setState(() => _photoLoading = false); _snack('Error: $e', false); }
    }
  }

  // ── Photo picker sheet ────────────────────────────────────────────────────
  void _showPhotoOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2530) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text('Profile Photo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (!kIsWeb) ...[
            _photoOption(Icons.camera_alt_rounded, 'Take Photo', Colors.blue,
                () { Navigator.pop(ctx); _takePhoto(); }),
            const SizedBox(height: 8),
          ],
          _photoOption(Icons.photo_library_rounded, 'Choose from Gallery',
              const Color(0xFF667eea),
              () { Navigator.pop(ctx); _pickPhoto(); }),
          if (_photoBytes != null) ...[
            const SizedBox(height: 8),
            _photoOption(Icons.delete_outline_rounded, 'Remove Photo',
                Colors.red,
                () { Navigator.pop(ctx); _removePhoto(); }),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _photoOption(IconData icon, String label, Color color, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(
                fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      );

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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2530) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              const Text('Edit Profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              // Avatar
              GestureDetector(
                onTap: () { Navigator.pop(ctx); _showPhotoOptions(); },
                child: Stack(children: [
                  _buildAvatar(radius: 40),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 6),
              Text('Tap to change photo',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
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
                width: double.infinity, height: 48,
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
                        _snack('Profile updated ✅', true);
                      }
                    } catch (e) {
                      setSheetState(() { saving = false; error = 'Failed: $e'; });
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

  // ── Avatar widget (shared) ────────────────────────────────────────────────
  Widget _buildAvatar({double radius = 28}) {
    if (_photoLoading) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF667eea).withOpacity(0.15),
        child: SizedBox(
          width: radius, height: radius,
          child: const CircularProgressIndicator(
              strokeWidth: 2, color: Color(0xFF667eea)),
        ),
      );
    }
    if (_photoBytes != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(_photoBytes!),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF667eea).withOpacity(0.15),
      child: Text(
        (_name.isNotEmpty ? _name[0] : 'U').toUpperCase(),
        style: TextStyle(
            fontSize: radius * 0.7,
            color: const Color(0xFF667eea),
            fontWeight: FontWeight.bold),
      ),
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
        _snack('Logout failed: $e', false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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

              // ── Profile card ────────────────────────────────────────
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
                    // Avatar with tap-to-change
                    GestureDetector(
                      onTap: _showPhotoOptions,
                      child: Stack(children: [
                        _buildAvatar(radius: 28),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            width: 18, height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xFF667eea),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                color: Colors.white, size: 10),
                          ),
                        ),
                      ]),
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
                    IconButton(
                      onPressed: _showEditProfile,
                      icon: const Icon(Icons.edit_outlined,
                          color: Color(0xFF667eea)),
                      tooltip: 'Edit profile',
                    ),
                  ]),
                ),
              ),

              // ── Logout ──────────────────────────────────────────────
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
                          content: const Text(
                              'Are you sure you want to logout?'),
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
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.grey.shade100),
                _aboutTile(
                  icon: Icons.new_releases_outlined,
                  iconColor: Colors.green,
                  title: 'Version',
                  subtitle: _version.isEmpty ? '1.3.0' : _version,
                  isDark: isDark,
                ),
                Divider(height: 1, indent: 60,
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.grey.shade100),
                _aboutTile(
                  icon: Icons.person_rounded,
                  iconColor: Colors.orange,
                  title: 'Developer',
                  subtitle: 'Jegan — Built with Flutter & Firebase',
                  isDark: isDark,
                ),
                Divider(height: 1, indent: 60,
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.grey.shade100),
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

  void _snack(String msg, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }
}