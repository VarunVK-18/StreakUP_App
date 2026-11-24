import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:streakup/services/database_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> subjects = [];

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    subjects = await _dbService.loadSubjects();
    if (mounted) setState(() {});
  }

  Future<void> _saveSubjects() async {
    await _dbService.saveSubjects(subjects);
  }

  void _addSubject(String name) {
    subjects.add({
      'name': name,
      'present': 0.0,
      'total': 0,
    });
    _saveSubjects();
    setState(() {});
  }

  void _markPresent(int i) {
    subjects[i]['present'] = (subjects[i]['present'] ?? 0.0) + 1.0;
    subjects[i]['total'] = (subjects[i]['total'] ?? 0) + 1;
    _saveSubjects();
    setState(() {});
  }

  void _markAbsent(int i) {
    subjects[i]['total'] = (subjects[i]['total'] ?? 0) + 1;
    _saveSubjects();
    setState(() {});
  }

  void _markHalfDay(int i) {
    subjects[i]['present'] = (subjects[i]['present'] ?? 0.0) + 0.5;
    subjects[i]['total'] = (subjects[i]['total'] ?? 0) + 1;
    _saveSubjects();
    setState(() {});
  }

  void _resetSubject(int index) {
    subjects[index]['present'] = 0.0;
    subjects[index]['total'] = 0;
    _saveSubjects();
    setState(() {});
  }

  void _deleteSubject(int index) {
    subjects.removeAt(index);
    _saveSubjects();
    setState(() {});
  }

  double _percentage(Map<String, dynamic> s) {
    final total = s['total'] ?? 0;
    if (total == 0) return 0.0;
    final present = (s['present'] ?? 0.0).toDouble();
    return (present / total) * 100;
  }

  double get _overallPercentage {
    double present = 0;
    int total = 0;
    for (final s in subjects) {
      present += (s['present'] ?? 0.0).toDouble();
      total += (s['total'] ?? 0) as int;
    }
    return total == 0 ? 0.0 : (present / total) * 100;
  }

  int get _totalClassesAttended {
    double present = 0;
    for (final s in subjects) {
      present += (s['present'] ?? 0.0).toDouble();
    }
    return present.round();
  }

  int get _totalClassesHeld {
    int total = 0;
    for (final s in subjects) {
      total += (s['total'] ?? 0) as int;
    }
    return total;
  }

  void _showAddDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Subject"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "e.g. Mathematics, Physics, OS...",
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
              if (controller.text.trim().isNotEmpty) {
                _addSubject(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _confirmReset(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reset Attendance"),
        content: const Text(
          "This will reset present, absent and total days for this subject. Continue?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              _resetSubject(index);
              Navigator.pop(context);
            },
            child: const Text("Reset"),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectIcon(String name, bool isDark) {
    final n = name.toLowerCase();
    String emoji = "📚";
    Color iconBg = const Color(0xFFEDE9FE);

    if (n.contains("math") || n.contains("calc") || n.contains("stat")) {
      emoji = "📐";
      iconBg = const Color(0xFFFEF3C7);
    } else if (n.contains("physic") || n.contains("science") || n.contains("chem")) {
      emoji = "🧪";
      iconBg = const Color(0xFFDBEAFE);
    } else if (n.contains("code") || n.contains("program") || n.contains("cs") || n.contains("java") || n.contains("python")) {
      emoji = "💻";
      iconBg = const Color(0xFFDCFCE7);
    } else if (n.contains("english") || n.contains("lang") || n.contains("literat")) {
      emoji = "📖";
      iconBg = const Color(0xFFFCE7F3);
    } else if (n.contains("hist") || n.contains("social") || n.contains("geo")) {
      emoji = "🌍";
      iconBg = const Color(0xFFE0E7FF);
    } else if (n.contains("ai") || n.contains("data") || n.contains("ml")) {
      emoji = "🤖";
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

    final overall = _overallPercentage;
    final int overallInt = overall.round();

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // ---------------------------------------------------------------
            // 🌟 TOP APP BAR: Filter/Action Icon + Date + "Classes & Attendance" + Avatar
            // ---------------------------------------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Add subject action button
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
                      Icons.add_rounded,
                      color: textColor,
                      size: 24,
                    ),
                  ),
                ),

                // Center Title: Date + Attendance
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dateString,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: subTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Classes & Attendance",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // Balanced spacing on the right
                const SizedBox(width: 46),
              ],
            ),
            const SizedBox(height: 24),

            // ---------------------------------------------------------------
            // 🌟 PEACH DAILY ATTENDANCE CARD (Radial Arc + Overall Stats)
            // ---------------------------------------------------------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: isDark
                    ? const LinearGradient(
                        colors: [Color(0xFF2A2022), Color(0xFF1E1A22)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFFFF1EB), Color(0xFFFDE8E1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B6B).withValues(alpha: isDark ? 0.08 : 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left Column: Stats & Bunk Status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Overall Attendance",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFFFB5A7) : const Color(0xFF78716C),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "$_totalClassesAttended/$_totalClassesHeld attended",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF1C1917),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Text(
                              overall >= 75.0 ? "🎯 " : "⚠️ ",
                              style: const TextStyle(fontSize: 14),
                            ),
                            Flexible(
                              child: Text(
                                overall >= 75.0
                                    ? "On Track (≥75% criteria met)"
                                    : "Shortage Alert (<75% target)",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: overall >= 75.0
                                      ? (isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D))
                                      : const Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Right: Radial Progress Ring with Percentage
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CustomPaint(
                      painter: _RadialArcPainter(
                        progress: (overall / 100.0).clamp(0.0, 1.0),
                        isDark: isDark,
                      ),
                      child: Center(
                        child: Text(
                          "$overallInt%",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF1C1917),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ---------------------------------------------------------------
            // 🌟 2-COLUMN INFO ROW: Target Metric + Total Subjects
            // ---------------------------------------------------------------
            Row(
              children: [
                // Column 1: Attendance Target
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
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
                          "Target Criteria",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: subTextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Icon(
                          Icons.verified_rounded,
                          size: 26,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "75% Minimum",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Column 2: Total Subjects Count
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
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
                          "Enrolled Subjects",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: subTextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Icon(
                          Icons.school_rounded,
                          size: 26,
                          color: Color(0xFFFF6B6B),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "${subjects.length} Subjects",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ---------------------------------------------------------------
            // 🌟 SUBJECT CARDS LIST (Matching Habits layout with Present/Absent/Reset actions)
            // ---------------------------------------------------------------
            if (subjects.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    const Text("📚", style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(
                      "No subjects added yet",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Tap the + button above to add your first subject!",
                      style: TextStyle(fontSize: 13, color: subTextColor),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(subjects.length, (index) {
                final s = subjects[index];
                final String name = s['name'] ?? 'Subject';
                final double percent = _percentage(s);
                final int percentInt = percent.round();
                final present = s['present'] ?? 0.0;
                final total = s['total'] ?? 0;
                final bool isSafe = percent >= 75.0 || total == 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Subject Emoji Icon
                          _buildSubjectIcon(name, isDark),
                          const SizedBox(width: 14),

                          // Subject Name & Attendance Numbers
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      "$present/$total attended",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: subTextColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isSafe
                                            ? (isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7))
                                            : (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "$percentInt%",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isSafe
                                              ? (isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D))
                                              : (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Present Quick-Action Circle Button (Coral Checkmark style)
                          GestureDetector(
                            onTap: () => _markPresent(index),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF10B981),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Absent Action Circle Button
                          GestureDetector(
                            onTap: () => _markAbsent(index),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFEF4444),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),

                          // More Options Menu (Reset / Delete)
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert_rounded, color: subTextColor, size: 20),
                            color: cardBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            onSelected: (val) {
                              if (val == 'half') _markHalfDay(index);
                              if (val == 'reset') _confirmReset(index);
                              if (val == 'delete') _deleteSubject(index);
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'half',
                                child: Row(
                                  children: [
                                    Icon(Icons.timelapse_rounded, size: 18, color: Colors.blue),
                                    SizedBox(width: 8),
                                    Text('Half Day (+0.5)'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'reset',
                                child: Row(
                                  children: [
                                    Icon(Icons.refresh_rounded, size: 18, color: Colors.orange),
                                    SizedBox(width: 8),
                                    Text('Reset Attendance'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                    SizedBox(width: 8),
                                    Text('Delete Subject'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 🌟 CUSTOM RADIAL ARC PAINTER (Matching Habits page radial gauge)
// ---------------------------------------------------------------------------
class _RadialArcPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _RadialArcPainter({
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    // Background grey circle
    final bgPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.1)
          : const Color(0xFFE2E8F0).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Foreground Coral / Green Arc
    final arcPaint = Paint()
      ..color = progress >= 0.75 ? const Color(0xFF10B981) : const Color(0xFFFF6B6B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
