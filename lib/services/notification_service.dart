// lib/services/notification_service.dart
// FCM Push Notifications — saves token to Firestore, handles messages

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ── Top-level background handler (REQUIRED outside class) ────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage msg) async {
  // Handle background message (app closed / in background)
  print('📩 Background message: ${msg.notification?.title}');
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _db        = FirebaseFirestore.instance;
  static final _localNotif = FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // ── Initialise once on app start ────────────────────────────────────────────
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request permission
    await _messaging.requestPermission(
      alert: true, badge: true, sound: true);

    // Local notifications (Android)
    if (!kIsWeb) {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      await _localNotif.initialize(
        const InitializationSettings(
            android: androidSettings, iOS: iosSettings),
      );

      // Create high-priority notification channel
      const channel = AndroidNotificationChannel(
        'money_manager_updates',
        'App Updates',
        description: 'Important update notifications from Money Manager',
        importance: Importance.high,
        playSound: true,
      );
      await _localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // Foreground message handler
    FirebaseMessaging.onMessage.listen((msg) {
      _showLocalNotification(msg);
    });

    // Save FCM token whenever it refreshes
    _messaging.onTokenRefresh.listen(_saveToken);

    // Save token on first launch
    await _saveFcmToken();
  }

  // ── Save token to Firestore user doc ────────────────────────────────────────
  static Future<void> _saveFcmToken() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      String? token;
      if (kIsWeb) {
        // Web FCM needs VAPID key — skip for now if not configured
        try {
          token = await _messaging.getToken(
              vapidKey: 'YOUR_VAPID_KEY_HERE');
        } catch (_) {
          return;
        }
      } else {
        token = await _messaging.getToken();
      }

      if (token == null) return;
      await _saveToken(token);
    } catch (_) {}
  }

  static Future<void> _saveToken(String token) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await _db.collection('users').doc(uid).set({
        'fcmToken':       token,
        'fcmUpdatedAt':   FieldValue.serverTimestamp(),
        'platform':       kIsWeb ? 'web' : 'mobile',
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Show local notification when app is in foreground ───────────────────────
  static Future<void> _showLocalNotification(RemoteMessage msg) async {
    if (kIsWeb) return;
    final notif = msg.notification;
    if (notif == null) return;

    await _localNotif.show(
      notif.hashCode,
      notif.title ?? 'Money Manager',
      notif.body  ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'money_manager_updates',
          'App Updates',
          channelDescription: 'Important update notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  // ── Subscribe / Unsubscribe topics ──────────────────────────────────────────
  static Future<void> subscribeToUpdates() async {
    if (!kIsWeb) {
      await _messaging.subscribeToTopic('app_updates');
    }
  }

  static Future<void> unsubscribeFromUpdates() async {
    if (!kIsWeb) {
      await _messaging.unsubscribeFromTopic('app_updates');
    }
  }

  // ── Admin: send update notification to all users via Firestore trigger ───────
  // This writes to Firestore; a Cloud Function or Admin SDK sends the actual push.
  static Future<void> sendUpdateNotification({
    required String title,
    required String body,
    String? updateUrl,
  }) async {
    await _db.collection('notifications_queue').add({
      'title':      title,
      'body':       body,
      'topic':      'app_updates',
      'type':       'force_update',
      'update_url': updateUrl ?? '',
      'created_at': FieldValue.serverTimestamp(),
      'sent':       false,
    });
  }
}