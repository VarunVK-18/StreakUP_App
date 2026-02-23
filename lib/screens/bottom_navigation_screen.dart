import 'package:flutter/material.dart';

import 'package:streakup/screens/homescreen.dart';
import 'package:streakup/screens/habitscreen.dart';
import 'package:streakup/screens/attanancescreen.dart';
import 'package:streakup/screens/statsscreen.dart';
import 'package:streakup/services/notification_service.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    HabitScreen(),
    AttendanceScreen(),
    StatsScreen(),
  ];

  @override
  void initState() {
    super.initState();

    // Ask notification permission after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Ask permission
      await NotificationService.checkAndRequestPermission(context: context);

      // Schedule notifications
      await NotificationService.scheduleDailyReminder();
      await NotificationService.scheduleStreakCheck();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.indigo,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.local_fire_department), label: 'Habits'),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Attendance'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
        ],
      ),
    );
  }
}
