import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'habitscreen.dart';
import 'attanancescreen.dart';
import 'statsscreen.dart';
import 'profile_screen.dart';
import 'theme_provider.dart';
import 'auth_screen.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/step_service.dart';
import '../services/notification_service.dart';
import '../widgets/circular_reveal_transition.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey _themeToggleKey = GlobalKey();
  int totalHabits = 0;
  int completedHabits = 0;
  double attendancePercent = 0;
  static String _userName = '';
  static String? _userPhotoUrl;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

  // Water & Health State
  int _waterGlasses = 0;
  int _waterTarget = 8;
  final StepService _stepService = StepService();

  // PageView controller for swipeable Focus Cards
  final PageController _focusPageController = PageController(
    viewportFraction: 0.88,
  );
  int _focusPageIndex = 0;

  final List<String> _dailyQuotes = [
    "✨ Start by adding your first habit!",
    "🔥 Amazing! All habits completed today.",
    "💪 Let’s get started. One habit is enough!",
    "⚡ Keep going! You're building consistency.",
    "🌟 Small steps lead to big achievements!",
    "🏆 Consistency is the key to success!",
    "🌈 Every day is a new opportunity!",
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
    // Pre-populate name immediately synchronously on state creation
    final user = AuthService().currentUser;
    if (user != null && _userName.isEmpty) {
      if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
        _userName = user.displayName!.trim();
      } else if (user.email != null) {
        _userName = user.email!.split('@').first;
      }
    }
    _loadData();
    _listenToUserProfile();
    _initHealthServices();
  }

  void _listenToUserProfile() {
    final user = AuthService().currentUser;
    if (user == null) return;

    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || doc.data() == null) return;
      final data = doc.data()!;
      final cloudAvatar = data['avatarBase64'] as String?;
      final customName = (data['displayName'] ?? '').toString().trim();

      bool changed = false;
      if (cloudAvatar != null && cloudAvatar.isNotEmpty && cloudAvatar != _userPhotoUrl) {
        _userPhotoUrl = cloudAvatar;
        changed = true;
      }
      if (customName.isNotEmpty && customName != _userName) {
        _userName = customName;
        changed = true;
      }

      if (changed && mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _initHealthServices() async {
    await _stepService.init();
    await NotificationService.scheduleWaterReminders();
    _stepService.todaySteps.addListener(() {
      if (mounted) setState(() {});
    });
    _stepService.targetSteps.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadData() async {
    final dbService = DatabaseService();
    final habits = await dbService.loadHabits();
    final subjects = await dbService.loadSubjects();
    final health = await dbService.loadDailyHealth();

    totalHabits = habits.length;
    completedHabits = habits.where((h) => h['doneToday'] == true).length;

    double present = 0;
    int total = 0;

    for (final s in subjects) {
      present += (s['present'] ?? 0).toDouble();
      total += (s['total'] ?? 0) as int;
    }

    attendancePercent = total == 0 ? 0 : (present / total) * 100;

    _waterGlasses = health['waterGlasses'] ?? 0;
    _waterTarget = health['waterTarget'] ?? 8;

    // Load User Name & Photo immediately from cache/auth
    final currentUser = AuthService().currentUser;
    if (currentUser != null) {
      if (_userName.isEmpty) {
        if (currentUser.displayName != null &&
            currentUser.displayName!.trim().isNotEmpty) {
          _userName = currentUser.displayName!.trim();
        } else if (currentUser.email != null) {
          _userName = currentUser.email!.split('@').first;
        }
      }

      // Always fetch latest name & avatar from Firestore to reflect edits immediately
      if (currentUser.displayName != null &&
          currentUser.displayName!.trim().isNotEmpty) {
        _userName = currentUser.displayName!.trim();
      } else if (_userName.isEmpty && currentUser.email != null) {
        _userName = currentUser.email!.split('@').first;
      }

      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final cloudAvatar = data['avatarBase64'] as String?;
          if (cloudAvatar != null && cloudAvatar.isNotEmpty) {
            _userPhotoUrl = cloudAvatar;
          }
          final customName = (data['displayName'] ?? '').toString().trim();
          if (customName.isNotEmpty) {
            _userName = customName;
          }
        }
      } catch (_) {}
    }

    if (mounted) setState(() {});
  }

  Future<void> _drinkWater() async {
    setState(() {
      _waterGlasses++;
    });

    final dbService = DatabaseService();
    await dbService.saveDailyHealth(
      waterGlasses: _waterGlasses,
      waterTarget: _waterTarget,
      stepsCount: _stepService.todaySteps.value,
      stepsTarget: _stepService.targetSteps.value,
    );

    if (_waterGlasses == _waterTarget) {
      NotificationService.showWaterGoalReached(_waterTarget);
    }
  }

  Future<void> _undoWater() async {
    if (_waterGlasses <= 0) return;
    setState(() {
      _waterGlasses--;
    });

    final dbService = DatabaseService();
    await dbService.saveDailyHealth(
      waterGlasses: _waterGlasses,
      waterTarget: _waterTarget,
      stepsCount: _stepService.todaySteps.value,
      stepsTarget: _stepService.targetSteps.value,
    );
  }

  void _showSetWaterTargetDialog() {
    int tempTarget = _waterTarget;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Daily Water Target'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'How many glasses (approx 250ml) do you want to drink per day?',
            ),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (ctx, setLocal) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: tempTarget > 1
                        ? () => setLocal(() => tempTarget--)
                        : null,
                  ),
                  Text(
                    '$tempTarget glasses',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: tempTarget < 25
                        ? () => setLocal(() => tempTarget++)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              setState(() => _waterTarget = tempTarget);
              Navigator.pop(ctx);
              await DatabaseService().saveDailyHealth(
                waterGlasses: _waterGlasses,
                waterTarget: _waterTarget,
                stepsCount: _stepService.todaySteps.value,
                stepsTarget: _stepService.targetSteps.value,
              );
            },
            child: const Text('Save Target'),
          ),
        ],
      ),
    );
  }

  void _showSetStepsTargetDialog() {
    int tempTarget = _stepService.targetSteps.value;
    final controller = TextEditingController(text: tempTarget.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Daily Steps Target'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your target steps for today:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'e.g. 6000',
                suffixText: 'steps',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed != null && parsed > 0) {
                _stepService.setTarget(parsed);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save Target'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _focusPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDark;

    final formattedDate = DateFormat('EEEE, MMM d, y').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 18),
          child: Center(
            child: GestureDetector(
              onTap: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
                if (result == true || mounted) {
                  _loadData();
                }
              },
              child: CircleAvatar(
                radius: 20,
                backgroundColor: isDark
                    ? const Color(0xFF2C2C2C)
                    : const Color(0xFFE2E8F0),
                backgroundImage: _userPhotoUrl != null
                    ? (_userPhotoUrl!.startsWith('http')
                          ? NetworkImage(_userPhotoUrl!)
                          : MemoryImage(base64Decode(_userPhotoUrl!))
                                as ImageProvider)
                    : null,
                child: _userPhotoUrl == null
                    ? Text(
                        _userName.isNotEmpty ? _userName[0].toUpperCase() : "U",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
        title: const Text(
          "StreakUp",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            key: _themeToggleKey,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => RotationTransition(
                turns: Tween<double>(begin: 0.75, end: 1.0).animate(anim),
                child: ScaleTransition(
                  scale: anim,
                  child: child,
                ),
              ),
              child: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                key: ValueKey<bool>(isDark),
              ),
            ),
            onPressed: () {
              final reveal = CircularThemeReveal.of(context);
              if (reveal != null) {
                reveal.triggerReveal(
                  iconKey: _themeToggleKey,
                  onToggle: themeProvider.toggleTheme,
                );
              } else {
                themeProvider.toggleTheme();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                _userName = '';
                _userPhotoUrl = null;
                await AuthService().signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                    (route) => false,
                  );
                }
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'home_fab',
        onPressed: () => _showFabMenu(context),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            24,
          ), // ✅ extra bottom space
          children: [
            Text(
              formattedDate,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Flexible(
                  child: Text(
                    _userName.isNotEmpty
                        ? "Welcome Back, $_userName"
                        : "Welcome Back",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SvgPicture.asset(
                  'assets/icons/welcome_icon.svg',
                  width: 22,
                  height: 22,
                  colorFilter: ColorFilter.mode(
                    isDark ? Colors.white : Colors.black87,
                    BlendMode.srcIn,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's Focus",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  _focusPageIndex == 0 ? "Habits" : "Attendance",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 💳 SWIPEABLE CREDIT-CARD STYLE CARDS
            SizedBox(
              height: 195,
              child: PageView(
                controller: _focusPageController,
                onPageChanged: (i) => setState(() => _focusPageIndex = i),
                children: [
                  _swipeCard(
                    title: "Streak Momentum",
                    subtitle: "Daily Habits",
                    mainValue: "${totalHabits - completedHabits} Left",
                    progressPercent: totalHabits == 0
                        ? 0.0
                        : (completedHabits / totalHabits),
                    progressLabel: "$completedHabits of $totalHabits completed",
                    gradientColors: [
                      const Color(0xFF6366F1),
                      const Color(0xFF4338CA),
                    ], // Ambient Indigo Glow
                    iconSvg: 'assets/icons/fire_icon.svg',
                    badgeText: totalHabits == completedHabits && totalHabits > 0
                        ? "DONE 🔥"
                        : "ACTIVE",
                  ),
                  _swipeCard(
                    title: "Class Attendance",
                    subtitle: "Academic Streak",
                    mainValue: "${attendancePercent.toStringAsFixed(1)}%",
                    progressPercent: (attendancePercent / 100).clamp(0.0, 1.0),
                    progressLabel: attendancePercent >= 75
                        ? "Safe threshold (≥75%)"
                        : "Below 75% goal",
                    gradientColors: [
                      const Color(0xFF0EA5E9),
                      const Color(0xFF0284C7),
                    ], // Ambient Sky Blue Glow
                    iconData: Icons.school_rounded,
                    badgeText: attendancePercent >= 75 ? "HEALTHY" : "CRITICAL",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Pagination Dots (Matching reference mockup "Physical Card •••")
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [_buildDot(0), const SizedBox(width: 6), _buildDot(1)],
            ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Health & Hydration",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => _showHealthSettings(context),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text("Targets"),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 💧 WATER TRACKER CARD
            _waterTrackerCard(isDark),

            const SizedBox(height: 12),

            // 🚶‍♂️ STEPS COUNTER CARD
            _stepsTrackerCard(isDark),

            const SizedBox(height: 28),
            const Text(
              "Daily Motivation",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

  // ---------------------------------------------------------------------------
  // 🍎 MAC GLASSMORPHIC SWIPEABLE CARDS
  // ---------------------------------------------------------------------------
  Widget _swipeCard({
    required String title,
    required String subtitle,
    required String mainValue,
    required double progressPercent,
    required String progressLabel,
    required List<Color> gradientColors,
    IconData? iconData,
    String? iconSvg,
    required String badgeText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(28)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              // Translucent frosted glass tint + ambient gradient
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        gradientColors.first.withValues(alpha: 0.35),
                        const Color(0xFF1E1E24).withValues(alpha: 0.70),
                      ]
                    : [
                        gradientColors.first.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.65),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              // Frosted glass border (light rim reflect)
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.85),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white60
                                : const Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    // Glass Pill Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.black.withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (iconSvg != null)
                            SvgPicture.asset(
                              iconSvg,
                              width: 13,
                              height: 13,
                              colorFilter: ColorFilter.mode(
                                isDark
                                    ? Colors.orangeAccent
                                    : const Color(0xFFEA580C),
                                BlendMode.srcIn,
                              ),
                            )
                          else if (iconData != null)
                            Icon(
                              iconData,
                              color: isDark
                                  ? Colors.blueAccent
                                  : const Color(0xFF2563EB),
                              size: 14,
                            ),
                          const SizedBox(width: 5),
                          Text(
                            badgeText,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Main Center Value
                Text(
                  mainValue,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4,
                  ),
                ),

                // Bottom Progress Bar & Details
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progressPercent.clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      progressLabel,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white60
                            : const Color(0xFF64748B),
                        fontSize: 10.5,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    final bool active = _focusPageIndex == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: active ? 18 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? Colors.black87 : Colors.grey[400],
        borderRadius: BorderRadius.circular(3),
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
          const Icon(Icons.auto_awesome, color: Colors.white, size: 36),
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

  // ---------------------------------------------------------------------------
  // 💧 WATER TRACKER CARD
  // ---------------------------------------------------------------------------
  Widget _waterTrackerCard(bool isDark) {
    final double waterPercent = _waterTarget > 0
        ? (_waterGlasses / _waterTarget).clamp(0.0, 1.0)
        : 0.0;
    final bool goalDone = _waterGlasses >= _waterTarget;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.water_drop_rounded,
                      color: Colors.blue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Water Intake",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        goalDone
                            ? "Goal Reached! 🎉"
                            : "$_waterGlasses of $_waterTarget glasses",
                        style: TextStyle(
                          fontSize: 13,
                          color: goalDone ? Colors.blue : Colors.grey[600],
                          fontWeight: goalDone
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  if (_waterGlasses > 0)
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.grey,
                      ),
                      tooltip: 'Undo glass',
                      onPressed: _undoWater,
                    ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    onPressed: _drinkWater,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      "+1 Glass",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: waterPercent,
              minHeight: 10,
              backgroundColor: Colors.blue.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Colors.blueAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🚶‍♂️ STEPS COUNTER CARD
  // ---------------------------------------------------------------------------
  Widget _stepsTrackerCard(bool isDark) {
    return ValueListenableBuilder<int>(
      valueListenable: _stepService.todaySteps,
      builder: (context, steps, _) {
        final target = _stepService.targetSteps.value;
        final double stepsPercent = target > 0
            ? (steps / target).clamp(0.0, 1.0)
            : 0.0;
        final bool goalDone = steps >= target;

        // Estimated km and calories
        final double km = (steps * 0.00076);
        final int kcal = (steps * 0.04).round();

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.directions_walk_rounded,
                          color: Colors.amber,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Step Counter",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            goalDone
                                ? "Target Achieved! 🏆"
                                : "$steps / $target steps",
                            style: TextStyle(
                              fontSize: 13,
                              color: goalDone
                                  ? Colors.amber[800]
                                  : Colors.grey[600],
                              fontWeight: goalDone
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.sync_rounded,
                          color: Colors.blueAccent,
                        ),
                        tooltip: 'Sync Google Fit / Health Connect',
                        onPressed: () async {
                          final result = await _stepService.syncWithGoogleFit();
                          if (!context.mounted) return;

                          if (result == "NEEDS_SETTINGS") {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  "Permission needed: Tap Settings to turn on Health Connect access.",
                                ),
                                backgroundColor: const Color(0xFF0F172A),
                                duration: const Duration(seconds: 5),
                                action: SnackBarAction(
                                  label: "Settings",
                                  textColor: Colors.blueAccent,
                                  onPressed: () => _stepService.openHealthConnectSettings(),
                                ),
                              ),
                            );
                            // Open settings directly for convenience
                            await _stepService.openHealthConnectSettings();
                          } else if (result == "NEEDS_PLAYSTORE") {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  "Health Connect is not installed. Opening Google Play Store...",
                                ),
                                backgroundColor: Colors.orange[800]!,
                                duration: const Duration(seconds: 5),
                                action: SnackBarAction(
                                  label: "Install",
                                  textColor: Colors.white,
                                  onPressed: () => _stepService.openHealthConnectPlayStore(),
                                ),
                              ),
                            );
                          } else if (result.startsWith("SUCCESS:")) {
                            final count = result.split(":").last;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Synced $count steps from Health Connect!"),
                                backgroundColor: Colors.green[700]!,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result),
                                backgroundColor: Colors.orangeAccent[700]!,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.amber,
                        ),
                        tooltip: 'Add manual steps (+500)',
                        onPressed: () => _stepService.addManualSteps(500),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: stepsPercent,
                  minHeight: 10,
                  backgroundColor: Colors.amber.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "📍 ${km.toStringAsFixed(2)} km",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Row(
                    children: [
                      SvgPicture.asset(
                        'assets/icons/fire_icon.svg',
                        width: 14,
                        height: 14,
                        colorFilter: const ColorFilter.mode(
                          Colors.orange,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "$kcal kcal burned",
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHealthSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          runSpacing: 12,
          children: [
            const Text(
              "Set Daily Health Targets",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.water_drop, color: Colors.blue),
              title: const Text("Daily Water Target"),
              subtitle: Text("Current: $_waterTarget glasses"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _showSetWaterTargetDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_walk, color: Colors.amber),
              title: const Text("Daily Step Target"),
              subtitle: Text(
                "Current: ${_stepService.targetSteps.value} steps",
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _showSetStepsTargetDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFabMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                MaterialPageRoute(builder: (_) => const HabitScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text("View Stats"),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatsScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.school),
              title: const Text("Attendance"),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AttendanceScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
