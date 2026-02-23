import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/bill_reminder_service.dart';
import '../models/bill_reminder_model.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final _notifService = NotificationService();
  final _billService = BillReminderService();

  bool _billsEnabled = true;
  bool _overdueEnabled = true;
  bool _dailySummaryEnabled = true;
  bool _goalsEnabled = true;
  int _notifHour = 9;
  bool _loading = true;
  bool _permissionGranted = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final bills = await _notifService.getSetting('bills_enabled');
    final overdue = await _notifService.getSetting('overdue_enabled');
    final summary = await _notifService.getSetting('daily_summary_enabled');
    final goals = await _notifService.getSetting('goals_enabled');
    final hour = await _notifService.getNotifHour();

    setState(() {
      _billsEnabled = bills;
      _overdueEnabled = overdue;
      _dailySummaryEnabled = summary;
      _goalsEnabled = goals;
      _notifHour = hour;
      _loading = false;
    });
  }

  Future<void> _requestPermission() async {
    final granted = await _notifService.requestPermission();
    setState(() => _permissionGranted = granted);
    if (granted) {
      _showSnack('✅ Notifications enabled!', Colors.green);
    } else {
      _showSnack(
          '❌ Permission denied. Enable in phone settings.', Colors.red);
    }
  }

  Future<void> _saveAndReschedule() async {
    await _notifService.setSetting('bills_enabled', _billsEnabled);
    await _notifService.setSetting('overdue_enabled', _overdueEnabled);
    await _notifService.setSetting('daily_summary_enabled', _dailySummaryEnabled);
    await _notifService.setSetting('goals_enabled', _goalsEnabled);
    await _notifService.setNotifHour(_notifHour);

    // Reschedule bill reminders
    if (_billsEnabled || _overdueEnabled) {
      _billService.getBillReminders().first.then((bills) async {
        await _notifService.scheduleBillReminders(bills);
        final overdue = bills.where((b) => b.isActive && b.daysUntilDue <= 0).toList();
        if (_overdueEnabled && overdue.isNotEmpty) {
          await _notifService.showOverdueBillsAlert(overdue);
        }
      });
    }

    _showSnack('✅ Notification settings saved!', Colors.green);
  }

  Future<void> _sendTestNotification() async {
    if (kIsWeb) {
      _showSnack('❌ Notifications not supported on web. Test on Android APK.', Colors.orange);
      return;
    }
    await _notifService.showGoalMilestone(
      goalName: 'Test Goal',
      progressPercent: 50,
      notifId: 999,
    );
    _showSnack('🔔 Test notification sent! Check your notification bar.', Colors.blue);
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    ));
  }

  String _hourLabel(int hour) {
    final suffix = hour < 12 ? 'AM' : 'PM';
    final h = hour == 0 ? 12 : hour > 12 ? hour - 12 : hour;
    return '$h:00 $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        actions: [
          TextButton(
            onPressed: _saveAndReschedule,
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Web warning
                if (kIsWeb) ...[
                  _warningCard(
                    '🌐 Web Preview',
                    'Push notifications only work on the Android APK. '
                        'Build and install the APK to test notifications.',
                    Colors.orange,
                    isDark,
                  ),
                  const SizedBox(height: 16),
                ],

                // Permission card
                _buildPermissionCard(isDark),
                const SizedBox(height: 20),

                // Notification time
                _sectionTitle('⏰ Notification Time'),
                const SizedBox(height: 10),
                _buildTimeSelector(isDark),
                const SizedBox(height: 20),

                // Notification types
                _sectionTitle('🔔 Notification Types'),
                const SizedBox(height: 10),

                _buildToggleCard(
                  isDark: isDark,
                  emoji: '📅',
                  title: 'Bill Due Alerts',
                  subtitle:
                      'Get notified 1 day before and on the day a bill is due',
                  value: _billsEnabled,
                  color: const Color(0xFF1565C0),
                  onChanged: (v) {
                    setState(() => _billsEnabled = v);
                  },
                ),
                _buildToggleCard(
                  isDark: isDark,
                  emoji: '🚨',
                  title: 'Overdue Bill Alerts',
                  subtitle:
                      'Immediate alert when a bill becomes overdue',
                  value: _overdueEnabled,
                  color: Colors.red,
                  onChanged: (v) {
                    setState(() => _overdueEnabled = v);
                  },
                ),
                _buildToggleCard(
                  isDark: isDark,
                  emoji: '📊',
                  title: 'Daily Spending Summary',
                  subtitle:
                      'Daily summary of how much you spent vs your average',
                  value: _dailySummaryEnabled,
                  color: const Color(0xFF2E7D32),
                  onChanged: (v) {
                    setState(() => _dailySummaryEnabled = v);
                  },
                ),
                _buildToggleCard(
                  isDark: isDark,
                  emoji: '🎯',
                  title: 'Goal Milestones',
                  subtitle:
                      'Celebrate when you hit 50%, 75% and 100% of a goal',
                  value: _goalsEnabled,
                  color: const Color(0xFF6A1B9A),
                  onChanged: (v) {
                    setState(() => _goalsEnabled = v);
                  },
                ),

                const SizedBox(height: 20),

                // Test button
                _sectionTitle('🧪 Test'),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _sendTestNotification,
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('Send Test Notification'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sends a test notification to verify everything works.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Save button
                ElevatedButton.icon(
                  onPressed: _saveAndReschedule,
                  icon: const Icon(Icons.save),
                  label: const Text('Save & Schedule'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildPermissionCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_active,
                color: theme.colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Enable Notifications',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text(
                  kIsWeb
                      ? 'Only works on Android APK'
                      : 'Allow Money Manager to send alerts',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: kIsWeb ? null : _requestPermission,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Allow', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  ThemeData get theme => Theme.of(context);

  Widget _buildTimeSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Notify at',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              Text(
                _hourLabel(_notifHour),
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary),
              ),
            ],
          ),
          Slider(
            value: _notifHour.toDouble(),
            min: 7,
            max: 21,
            divisions: 14,
            label: _hourLabel(_notifHour),
            onChanged: (v) => setState(() => _notifHour = v.round()),
            activeColor: theme.colorScheme.primary,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('7 AM',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[500])),
              Text('12 PM',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[500])),
              Text('9 PM',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleCard({
    required bool isDark,
    required String emoji,
    required String title,
    required String subtitle,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: value ? color.withOpacity(0.12) : Colors.grey.withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: value ? null : Colors.grey)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[500], height: 1.3)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold));

  Widget _warningCard(
      String title, String body, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 13)),
                const SizedBox(height: 3),
                Text(body,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[600], height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}