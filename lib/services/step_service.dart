import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'database_service.dart';

class StepService {
  static final StepService _instance = StepService._internal();
  factory StepService() => _instance;
  StepService._internal();

  StreamSubscription<StepCount>? _stepCountStream;
  final ValueNotifier<int> todaySteps = ValueNotifier<int>(0);
  final ValueNotifier<int> targetSteps = ValueNotifier<int>(6000);

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

    // Request Activity Recognition Permission (Android 10+)
    await _initPedometer();
  }

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

    todaySteps.value = calculatedToday;
    await prefs.setInt('steps_count_$_todayDate', calculatedToday);

    // Check step target completion
    if (calculatedToday >= targetSteps.value && !_goalNotificationSent) {
      _goalNotificationSent = true;
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

    if (todaySteps.value >= targetSteps.value && !_goalNotificationSent) {
      _goalNotificationSent = true;
      await prefs.setBool('steps_goal_notified_$_todayDate', true);
      NotificationService.showStepsTargetCompleted(targetSteps.value);
    }

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

