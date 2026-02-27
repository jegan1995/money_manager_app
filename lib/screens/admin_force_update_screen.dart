// lib/screens/admin_force_update_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/force_update_service.dart';
import '../services/notification_service.dart';

class AdminForceUpdateScreen extends StatefulWidget {
  const AdminForceUpdateScreen({super.key});
  @override
  State<AdminForceUpdateScreen> createState() => _AdminForceUpdateScreenState();
}

class _AdminForceUpdateScreenState extends State<AdminForceUpdateScreen> {
  final _db = FirebaseFirestore.instance;

  final _minVersionCtrl     = TextEditingController();
  final _curVersionCtrl     = TextEditingController();
  final _messageCtrl        = TextEditingController();
  final _urlCtrl            = TextEditingController();
  final _whatsNewCtrl       = TextEditingController();
  final _notifTitleCtrl     = TextEditingController(text: 'Update Required 🚀');
  final _notifBodyCtrl      = TextEditingController();

  // ── local UI state — NEVER touched by any stream or async rebuild ──────────
  bool _forceUpdate = false;
  bool _softUpdate  = false;
  bool _loading     = false;
  bool _ready       = false;       // show spinner until first load done

  // saved Firestore state for the status banner
  bool   _firestoreForce = false;
  bool   _firestoreSoft  = false;
  String _firestoreMin   = '';
  String _firestoreAt    = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _minVersionCtrl.dispose();  _curVersionCtrl.dispose();
    _messageCtrl.dispose();     _urlCtrl.dispose();
    _whatsNewCtrl.dispose();    _notifTitleCtrl.dispose();
    _notifBodyCtrl.dispose();
    super.dispose();
  }

  // ── One-shot load from Firestore ────────────────────────────────────────────
  Future<void> _load() async {
    try {
      final snap = await _db.collection('app_config').doc('version').get();
      if (!mounted) return;
      if (snap.exists) {
        final d = snap.data()!;
        setState(() {
          _minVersionCtrl.text  = d['min_version']     ?? '1.2.0';
          _curVersionCtrl.text  = d['current_version'] ?? '1.2.0';
          _messageCtrl.text     = d['update_message']  ?? 'Please update Money Manager to continue.';
          _urlCtrl.text         = d['update_url']      ?? '';
          _whatsNewCtrl.text    = d['whats_new']       ?? '';
          // set local toggles from Firestore only on first load
          _forceUpdate          = d['force_update']    ?? false;
          _softUpdate           = d['soft_update']     ?? false;
          // cache for status banner
          _firestoreForce       = d['force_update']    ?? false;
          _firestoreSoft        = d['soft_update']     ?? false;
          _firestoreMin         = d['min_version']     ?? '–';
          if (d['updated_at'] != null) {
            _firestoreAt = DateFormat('dd MMM yyyy  HH:mm')
                .format((d['updated_at'] as dynamic).toDate());
          }
          _ready = true;
        });
      } else {
        setState(() {
          _minVersionCtrl.text = '1.2.0';
          _curVersionCtrl.text = '1.2.0';
          _ready = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _ready = true);
    }
  }

  // ── Reload from Firestore (refresh button) ──────────────────────────────────
  Future<void> _reload() async {
    setState(() { _ready = false; });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4FF);
    final card   = isDark ? const Color(0xFF1E2530) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: const Text('Force Update Control',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload from Firestore',
            onPressed: _reload,
          ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              children: [

                // ── Firestore status banner ─────────────────────────────────
                _StatusBanner(
                  firestoreForce: _firestoreForce,
                  firestoreSoft:  _firestoreSoft,
                  minVersion:     _firestoreMin,
                  updatedAt:      _firestoreAt,
                  isDark:         isDark,
                ),
                const SizedBox(height: 20),

                // ── Version numbers ─────────────────────────────────────────
                _sectionLabel('Version Numbers', isDark),
                const SizedBox(height: 8),
                _card(card, isDark, [
                  _inputRow(_minVersionCtrl, 'Minimum Required Version',
                      '1.3.0', Icons.verified_outlined,
                      helper: 'Users BELOW this version will be blocked'),
                  _divider(isDark),
                  _inputRow(_curVersionCtrl, 'Latest App Version',
                      '1.3.0', Icons.new_releases_outlined,
                      helper: 'The version you just released'),
                ]),

                const SizedBox(height: 20),

                // ── Toggle: Force Update ────────────────────────────────────
                _sectionLabel('Update Mode', isDark),
                const SizedBox(height: 8),

                // FORCE UPDATE
                _ToggleRow(
                  icon: Icons.block_rounded,
                  iconColor: Colors.red,
                  title: 'Force Update',
                  subtitle: 'Completely blocks the app until user updates.\nCannot be dismissed.',
                  value: _forceUpdate,
                  activeColor: Colors.red,
                  card: card,
                  isDark: isDark,
                  onChanged: (v) {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      _forceUpdate = v;
                      if (v) _softUpdate = false;
                    });
                  },
                ),
                const SizedBox(height: 8),

                // SOFT UPDATE
                _ToggleRow(
                  icon: Icons.notifications_active_outlined,
                  iconColor: Colors.orange,
                  title: 'Soft Update',
                  subtitle: 'Shows a banner that users can dismiss.\nApp still works.',
                  value: _softUpdate,
                  activeColor: Colors.orange,
                  card: card,
                  isDark: isDark,
                  onChanged: (v) {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      _softUpdate = v;
                      if (v) _forceUpdate = false;
                    });
                  },
                ),

                if (_forceUpdate) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        '⚠️  Force Update is ON locally. '
                        'Press "Apply Force Update" below to save and activate for all users.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.red[700]),
                      )),
                    ]),
                  ),
                ],

                const SizedBox(height: 20),

                // ── Message content ─────────────────────────────────────────
                _sectionLabel('Update Message Content', isDark),
                const SizedBox(height: 8),
                _card(card, isDark, [
                  _inputRow(_messageCtrl, 'Update Message',
                      'A new version is available. Please update to continue.',
                      Icons.message_outlined, maxLines: 3),
                  _divider(isDark),
                  _inputRow(_whatsNewCtrl, "What's New",
                      '• Bug fixes\n• Performance improvements',
                      Icons.new_releases_outlined, maxLines: 4),
                  _divider(isDark),
                  _inputRow(_urlCtrl, 'Play Store URL',
                      'https://play.google.com/store/apps/details?id=com.jegan.money_manager_app',
                      Icons.link),
                ]),

                const SizedBox(height: 20),

                // ── Apply / Clear ───────────────────────────────────────────
                _BigButton(
                  label: _forceUpdate
                      ? '🔴  Apply Force Update'
                      : _softUpdate
                          ? '🟡  Apply Soft Update'
                          : '💾  Save Settings',
                  color: _forceUpdate
                      ? Colors.red
                      : _softUpdate ? Colors.orange : const Color(0xFF667eea),
                  loading: _loading,
                  onTap: _apply,
                ),
                const SizedBox(height: 10),
                _BigButton(
                  label: '🟢  Clear All Update Restrictions',
                  color: const Color(0xFF2E7D32),
                  loading: _loading,
                  onTap: _clear,
                ),

                const SizedBox(height: 28),

                // ── Push notification ───────────────────────────────────────
                _sectionLabel('Push Notification to All Users', isDark),
                const SizedBox(height: 8),
                _card(card, isDark, [
                  _inputRow(_notifTitleCtrl, 'Notification Title',
                      'Update Required 🚀', Icons.title),
                  _divider(isDark),
                  _inputRow(_notifBodyCtrl, 'Notification Body',
                      'Please update Money Manager to the latest version.',
                      Icons.text_fields, maxLines: 3),
                ]),
                const SizedBox(height: 10),
                _BigButton(
                  label: '📩  Send Push Notification',
                  color: const Color(0xFF1A237E),
                  loading: _loading,
                  onTap: _sendPush,
                ),
                const SizedBox(height: 10),
                Text(
                  'ℹ️  This queues the notification in Firestore. '
                  'A Firebase Cloud Function is needed to actually send FCM push to devices.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _apply() async {
    final minV = _minVersionCtrl.text.trim();
    final curV = _curVersionCtrl.text.trim();
    if (minV.isEmpty || curV.isEmpty) {
      _snack('Please fill in both version fields', false); return;
    }
    setState(() => _loading = true);
    try {
      if (_forceUpdate) {
        await ForceUpdateService.setForceUpdate(
          minVersion:     minV,
          currentVersion: curV,
          updateMessage:  _messageCtrl.text.trim().isEmpty
              ? 'Please update Money Manager to continue.'
              : _messageCtrl.text.trim(),
          updateUrl: _urlCtrl.text.trim(),
          whatsNew:  _whatsNewCtrl.text.trim(),
        );
      } else if (_softUpdate) {
        await ForceUpdateService.setSoftUpdate(
          currentVersion: curV,
          updateUrl: _urlCtrl.text.trim(),
          whatsNew:  _whatsNewCtrl.text.trim(),
        );
        await _db.collection('app_config').doc('version').set({
          'min_version':    minV,
          'update_message': _messageCtrl.text.trim(),
        }, SetOptions(merge: true));
      } else {
        await _db.collection('app_config').doc('version').set({
          'min_version':     minV,
          'current_version': curV,
          'update_message':  _messageCtrl.text.trim(),
          'update_url':      _urlCtrl.text.trim(),
          'whats_new':       _whatsNewCtrl.text.trim(),
          'force_update':    false,
          'soft_update':     false,
          'updated_at':      FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      // Refresh status banner after save
      setState(() {
        _firestoreForce = _forceUpdate;
        _firestoreSoft  = _softUpdate;
        _firestoreMin   = minV;
        _firestoreAt    = DateFormat('dd MMM yyyy  HH:mm').format(DateTime.now());
      });
      _snack('Saved to Firestore ✅', true);
    } catch (e) {
      _snack('Error: $e', false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All Updates'),
        content: const Text(
            'All users can continue with their current version. '
            'No one will be blocked or prompted to update.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ForceUpdateService.clearUpdate();
    setState(() {
      _forceUpdate    = false;
      _softUpdate     = false;
      _firestoreForce = false;
      _firestoreSoft  = false;
      _firestoreAt    = DateFormat('dd MMM yyyy  HH:mm').format(DateTime.now());
    });
    _snack('All update restrictions cleared ✅', true);
  }

  Future<void> _sendPush() async {
    if (_notifTitleCtrl.text.trim().isEmpty || _notifBodyCtrl.text.trim().isEmpty) {
      _snack('Enter both notification title and body', false); return;
    }
    try {
      await NotificationService.sendUpdateNotification(
        title:     _notifTitleCtrl.text.trim(),
        body:      _notifBodyCtrl.text.trim(),
        updateUrl: _urlCtrl.text.trim(),
      );
      _snack('Notification queued ✅', true);
    } catch (e) {
      _snack('Error: $e', false);
    }
  }

  // ── UI helpers ────────────────────────────────────────────────────────────
  Widget _sectionLabel(String t, bool isDark) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(t.toUpperCase(),
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold,
                color: Colors.grey[500], letterSpacing: 1.1)),
      );

  Widget _card(Color card, bool isDark, List<Widget> children) =>
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
      height: 1, indent: 16,
      color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100);

  Widget _inputRow(TextEditingController ctrl, String label, String hint,
      IconData icon, {int maxLines = 1, String? helper}) =>
      TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          prefixIcon: Icon(icon, size: 18, color: Colors.grey[400]),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );

  void _snack(String msg, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? const Color(0xFF2E7D32) : Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    ));
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _ToggleRow — a self-contained toggle widget with NO external stream
// Tapping anywhere on the row (or the switch) toggles the value.
// ════════════════════════════════════════════════════════════════════════════
class _ToggleRow extends StatelessWidget {
  final IconData  icon;
  final Color     iconColor;
  final String    title;
  final String    subtitle;
  final bool      value;
  final Color     activeColor;
  final Color     card;
  final bool      isDark;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.activeColor,
    required this.card,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Tap anywhere on the row to toggle
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value
                ? activeColor.withOpacity(0.4)
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [BoxShadow(
              color: value
                  ? activeColor.withOpacity(0.08)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 8)],
        ),
        child: Row(children: [
          // Icon box
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: (value ? activeColor : Colors.grey)
                  .withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon,
                color: value ? activeColor : Colors.grey[400],
                size: 20),
          ),
          const SizedBox(width: 14),

          // Text
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: value ? activeColor : null)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      height: 1.4)),
            ],
          )),

          // Switch — also wired up, in case user taps only the switch
          Switch(
            value: value,
            activeColor: activeColor,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _StatusBanner — pure display, receives values as constructor args (no stream)
// ════════════════════════════════════════════════════════════════════════════
class _StatusBanner extends StatelessWidget {
  final bool   firestoreForce;
  final bool   firestoreSoft;
  final String minVersion;
  final String updatedAt;
  final bool   isDark;

  const _StatusBanner({
    required this.firestoreForce,
    required this.firestoreSoft,
    required this.minVersion,
    required this.updatedAt,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = firestoreForce
        ? Colors.red
        : firestoreSoft ? Colors.orange : const Color(0xFF2E7D32);
    final text = firestoreForce
        ? '🔴  FORCE UPDATE ACTIVE — old users are blocked'
        : firestoreSoft
            ? '🟡  SOFT UPDATE ACTIVE — banner shown to users'
            : '🟢  NO UPDATES ACTIVE — all users can use the app';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12, color: color)),
        if (minVersion.isNotEmpty || updatedAt.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            if (minVersion.isNotEmpty)
              _chip('Min Version', minVersion, Colors.grey),
            if (updatedAt.isNotEmpty)
              _chip('Last Saved', updatedAt, Colors.grey),
          ]),
        ],
        const SizedBox(height: 8),
        Text(
          'ℹ️  This shows the LIVE status in Firestore. '
          'Toggle above, then press Apply to change it.',
          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }

  Widget _chip(String label, String value, Color color) =>
      Column(children: [
        Text(label,
            style: TextStyle(fontSize: 9, color: Colors.grey[500])),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 11)),
      ]);
}

// ════════════════════════════════════════════════════════════════════════════
// _BigButton — simple full-width button
// ════════════════════════════════════════════════════════════════════════════
class _BigButton extends StatelessWidget {
  final String   label;
  final Color    color;
  final bool     loading;
  final VoidCallback onTap;

  const _BigButton({
    required this.label,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }
}