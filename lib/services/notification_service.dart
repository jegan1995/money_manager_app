import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/bill_reminder_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── Notification IDs (reserved ranges) ──────────────────────────────────────
  // 1000–1999 : Bill reminders
  // 2000      : Daily spending summary
  // 3000–3999 : Goal milestones
  // 4000      : Overdue bills summary

  // ── Channel IDs ──────────────────────────────────────────────────────────────
  static const _billChannelId = 'bill_reminders';
  static const _billChannelName = 'Bill Reminders';
  static const _summaryChannelId = 'daily_summary';
  static const _summaryChannelName = 'Daily Summary';
  static const _goalChannelId = 'goal_milestones';
  static const _goalChannelName = 'Goal Milestones';
  static const _overdueChannelId = 'overdue_bills';
  static const _overdueChannelName = 'Overdue Bills';

  // ── Initialize ───────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (kIsWeb) return; // Notifications not supported on web
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android notification channels
    await _createChannels();

    _initialized = true;
  }

  Future<void> _createChannels() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _billChannelId,
        _billChannelName,
        description: 'Reminders for upcoming bill due dates',
        importance: Importance.high,
        enableVibration: true,
      ),
    );
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _summaryChannelId,
        _summaryChannelName,
        description: 'Daily spending summary',
        importance: Importance.defaultImportance,
      ),
    );
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _goalChannelId,
        _goalChannelName,
        description: 'Goal completion milestones',
        importance: Importance.high,
        enableVibration: true,
      ),
    );
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _overdueChannelId,
        _overdueChannelName,
        description: 'Overdue bill alerts',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
      ),
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    // Navigation can be wired up later via GlobalKey<NavigatorState>
  }

  // ── Permission ───────────────────────────────────────────────────────────────
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted =
          await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  // ── Settings helpers ─────────────────────────────────────────────────────────
  Future<bool> getSetting(String key, {bool defaultValue = true}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notif_$key') ?? defaultValue;
  }

  Future<void> setSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_$key', value);
  }

  Future<int> getNotifHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('notif_hour') ?? 9;
  }

  Future<void> setNotifHour(int hour) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notif_hour', hour);
  }

  // ── Bill Reminder Notifications ──────────────────────────────────────────────
  Future<void> scheduleBillReminders(
      List<BillReminderModel> bills) async {
    if (kIsWeb) return;
    final enabled = await getSetting('bills_enabled');
    if (!enabled) return;

    final hour = await getNotifHour();

    // Cancel all existing bill notifications
    for (int i = 1000; i < 2000; i++) {
      await _plugin.cancel(i);
    }

    int notifId = 1000;
    for (final bill in bills) {
      if (!bill.isActive || bill.nextDueDate == null) continue;

      final daysUntil = bill.daysUntilDue;

      // Day-before reminder
      if (daysUntil == 1 || daysUntil > 1) {
        final dayBefore = bill.nextDueDate!.subtract(const Duration(days: 1));
        final scheduleTime = _todayAt(dayBefore, hour, 0);
        if (scheduleTime.isAfter(DateTime.now())) {
          await _scheduleNotification(
            id: notifId++,
            channelId: _billChannelId,
            channelName: _billChannelName,
            title: '⏰ Bill Due Tomorrow',
            body: '${bill.name} — ₹${bill.amount.toStringAsFixed(0)} due tomorrow',
            scheduledDate: scheduleTime,
          );
        }
      }

      // Due-day reminder
      if (daysUntil == 0 || daysUntil > 0) {
        final dueDay = bill.nextDueDate!;
        final scheduleTime = _todayAt(dueDay, hour, 0);
        if (scheduleTime.isAfter(DateTime.now())) {
          await _scheduleNotification(
            id: notifId++,
            channelId: _billChannelId,
            channelName: _billChannelName,
            title: '🔴 Bill Due Today!',
            body: '${bill.name} — ₹${bill.amount.toStringAsFixed(0)} is due today',
            scheduledDate: scheduleTime,
          );
        }
      }

      if (notifId >= 2000) break; // Safety limit
    }
  }

  // ── Overdue Bill Alert ────────────────────────────────────────────────────────
  Future<void> showOverdueBillsAlert(
      List<BillReminderModel> overdueBills) async {
    if (kIsWeb) return;
    final enabled = await getSetting('overdue_enabled');
    if (!enabled || overdueBills.isEmpty) return;

    final names = overdueBills.take(3).map((b) => b.name).join(', ');
    final totalAmount = overdueBills.fold(0.0, (s, b) => s + b.amount);

    await _showImmediate(
      id: 4000,
      channelId: _overdueChannelId,
      channelName: _overdueChannelName,
      title:
          '🚨 ${overdueBills.length} Bill${overdueBills.length > 1 ? 's' : ''} Overdue!',
      body:
          '$names — Total: ₹${totalAmount.toStringAsFixed(0)} overdue. Pay now!',
    );
  }

  // ── Daily Spending Summary ───────────────────────────────────────────────────
  Future<void> scheduleDailySummary({
    required double todaySpend,
    required double avgDailySpend,
    required int hour,
  }) async {
    if (kIsWeb) return;
    final enabled = await getSetting('daily_summary_enabled');
    if (!enabled) return;

    await _plugin.cancel(2000);

    final diff = todaySpend - avgDailySpend;
    final isOver = diff > 0;
    final emoji = isOver ? '📈' : '✅';
    final comparison = isOver
        ? '₹${diff.toStringAsFixed(0)} above average'
        : '₹${diff.abs().toStringAsFixed(0)} below average';

    final now = DateTime.now();
    var scheduleTime = DateTime(now.year, now.month, now.day, hour, 0);
    if (scheduleTime.isBefore(now)) {
      scheduleTime = scheduleTime.add(const Duration(days: 1));
    }

    await _scheduleNotification(
      id: 2000,
      channelId: _summaryChannelId,
      channelName: _summaryChannelName,
      title: '$emoji Today\'s Spending: ₹${todaySpend.toStringAsFixed(0)}',
      body: '$comparison. Keep tracking!',
      scheduledDate: scheduleTime,
    );
  }

  // ── Goal Milestone ───────────────────────────────────────────────────────────
  Future<void> showGoalMilestone({
    required String goalName,
    required double progressPercent,
    required int notifId,
  }) async {
    if (kIsWeb) return;
    final enabled = await getSetting('goals_enabled');
    if (!enabled) return;

    String title;
    String body;

    if (progressPercent >= 100) {
      title = '🎉 Goal Completed!';
      body = 'You\'ve reached your "$goalName" goal. Congratulations!';
    } else if (progressPercent >= 75) {
      title = '🔥 Almost There!';
      body =
          '"$goalName" is ${progressPercent.toStringAsFixed(0)}% complete. Just a little more!';
    } else if (progressPercent >= 50) {
      title = '💪 Halfway There!';
      body =
          '"$goalName" is 50% complete. Keep going!';
    } else {
      title = '⭐ Goal Progress';
      body =
          '"$goalName" is ${progressPercent.toStringAsFixed(0)}% complete.';
    }

    await _showImmediate(
      id: 3000 + notifId,
      channelId: _goalChannelId,
      channelName: _goalChannelName,
      title: title,
      body: body,
    );
  }

  // ── Cancel all ───────────────────────────────────────────────────────────────
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }

  // ── Low-level helpers ────────────────────────────────────────────────────────
  Future<void> _scheduleNotification({
    required int id,
    required String channelId,
    required String channelName,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _showImmediate({
    required int id,
    required String channelId,
    required String channelName,
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  DateTime _todayAt(DateTime date, int hour, int minute) {
    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}