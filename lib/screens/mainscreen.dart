import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:streakup/screens/theme_provider.dart';
import 'package:streakup/screens/bottom_navigation_screen.dart';
import 'package:streakup/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.init();

  runApp(const StreakUpApp());
}

class StreakUpApp extends StatelessWidget {
  const StreakUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StreakUp',

      themeMode:
      themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme:
        ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
      ),

      home: const BottomNav(),
    );
  }
}
