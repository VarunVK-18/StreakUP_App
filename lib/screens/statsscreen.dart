import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:streakup/services/database_service.dart';
import 'package:streakup/services/step_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final DatabaseService _dbService = DatabaseService();
  final StepService _stepService = StepService();

  List<Map<String, dynamic>> habits = [];
  List<Map<String, dynamic>> subjects = [];
  Map<String, dynamic> healthData = {};

  int _selectedTabIndex = 0; // 0 = "Overview", 1 = "Habits & Routines"

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      habits = await _dbService.loadHabits();
      subjects = await _dbService.loadSubjects();
      healthData = await _dbService.loadDailyHealth();
    } catch (e) {
      habits = [];
      subjects = [];
      healthData = {};
    }

    if (!mounted) return;
    setState(() {});
  }

  double _attendancePercent() {
    double present = 0;
    double total = 0;

    for (var s in subjects) {
      present += (s['present'] ?? 0).toDouble();
      total += (s['total'] ?? 0).toDouble();
    }

    return total == 0 ? 0 : (present / total) * 100;
  }

  int _activeStreaksCount() {
    return habits.where((h) => (h['streak'] ?? 0) > 0).length;
  }

  int _bestStreak() {
    if (habits.isEmpty) return 0;
    int max = 0;
    for (var h in habits) {
      final s = (h['streak'] ?? 0) as int;
      if (s > max) max = s;
    }
    return max;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D0F14) : const Color(0xFFF9FAFC);
    final cardBg = isDark ? const Color(0xFF161922) : const Color(0xFFEEF0F5);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    final attPercent = _attendancePercent();
    final waterGlasses = healthData['waterGlasses'] ?? 0;
    final waterTarget = healthData['waterTarget'] ?? 8;
    final steps = _stepService.todaySteps.value;
    final targetSteps = _stepService.targetSteps.value;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: Colors.deepOrangeAccent,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // -------------------------------------------------------------
              // 🌟 1. HEADER (Title + Orange Circular Action Button)
              // -------------------------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Analytics",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.8,
                      color: textColor,
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF2563EB), // Vibrant Professional Blue Action Button
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x402563EB),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 24),
                      tooltip: "Refresh Metrics",
                      onPressed: _loadData,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // -------------------------------------------------------------
              // 🔲 2. SEGMENTED PILL TAB SWITCHER
              // -------------------------------------------------------------
              Container(
                height: 52,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E222D) : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTabIndex = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: _selectedTabIndex == 0
                                ? (isDark ? Colors.white : Colors.black)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(26),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "My Metrics",
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: _selectedTabIndex == 0
                                  ? (isDark ? Colors.black : Colors.white)
                                  : subTextColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTabIndex = 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: _selectedTabIndex == 1
                                ? (isDark ? Colors.white : Colors.black)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(26),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "Habit Streaks",
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: _selectedTabIndex == 1
                                  ? (isDark ? Colors.black : Colors.white)
                                  : subTextColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // -------------------------------------------------------------
              // 📱 3. TAB 1: 2x2 ANALYTICS GRID (Exact requested mockup design)
              // -------------------------------------------------------------
              if (_selectedTabIndex == 0) ...[
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 0.95,
                  children: [
                    // Card 1: Habit Streak Momentum
                    _cleanMetricCard(
                      icon: Icons.local_fire_department_rounded,
                      iconColor: const Color(0xFFFF5722),
                      title: "Streak Momentum",
                      subtitle: "${_activeStreaksCount()} active (${_bestStreak()} max streak)",
                      cardBg: cardBg,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),

                    // Card 2: Attendance Standing
                    _cleanMetricCard(
                      icon: Icons.school_rounded,
                      iconColor: attPercent >= 75 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      title: "Attendance",
                      subtitle: "${attPercent.toStringAsFixed(1)}% safe threshold",
                      cardBg: cardBg,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),

                    // Card 3: Daily Steps Counter
                    _cleanMetricCard(
                      icon: Icons.directions_walk_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      title: "Activity / Steps",
                      subtitle: "$steps of $targetSteps steps done",
                      cardBg: cardBg,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),

                    // Card 4: Daily Hydration
                    _cleanMetricCard(
                      icon: Icons.water_drop_rounded,
                      iconColor: const Color(0xFF3B82F6),
                      title: "Water Intake",
                      subtitle: "$waterGlasses of $waterTarget glasses drunk",
                      cardBg: cardBg,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // -------------------------------------------------------------
                // 📊 4. "ACTIVE ROUTINE" / ATTENDANCE BREAKDOWN SECTION
                // -------------------------------------------------------------
                Text(
                  "Active routine",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 14),

                if (subjects.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        "No subjects added yet. Add subjects in the Attendance tab!",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: subTextColor, fontSize: 13.5),
                      ),
                    ),
                  )
                else
                  ...subjects.map((s) {
                    final present = (s['present'] ?? 0).toDouble();
                    final total = (s['total'] ?? 0).toDouble();
                    final percent = total == 0 ? 0.0 : (present / total) * 100;
                    final isSafe = percent >= 75;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF232836) : Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.menu_book_rounded,
                              size: 20,
                              color: isSafe ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s['name'] ?? 'Subject',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${present.toInt()} of ${total.toInt()} classes attended",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: subTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "${percent.toStringAsFixed(0)}%",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isSafe ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ] else ...[
                // -------------------------------------------------------------
                // 🔥 TAB 2: HABIT STREAKS VIEW
                // -------------------------------------------------------------
                Text(
                  "Habit Streaks",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 14),

                if (habits.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        "No habits added yet. Start your first streak in Habits tab!",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: subTextColor, fontSize: 13.5),
                      ),
                    ),
                  )
                else
                  ...habits.map((h) {
                    final streak = (h['streak'] ?? 0) as int;
                    final doneToday = h['doneToday'] == true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF232836) : Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: SvgPicture.asset(
                                'assets/icons/fire_icon.svg',
                                width: 20,
                                height: 20,
                                colorFilter: ColorFilter.mode(
                                  streak > 0 ? const Color(0xFFFF5722) : Colors.grey,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  h['name'] ?? '',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  doneToday ? "Completed today ✨" : "Pending today",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: doneToday ? const Color(0xFF10B981) : subTextColor,
                                    fontWeight: doneToday ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: streak > 0
                                  ? const Color(0xFFFF5722).withValues(alpha: 0.15)
                                  : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.local_fire_department,
                                  size: 16,
                                  color: Color(0xFFFF5722),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  "$streak",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFFFF5722),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
              const SizedBox(height: 80), // Padding for floating navbar
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🔲 PROFESSIONAL ROUNDED GRID CARD (Mockup exact design)
  // ---------------------------------------------------------------------------
  Widget _cleanMetricCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color cardBg,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // White circular icon badge (exact as in mockup)
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),

          // Titles & Subtitles
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: subTextColor,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
