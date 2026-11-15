import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService.checkAndRequestPermission(context: context);
      await NotificationService.scheduleDailyReminder();
      await NotificationService.scheduleStreakCheck();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 68,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                label: 'Home',
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                isDark: isDark,
              ),
              _buildNavItem(
                index: 1,
                label: 'Habits',
                svgAsset: 'assets/icons/fire_icon.svg',
                isDark: isDark,
              ),
              _buildNavItem(
                index: 2,
                label: 'Classes',
                icon: Icons.school_outlined,
                activeIcon: Icons.school_rounded,
                isDark: isDark,
              ),
              _buildNavItem(
                index: 3,
                label: 'Stats',
                icon: Icons.bar_chart_outlined,
                activeIcon: Icons.bar_chart_rounded,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    IconData? icon,
    IconData? activeIcon,
    String? svgAsset,
    required bool isDark,
  }) {
    final bool isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: isSelected
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : Colors.black) // Selected background is now Black (or white in dark mode for contrast)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (svgAsset != null)
              SvgPicture.asset(
                svgAsset,
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  isSelected
                      ? (isDark ? Colors.black : Colors.white)
                      : (isDark ? Colors.grey[400]! : Colors.grey[600]!),
                  BlendMode.srcIn,
                ),
              )
            else
              Icon(
                isSelected ? (activeIcon ?? icon) : icon,
                size: 22,
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
