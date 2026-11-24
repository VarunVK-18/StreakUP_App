import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:streakup/services/notification_service.dart';
import 'package:streakup/services/database_service.dart';
import 'package:streakup/services/circle_service.dart';
import 'package:streakup/screens/circle_hub_screen.dart';

class HabitScreen extends StatefulWidget {
  const HabitScreen({super.key});

  @override
  State<HabitScreen> createState() => _HabitScreenState();
}

class _HabitScreenState extends State<HabitScreen> {
  final DatabaseService _dbService = DatabaseService();
  final CircleService _circleService = CircleService();
  List<Map<String, dynamic>> habits = [];

  String get today => DateTime.now().toIso8601String().substring(0, 10);
  String get yesterday => DateTime.now()
      .subtract(const Duration(days: 1))
      .toIso8601String()
      .substring(0, 10);

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    habits = await _dbService.loadHabits();

    for (final h in habits) {
      h['streak'] = (h['streak'] ?? 0) as int;
      h['doneToday'] = h['lastDone'] == today;
    }

    _checkMissedHabits();
    await _saveHabits();

    NotificationService.scheduleDailyReminder();
    NotificationService.scheduleStreakCheck();

    if (mounted) setState(() {});
  }

  Future<void> _saveHabits() async {
    await _dbService.saveHabits(habits);
  }

  void _checkMissedHabits() {
    for (final h in habits) {
      final lastDone = (h['lastDone'] ?? '') as String;
      if (lastDone.isNotEmpty &&
          lastDone != yesterday &&
          lastDone != today &&
          (h['streak'] ?? 0) > 0) {
        final lostStreak = h['streak'];
        h['streak'] = 0;
        NotificationService.showStreakBroken(h['name'] ?? '', lostStreak);
      }
    }
  }

  void _toggleHabit(int index) {
    final habit = habits[index];
    final bool currentStatus = habit['doneToday'] == true;

    if (currentStatus) {
      // Toggle off / undo
      habit['doneToday'] = false;
      if (habit['lastDone'] == today) {
        habit['streak'] = math.max(0, ((habit['streak'] ?? 1) as int) - 1);
        habit['lastDone'] = '';
      }
    } else {
      // Toggle on / complete
      final String lastDone = (habit['lastDone'] ?? '') as String;
      if (lastDone == yesterday) {
        habit['streak'] = (habit['streak'] ?? 0) + 1;
      } else if (lastDone != today) {
        habit['streak'] = math.max(1, ((habit['streak'] ?? 0) as int) + 1);
      }
      habit['lastDone'] = today;
      habit['doneToday'] = true;
    }

    habits[index] = habit;
    _saveHabits();
    _circleService.syncMemberProgress(
      completed: doneCount,
      total: habits.length,
    );
    if (!currentStatus) _evaluateNotifications();
    setState(() {});
  }

  void _evaluateNotifications() {
    if (habits.isEmpty) return;
    final completed = habits.where((h) => h['doneToday'] == true).length;
    if (completed == habits.length) {
      NotificationService.showAllCompleted();
      return;
    }

    for (final h in habits) {
      final bool done = h['doneToday'] == true;
      final int streak = (h['streak'] ?? 0) as int;
      if (!done && streak > 0) {
        NotificationService.showStreakWarning(h['name'] ?? '', streak);
      }
    }
  }

  void _deleteHabit(int index) {
    habits.removeAt(index);
    _saveHabits();
    setState(() {});
  }

  void _resetHabit(int index) {
    habits[index]['streak'] = 0;
    habits[index]['doneToday'] = false;
    habits[index]['lastDone'] = '';
    _saveHabits();
    setState(() {});
  }

  void _editHabit(int index) {
    final controller = TextEditingController(text: habits[index]['name']);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Habit"),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              habits[index]['name'] = controller.text.trim();
              _saveHabits();
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  void _showAddDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add New Habit"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "e.g. Morning Meditation, Reading...",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              habits.add({
                'name': controller.text.trim(),
                'streak': 0,
                'lastDone': '',
                'doneToday': false,
              });
              _saveHabits();
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text("Add"),
          )
        ],
      ),
    );
  }

  int get doneCount => habits.where((h) => h['doneToday'] == true).length;

  int get bestStreak {
    if (habits.isEmpty) return 0;
    return habits
        .map((h) => (h['streak'] ?? 0) as int)
        .reduce((a, b) => a > b ? a : b);
  }

  // Helper to pick cute representative emoji / icon for habit name
  Widget _buildHabitIcon(String name, bool isDark) {
    final n = name.toLowerCase();
    String emoji = "🎯";
    Color iconBg = const Color(0xFFF1F5F9);

    if (n.contains("meditat") || n.contains("yoga") || n.contains("mind")) {
      emoji = "🧘";
      iconBg = const Color(0xFFEDE9FE);
    } else if (n.contains("read") || n.contains("book") || n.contains("study")) {
      emoji = "📚";
      iconBg = const Color(0xFFDCFCE7);
    } else if (n.contains("water") || n.contains("drink") || n.contains("hydrat")) {
      emoji = "💧";
      iconBg = const Color(0xFFDBEAFE);
    } else if (n.contains("run") || n.contains("walk") || n.contains("exercise") || n.contains("gym")) {
      emoji = "🏃";
      iconBg = const Color(0xFFFEF3C7);
    } else if (n.contains("sleep") || n.contains("bed") || n.contains("rest")) {
      emoji = "🌙";
      iconBg = const Color(0xFFE0E7FF);
    } else if (n.contains("eat") || n.contains("food") || n.contains("diet")) {
      emoji = "🥗";
      iconBg = const Color(0xFFD1FAE5);
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2E3D) : iconBg,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 22),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F1218) : const Color(0xFFF9FAFC);
    final cardBg = isDark ? const Color(0xFF181C26) : const Color(0xFFFFFFFF);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    final now = DateTime.now();
    final dateString = DateFormat('EEEE, MMM d').format(now);

    final int total = habits.length;
    final int completed = doneCount;
    final double percent = total > 0 ? (completed / total) : 0.0;
    final int percentInt = (percent * 100).round();

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // ---------------------------------------------------------------
            // 🌟 TOP APP BAR: Filter/Action Icon + Date + "Today's Habits" + Avatar
            // ---------------------------------------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Filter / Add icon badge
                GestureDetector(
                  onTap: _showAddDialog,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: cardBg,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: textColor,
                      size: 20,
                    ),
                  ),
                ),

                // Center Title: Date + Today's Habits
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        dateString,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: subTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "Today's Habits",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.4,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // Balanced spacing on the right (keeps title centered)
                const SizedBox(width: 46),
              ],
            ),
            const SizedBox(height: 22),

            // ---------------------------------------------------------------
            // 🌟 HERO PROGRESS CARD: Soft Peach/Warm Gradient + Radial Progress
            // ---------------------------------------------------------------
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF2A2022), const Color(0xFF231B21)]
                      : [const Color(0xFFFFF0EA), const Color(0xFFFFECE5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF7A59).withValues(alpha: isDark ? 0.08 : 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Daily Progress",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : const Color(0xFF78716C),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "$completed/$total completed",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : const Color(0xFF1C1917),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Text("🔥", style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 5),
                            Text(
                              "Best streak: $bestStreak days",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFFF8A65) : const Color(0xFFC2410C),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Right: Radial Circular Chart with Coral/Orange Progress
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background track
                        SizedBox(
                          width: 84,
                          height: 84,
                          child: CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: 7,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFF5D0C5).withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        // Active gradient arc
                        SizedBox(
                          width: 84,
                          height: 84,
                          child: CircularProgressIndicator(
                            value: percent.clamp(0.0, 1.0),
                            strokeWidth: 7,
                            strokeCap: StrokeCap.round,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF6B53), // Coral Orange matching mockup
                            ),
                          ),
                        ),
                        Text(
                          "$percentInt%",
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1C1917),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ---------------------------------------------------------------
            // 🌟 2-COLUMN WIDGETS: "Deadline" & "People" (Exact Mockup Row)
            // ---------------------------------------------------------------
            Row(
              children: [
                // Card 1: Deadline
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Deadline",
                          style: TextStyle(
                            fontSize: 13,
                            color: subTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 28,
                          color: textColor,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          DateFormat('d MMMM').format(now),
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Card 2: People / Community
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CircleHubScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Community",
                            style: TextStyle(
                              fontSize: 13,
                              color: subTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Overlapping avatar stack matching mockup
                          SizedBox(
                            height: 32,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned(
                                  left: 16,
                                  child: _miniAvatar("👧", const Color(0xFFBAE6FD)),
                                ),
                                Positioned(
                                  left: 40,
                                  child: _miniAvatar("👦", const Color(0xFFFFEDD5)),
                                ),
                                Positioned(
                                  left: 64,
                                  child: _miniAvatar("🧔", const Color(0xFFE2E8F0)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "StreakUP Circle",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 11,
                                color: subTextColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ---------------------------------------------------------------
            // 🌟 HABIT LIST (Clean rounded pills with custom icons & checkmarks)
            // ---------------------------------------------------------------
            if (habits.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.checklist_rounded, size: 48, color: subTextColor),
                      const SizedBox(height: 12),
                      Text(
                        "No habits added yet\nTap the top filter button to add one!",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: subTextColor, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...habits.asMap().entries.map((entry) {
                final index = entry.key;
                final h = entry.value;

                final int streak = (h['streak'] ?? 0) as int;
                final bool done = h['doneToday'] == true;
                final String name = h['name'] ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Representative Icon
                      _buildHabitIcon(name, isDark),
                      const SizedBox(width: 14),

                      // Title & Streak
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                                decoration: done ? TextDecoration.lineThrough : null,
                                decorationColor: subTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                SvgPicture.asset(
                                  'assets/icons/fire_icon.svg',
                                  width: 14,
                                  height: 14,
                                  colorFilter: ColorFilter.mode(
                                    streak > 0 ? const Color(0xFFFF5722) : Colors.grey,
                                    BlendMode.srcIn,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "$streak days",
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: streak > 0 ? const Color(0xFFFF5722) : subTextColor,
                                    fontWeight: streak > 0 ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Actions menu (edit / delete)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, size: 20, color: subTextColor),
                        onSelected: (val) {
                          if (val == 'edit') _editHabit(index);
                          if (val == 'reset') _resetHabit(index);
                          if (val == 'delete') _deleteHabit(index);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text("Edit")),
                          const PopupMenuItem(value: 'reset', child: Text("Reset Streak")),
                          const PopupMenuItem(value: 'delete', child: Text("Delete")),
                        ],
                      ),

                      // Circular Checkmark button (Exact Coral circle like mockup)
                      GestureDetector(
                        onTap: () => _toggleHabit(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: done ? const Color(0xFFFF6B53) : Colors.transparent,
                            border: Border.all(
                              color: done ? const Color(0xFFFF6B53) : (isDark ? Colors.white30 : const Color(0xFFCBD5E1)),
                              width: 2,
                            ),
                          ),
                          child: done
                              ? const Icon(Icons.check, size: 18, color: Colors.white)
                              : null,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 80), // Padding for floating capsule navbar
          ],
        ),
      ),
    );
  }

  Widget _miniAvatar(String emoji, Color bg) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 12)),
    );
  }
}
