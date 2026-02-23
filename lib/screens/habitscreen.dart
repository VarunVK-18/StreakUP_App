import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streakup/services/notification_service.dart';

class HabitScreen extends StatefulWidget {
  const HabitScreen({super.key});

  @override
  State<HabitScreen> createState() => _HabitScreenState();
}

class _HabitScreenState extends State<HabitScreen> {
  List<Map<String, dynamic>> habits = [];

  String get today =>
      DateTime.now().toIso8601String().substring(0, 10);
  String get yesterday =>
      DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('habits');

    habits = data == null
        ? []
        : List<Map<String, dynamic>>.from(json.decode(data));

    // Reset doneToday for new day
    for (final h in habits) {
      h['streak'] = (h['streak'] ?? 0) as int;
      h['doneToday'] = h['lastDone'] == today;
    }

    // Strict streak: reset if user missed a day
    _checkMissedHabits();

    await _saveHabits();

    NotificationService.scheduleDailyReminder();
    NotificationService.scheduleStreakCheck();

    if (mounted) setState(() {});
  }

  Future<void> _saveHabits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('habits', json.encode(habits));
  }

  /// Strict streak: reset streaks for missed days
  void _checkMissedHabits() {
    for (final h in habits) {
      final lastDone = (h['lastDone'] ?? '') as String;

      if (lastDone != yesterday && lastDone != today && (h['streak'] ?? 0) > 0) {
        h['streak'] = 0;
        NotificationService.showStreakBroken(h['name'] ?? '');
      }
    }
  }

  String _rewardLabel(int streak) {
    if (streak >= 28) return "💎 Diamond";
    if (streak >= 21) return "🥇 Gold";
    if (streak >= 14) return "🥈 Silver";
    if (streak >= 7) return "🥉 Bronze";
    return "";
  }

  void _toggleHabit(int index) {
    final habit = habits[index];

    if (habit['doneToday'] == true) return;

    final String lastDone = (habit['lastDone'] ?? '') as String;

    if (lastDone == yesterday) {
      // Consecutive day → increment streak
      habit['streak'] = (habit['streak'] ?? 0) + 1;
    } else if (lastDone != today) {
      // Missed day → start streak from 1 & notify
      habit['streak'] = 1;
      NotificationService.showStreakBroken(habit['name'] ?? '');
    }

    habit['lastDone'] = today;
    habit['doneToday'] = true;

    habits[index] = habit;

    _saveHabits();
    _evaluateNotifications();

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
        NotificationService.showStreakWarning(
          h['name'] ?? '',
          streak,
        );
        break;
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
        title: const Text("Add Habit"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Habit name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
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

  int get doneCount =>
      habits.where((h) => h['doneToday'] == true).length;

  int get bestStreak {
    if (habits.isEmpty) return 0;
    return habits
        .map((h) => (h['streak'] ?? 0) as int)
        .reduce((a, b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = habits.length - doneCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Habit Tracker",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _summaryCard("Total", habits.length.toString(),
                  Icons.list, Colors.blue),
              const SizedBox(width: 12),
              _summaryCard("Done Today", doneCount.toString(),
                  Icons.check_circle, Colors.green),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _summaryCard("Remaining", remaining.toString(),
                  Icons.pending, Colors.orange),
              const SizedBox(width: 12),
              _summaryCard("Best Streak", bestStreak.toString(),
                  Icons.local_fire_department, Colors.red),
            ],
          ),
          const SizedBox(height: 20),

          if (habits.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(
                child: Text(
                  "No habits yet\nTap + to add",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),

          ...habits.asMap().entries.map((entry) {
            final index = entry.key;
            final h = entry.value;

            final int streak = (h['streak'] ?? 0) as int;
            final bool done = h['doneToday'] == true;

            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: ListTile(
                leading: GestureDetector(
                  onTap: () => _toggleHabit(index),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: done
                          ? Colors.green
                          : Colors.grey.shade200,
                    ),
                    child: done
                        ? const Icon(Icons.check, color: Colors.white)
                        : const Icon(Icons.square_outlined),
                  ),
                ),
                title: Text(
                  h['name'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "🔥 Streak: $streak ${_rewardLabel(streak)}",
                ),

                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _editHabit(index);
                    if (value == 'reset') _resetHabit(index);
                    if (value == 'delete') _deleteHabit(index);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text("Edit"),
                    ),
                    const PopupMenuItem(
                      value: 'reset',
                      child: Text("Reset Streak"),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text("Delete"),
                    ),
                  ],
                ),
              ),
            );
          })
        ],
      ),
    );
  }

  Widget _summaryCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(title),
          ],
        ),
      ),
    );
  }
}
