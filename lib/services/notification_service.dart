import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔥 FCM Background Message received: ${message.messageId}');
}

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // ---------------------------------------------------------------------------
  // ✅ INITIALIZE FIREBASE CLOUD MESSAGING (FCM)
  // ---------------------------------------------------------------------------
  static Future<void> init() async {
    // 1. Setup local display banner channel for when app is in Foreground
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(settings: settings);

    // 2. Request FCM permissions from OS
    final notificationSettings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('🔥 FCM Permission: ${notificationSettings.authorizationStatus}');

    // 3. Register background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Foreground FCM Listener: Displays incoming FCM push directly to user
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔥 FCM Foreground Message: ${message.notification?.title}');
      final notification = message.notification;
      if (notification != null) {
        _displayForegroundFCM(
          title: notification.title ?? 'StreakUP Alert',
          body: notification.body ?? '',
        );
      }
    });

    // 5. Save FCM Device Token & Subscribe to general topics
    await _syncDeviceToken();

    // Subscribe to topics for automatic cloud broadcasts
    try {
      await _firebaseMessaging.subscribeToTopic('daily_reminders');
      await _firebaseMessaging.subscribeToTopic('water_reminders');
    } catch (e) {
      debugPrint('FCM topic subscription error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 🔑 SYNC FCM TOKEN TO USER PROFILE IN FIRESTORE
  // ---------------------------------------------------------------------------
  static Future<void> _syncDeviceToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        debugPrint('==================================================');
        debugPrint('🔥 ACTIVE FCM DEVICE TOKEN:');
        debugPrint(token);
        debugPrint('==================================================');

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'fcmToken': token,
            'fcmUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      // Listen for token refreshes
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'fcmToken': newToken,
            'fcmUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      });
    } catch (e) {
      debugPrint('Error syncing FCM token: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 🔔 DISPLAY FOREGROUND FCM BANNER
  // ---------------------------------------------------------------------------
  static Future<void> _displayForegroundFCM({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'fcm_live_channel',
      'Firebase Live Notifications',
      channelDescription: 'Live push messages received from Firebase Cloud Messaging',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  // Check and request permission (Helper for UI)
  static Future<void> checkAndRequestPermission({dynamic context}) async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // ---------------------------------------------------------------------------
  // ☁️ FIREBASE CLOUD TRIGGERS (Records events to Firestore for Cloud Function FCM)
  // ---------------------------------------------------------------------------
  static Future<void> triggerCloudNotification({
    required String title,
    required String body,
    required String type, // e.g. 'water_goal', 'step_goal', 'streak_risk'
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show immediate notification if active
    await _displayForegroundFCM(title: title, body: body);

    // Save notification event to Cloud Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications_queue')
        .add({
      'title': title,
      'body': body,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  // Legacy convenience wrappers routing through Firebase
  static Future<void> scheduleDailyReminder() async {}
  static Future<void> scheduleStreakCheck() async {}
  static Future<void> scheduleWaterReminders({int intervalHours = 2}) async {}

  static Future<void> showAllCompleted() async {
    await triggerCloudNotification(
      title: '🎉 All Habits Completed!',
      body: 'Incredible work! You crushed all your habits today.',
      type: 'all_habits_completed',
    );
  }

  static Future<void> showWaterGoalReached(int glasses) async {
    await triggerCloudNotification(
      title: '🎉 Hydration Goal Completed!',
      body: 'Amazing! You reached your target of $glasses glasses of water today.',
      type: 'water_goal',
    );
  }

  static Future<void> showStepsTargetCompleted(int targetSteps) async {
    await triggerCloudNotification(
      title: '🎯 Step Target Achieved!',
      body: 'You crushed it! You reached your goal of $targetSteps steps today.',
      type: 'step_goal',
    );
  }

  static Future<void> showStreakWarning(String habitName, int streak) async {
    await triggerCloudNotification(
      title: 'Streak At Risk',
      body: '$habitName — your $streak-day streak needs attention.',
      type: 'streak_risk',
    );
  }

  static Future<void> showStreakBroken(String habitName) async {
    await triggerCloudNotification(
      title: 'Streak Broken!',
      body: 'You missed $habitName yesterday. Your streak is reset.',
      type: 'streak_broken',
    );
  }
}
