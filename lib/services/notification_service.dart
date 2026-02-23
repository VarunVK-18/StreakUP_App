import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  // ---------------------------------------------------------------------------
  // ✅ INIT NOTIFICATIONS
  // ---------------------------------------------------------------------------
  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (details) {},
    );

    // iOS only: request permission automatically
    final iosDetails =
    _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await iosDetails?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // ---------------------------------------------------------------------------
  // ✅ CHECK & REQUEST NOTIFICATION PERMISSION (iOS & Android 13+)
  // ---------------------------------------------------------------------------
  static Future<void> checkAndRequestPermission({BuildContext? context}) async {
    final status = await Permission.notification.status;

    if (!status.isGranted) {
      final result = await Permission.notification.request();

      if (context != null && context.mounted) {
        if (result.isDenied || result.isPermanentlyDenied) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Enable Notifications"),
              content: const Text(
                  "Notifications are disabled. To receive habit reminders, please enable them in your device settings."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    openAppSettings();
                    Navigator.pop(context);
                  },
                  child: const Text("Open Settings"),
                )
              ],
            ),
          );
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // ✅ DAILY REMINDER – 8 PM
  // ---------------------------------------------------------------------------
  static Future<void> scheduleDailyReminder() async {
    final now = tz.TZDateTime.now(tz.local);

    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      20, // 8 PM
    );

    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));

    const androidDetails = AndroidNotificationDetails(
      'daily_channel',
      'Daily Reminder',
      channelDescription: 'Daily habit reminder',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.zonedSchedule(
      id: 1,
      title: 'Daily Check-in',
      body: 'A small step today protects your progress.',
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ---------------------------------------------------------------------------
  // ✅ STREAK CHECK – 7 PM
  // ---------------------------------------------------------------------------
  static Future<void> scheduleStreakCheck() async {
    final now = tz.TZDateTime.now(tz.local);

    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      19, // 7 PM
    );

    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));

    const androidDetails = AndroidNotificationDetails(
      'streak_channel',
      'Streak Check',
      channelDescription: 'Checks streak risks',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.zonedSchedule(
      id: 99,
      title: 'Habit Review',
      body: 'Checking your streaks…',
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ---------------------------------------------------------------------------
  // ✅ ALL HABITS COMPLETED
  // ---------------------------------------------------------------------------
  static Future<void> showAllCompleted() async {
    const androidDetails = AndroidNotificationDetails(
      'success_channel',
      'Success',
      channelDescription: 'All habits completed',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      id: 2,
      title: 'All Habits Completed',
      body: 'Momentum successfully preserved.',
      notificationDetails: details,
    );
  }

  // ---------------------------------------------------------------------------
  // ✅ STREAK WARNING
  // ---------------------------------------------------------------------------
  static Future<void> showStreakWarning(String habitName, int streak) async {
    const androidDetails = AndroidNotificationDetails(
      'warning_channel',
      'Streak Warning',
      channelDescription: 'Habit streak warning',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      id: 3,
      title: 'Streak At Risk',
      body: '$habitName — your $streak-day streak needs attention.',
      notificationDetails: details,
    );
  }

  // ---------------------------------------------------------------------------
  // ✅ STREAK BROKEN NOTIFICATION
  // ---------------------------------------------------------------------------
  static Future<void> showStreakBroken(String habitName) async {
    const androidDetails = AndroidNotificationDetails(
      'broken_channel',
      'Streak Broken',
      channelDescription: 'Habit streak broken',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      id: 4,
      title: 'Streak Broken!',
      body: 'You missed $habitName yesterday. Your streak is reset.',
      notificationDetails: details,
    );
  }
}
