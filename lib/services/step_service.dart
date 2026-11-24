import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'notification_service.dart';
import 'database_service.dart';

class StepService {
  static final StepService _instance = StepService._internal();
  factory StepService() => _instance;
  StepService._internal();

  StreamSubscription<StepCount>? _stepCountStream;
  final ValueNotifier<int> todaySteps = ValueNotifier<int>(0);
  final ValueNotifier<int> targetSteps = ValueNotifier<int>(6000);
  final ValueNotifier<bool> isHealthConnected = ValueNotifier<bool>(false);

  final Health _health = Health();
  bool _goalNotificationSent = false;
  int _bootStepOffset = 0;
  String _todayDate = '';

  Future<void> init() async {
    _todayDate = DateTime.now().toIso8601String().substring(0, 10);
    final prefs = await SharedPreferences.getInstance();

    targetSteps.value = prefs.getInt('steps_target') ?? 6000;
    _goalNotificationSent = prefs.getBool('steps_goal_notified_$_todayDate') ?? false;

    // Load saved daily base steps
    final savedTodaySteps = prefs.getInt('steps_count_$_todayDate') ?? 0;
    todaySteps.value = savedTodaySteps;
    _bootStepOffset = prefs.getInt('steps_boot_offset_$_todayDate') ?? 0;

    // 1. Try connecting to Google Health Connect / Google Fit
    await syncWithGoogleFit();

    // 2. Also initialize local pedometer as seamless real-time fallback
    await _initPedometer();
  }

  // ---------------------------------------------------------------------------
  // 🩺 GOOGLE HEALTH CONNECT / GOOGLE FIT SYNC
  // ---------------------------------------------------------------------------
  Future<String> syncWithGoogleFit() async {
    final types = [HealthDataType.STEPS];

    try {
      await _health.configure();

      // Check if Health Connect is available or needs installation
      final status = await _health.getHealthConnectSdkStatus();
      if (status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired ||
          status == HealthConnectSdkStatus.sdkUnavailable) {
        await openHealthConnectPlayStore();
        return "NEEDS_PLAYSTORE";
      }

      if (status != HealthConnectSdkStatus.sdkAvailable) {
        return "Health Connect is not supported on this device";
      }

      // Check existing permission
      bool? hasPermissions = await _health.hasPermissions(types);
      if (hasPermissions != true) {
        // Explicitly open the Health Connect permissions dialog
        final authorized = await _health.requestAuthorization(types);
        if (!authorized) {
          // Check once more after dialog dismissed
          final hasPermAfter = await _health.hasPermissions(types);
          if (hasPermAfter != true) {
            return "NEEDS_SETTINGS";
          }
        }
      }

      // If authorized, read steps
      isHealthConnected.value = true;
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      final steps = await _health.getTotalStepsInInterval(midnight, now);
      if (steps != null && steps > 0) {
        todaySteps.value = steps;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('steps_count_$_todayDate', steps);
        _checkGoal(steps);
        return "SUCCESS:$steps";
      } else {
        return "SUCCESS:0";
      }
    } catch (e) {
      debugPrint('Google Fit / Health Connect error: $e');
      return "Error: $e";
    }
  }

  // Open Health Connect Play Store page
  Future<void> openHealthConnectPlayStore() async {
    final Uri playStoreUri = Uri.parse(
      'market://details?id=com.google.android.apps.healthdata',
    );
    final Uri webUri = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata',
    );

    try {
      if (await canLaunchUrl(playStoreUri)) {
        await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Could not open Play Store: $e");
    }
  }

  // Open Health Connect / App Permissions settings directly
  Future<void> openHealthConnectSettings() async {
    await openAppSettings();
  }

  // ---------------------------------------------------------------------------
  // 🚶‍♂️ REAL-TIME HARDWARE SENSOR
  // ---------------------------------------------------------------------------
  Future<void> _initPedometer() async {
    try {
      final status = await Permission.activityRecognition.request();
      if (status.isGranted) {
        _stepCountStream = Pedometer.stepCountStream.listen(
          _onStepCount,
          onError: (error) {
            debugPrint('Pedometer error: $error');
          },
          cancelOnError: false,
        );
      }
    } catch (e) {
      debugPrint('Failed to start pedometer: $e');
    }
  }

  void _onStepCount(StepCount event) async {
    final nowDay = DateTime.now().toIso8601String().substring(0, 10);
    final prefs = await SharedPreferences.getInstance();

    // Day change reset
    if (nowDay != _todayDate) {
      _todayDate = nowDay;
      _bootStepOffset = event.steps;
      _goalNotificationSent = false;
      await prefs.setInt('steps_boot_offset_$_todayDate', _bootStepOffset);
      await prefs.setBool('steps_goal_notified_$_todayDate', false);
    }

    if (_bootStepOffset == 0 || _bootStepOffset > event.steps) {
      _bootStepOffset = event.steps - todaySteps.value;
      await prefs.setInt('steps_boot_offset_$_todayDate', _bootStepOffset);
    }

    int calculatedToday = event.steps - _bootStepOffset;
    if (calculatedToday < 0) calculatedToday = 0;

    // Only overwrite if hardware steps exceed currently recorded
    if (calculatedToday > todaySteps.value) {
      todaySteps.value = calculatedToday;
      await prefs.setInt('steps_count_$_todayDate', calculatedToday);
      _checkGoal(calculatedToday);
    }
  }

  void _checkGoal(int current) async {
    if (current >= targetSteps.value && !_goalNotificationSent) {
      _goalNotificationSent = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('steps_goal_notified_$_todayDate', true);
      NotificationService.showStepsTargetCompleted(targetSteps.value);
    }
  }

  Future<void> setTarget(int newTarget) async {
    targetSteps.value = newTarget;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('steps_target', newTarget);

    // Sync to Firestore
    final health = await DatabaseService().loadDailyHealth();
    await DatabaseService().saveDailyHealth(
      waterGlasses: health['waterGlasses'] ?? 0,
      waterTarget: health['waterTarget'] ?? 8,
      stepsCount: todaySteps.value,
      stepsTarget: newTarget,
    );
  }

  void addManualSteps(int count) async {
    todaySteps.value += count;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('steps_count_$_todayDate', todaySteps.value);

    _checkGoal(todaySteps.value);

    // Sync to Cloud
    final health = await DatabaseService().loadDailyHealth();
    await DatabaseService().saveDailyHealth(
      waterGlasses: health['waterGlasses'] ?? 0,
      waterTarget: health['waterTarget'] ?? 8,
      stepsCount: todaySteps.value,
      stepsTarget: targetSteps.value,
    );
  }

  void dispose() {
    _stepCountStream?.cancel();
  }
}
