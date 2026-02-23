import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<Map<String, dynamic>> habits = [];
  List<Map<String, dynamic>> subjects = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ---------------------------------------------------------------------------
  // ✅ SAFE DATA LOADING
  // ---------------------------------------------------------------------------
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final habitData = prefs.getString('habits');
      final subjectData = prefs.getString('subjects');

      habits = habitData == null
          ? []
          : List<Map<String, dynamic>>.from(json.decode(habitData));

      subjects = subjectData == null
          ? []
          : List<Map<String, dynamic>>.from(json.decode(subjectData));
    } catch (e) {
      habits = [];
      subjects = [];
    }

    if (!mounted) return;
    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // ✅ ATTENDANCE CALCULATION
  // ---------------------------------------------------------------------------
  double _attendancePercent() {
    double present = 0;
    double total = 0;

    for (var s in subjects) {
      present += (s['present'] ?? 0).toDouble();
      total += (s['total'] ?? 0).toDouble();
    }

    return total == 0 ? 0 : (present / total) * 100;
  }

  // ---------------------------------------------------------------------------
  // ✅ ATTENDANCE ANALYSIS TEXT
  // ---------------------------------------------------------------------------
  String _attendanceAnalysis(double percent) {
    if (percent >= 90) return "Excellent ✅";
    if (percent >= 75) return "Good standing ✅";
    if (percent >= 50) return "Needs improvement ⚠";
    return "Below safe zone ❌";
  }

  @override
  Widget build(BuildContext context) {
    final attendancePercent = _attendancePercent();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Statistics",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // -----------------------------------------------------------------
            // ✅ SUMMARY CARDS
            // -----------------------------------------------------------------
            Row(
              children: [
                _summaryCard(
                  "Habits",
                  habits.length.toString(),
                  Icons.local_fire_department,
                  Colors.orange,
                ),
                const SizedBox(width: 12),
                _summaryCard(
                  "Attendance",
                  "${attendancePercent.toStringAsFixed(1)}%",
                  Icons.school,
                  attendancePercent >= 75 ? Colors.green : Colors.red,
                ),
              ],
            ),

            const SizedBox(height: 30),

            // -----------------------------------------------------------------
            // ✅ ATTENDANCE ANALYSIS HERO CARD
            // -----------------------------------------------------------------
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Attendance Progress",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "${attendancePercent.toStringAsFixed(1)}%",
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: (attendancePercent / 100).clamp(0.0, 1.0),
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(10),
                    color: attendancePercent >= 75 ? Colors.green : Colors.red,
                    backgroundColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 8),
                  Text(_attendanceAnalysis(attendancePercent)),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // -----------------------------------------------------------------
            // ✅ SUBJECT BREAKDOWN
            // -----------------------------------------------------------------
            const Text(
              "Subjects Attendance",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            subjects.isEmpty
                ? const Text("No subjects added")
                : Column(
              children: subjects.map((s) {
                final present = (s['present'] ?? 0).toDouble();
                final total = (s['total'] ?? 0).toDouble();
                final percent = total == 0 ? 0 : (present / total) * 100;

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(s['name'] ?? ''),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: LinearProgressIndicator(
                        value: (percent / 100).clamp(0.0, 1.0),
                        minHeight: 10,
                        color: percent >= 75 ? Colors.green : Colors.red,
                        backgroundColor: Colors.grey.shade300,
                      ),
                    ),
                    trailing: Text(
                      "${percent.toStringAsFixed(0)}%",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: percent >= 75 ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 30),

            // -----------------------------------------------------------------
            // ✅ HABIT STREAKS
            // -----------------------------------------------------------------
            const Text(
              "Habit Streaks",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            habits.isEmpty
                ? const Text("No habits added")
                : Column(
              children: habits.map((h) {
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(
                      Icons.local_fire_department,
                      color: Colors.orange,
                    ),
                    title: Text(h['name'] ?? ''),
                    trailing: Text(
                      "🔥 ${(h['streak'] ?? 0)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ✅ SUMMARY CARD WIDGET (Fixed: withValues instead of withOpacity)
  // ---------------------------------------------------------------------------
  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12), // <-- fixed here
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
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
