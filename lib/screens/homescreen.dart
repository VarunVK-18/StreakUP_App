import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'habitscreen.dart';
import 'attanancescreen.dart';
import 'statsscreen.dart';
import 'theme_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int totalHabits = 0;
  int completedHabits = 0;
  double attendancePercent = 0;

  final List<String> _dailyQuotes = [
    "✨ Start by adding your first habit!",
    "🔥 Amazing! All habits completed today.",
    "💪 Let’s get started. One habit is enough!",
    "⚡ Keep going! You're building consistency.",
    "🌟 Small steps lead to big achievements!",
    "🏆 Consistency is the key to success!",
    "🌈 Every day is a new opportunity!"
  ];

  String getDailyQuote() {
    int index = DateTime.now().day % _dailyQuotes.length;

    if (completedHabits == totalHabits && totalHabits > 0) {
      return "🔥 Congratulations! All habits done today!";
    }

    return _dailyQuotes[index];
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final habits =
    json.decode(prefs.getString('habits') ?? '[]') as List;

    final subjects =
    json.decode(prefs.getString('subjects') ?? '[]') as List;

    totalHabits = habits.length;
    completedHabits =
        habits.where((h) => h['doneToday'] == true).length;

    double present = 0;
    int total = 0;

    for (final s in subjects) {
      present += (s['present'] ?? 0).toDouble();
      total += (s['total'] ?? 0) as int;
    }

    attendancePercent =
    total == 0 ? 0 : (present / total) * 100;

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDark;

    final formattedDate =
    DateFormat('EEEE, MMM d, y').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "StreakUp",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: themeProvider.toggleTheme,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFabMenu(context),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), // ✅ extra bottom space
          children: [
            Text(
              formattedDate,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Welcome Back 👋",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Today's Focus",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            /// ✅ Removed rigid height container (main fix)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _focusCard(
                    title: "Habits Left",
                    value: totalHabits - completedHabits,
                    icon: Icons.local_fire_department,
                    color: Colors.orange,
                    percent: totalHabits == 0
                        ? 0
                        : completedHabits / totalHabits,
                  ),
                  const SizedBox(width: 12),
                  _focusCard(
                    title: "Attendance",
                    value:
                    "${attendancePercent.toStringAsFixed(1)}%",
                    icon: Icons.school,
                    color: attendancePercent >= 75
                        ? Colors.green
                        : Colors.red,
                    percent: attendancePercent / 100,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),
            const Text(
              "Daily Motivation",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _motivationCard(),
            const SizedBox(height: 20),

            if (attendancePercent > 0 && attendancePercent < 75)
              _attendanceWarning(),
          ],
        ),
      ),
    );
  }

  Widget _focusCard({
    required String title,
    required dynamic value,
    required IconData icon,
    required Color color,
    required double percent,
  }) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12), // ✅ modern API (no deprecation)
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // ✅ prevents overflow
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            width: 50,
            child: CircularProgressIndicator(
              value: percent.clamp(0.0, 1.0),
              color: color,
              backgroundColor: color.withValues(alpha: 0.2),
              strokeWidth: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "$value",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _motivationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.indigo, Colors.blueAccent],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome,
              color: Colors.white, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              getDailyQuote(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attendanceWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning, color: Colors.orange),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Attendance is below 75%. Take action!",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFabMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text("Add Habit"),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const HabitScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text("View Stats"),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const StatsScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.school),
              title: const Text("Attendance"),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                    const AttendanceScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
