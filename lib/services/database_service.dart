import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

  // ---------------------------------------------------------------------------
  // 🔹 HABITS
  // ---------------------------------------------------------------------------
  CollectionReference<Map<String, dynamic>>? get _habitsRef {
    final uid = currentUid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('habits');
  }

  // Stream habits in real-time
  Stream<List<Map<String, dynamic>>> streamHabits() {
    final ref = _habitsRef;
    if (ref == null) return const Stream.empty();
    return ref.orderBy('createdAt', descending: false).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // Save/Update full habits list (and cache to shared_preferences for offline fast-boot)
  Future<void> saveHabits(List<Map<String, dynamic>> habits) async {
    // 1. Local cache
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('habits', json.encode(habits));

    // 2. Cloud Firestore sync
    final ref = _habitsRef;
    if (ref == null) return;

    final batch = _firestore.batch();
    for (int i = 0; i < habits.length; i++) {
      final h = habits[i];
      final docId = h['id']?.toString() ?? 'habit_$i';
      final docRef = ref.doc(docId);
      final payload = Map<String, dynamic>.from(h);
      payload.remove('id');
      if (!payload.containsKey('createdAt')) {
        payload['createdAt'] = FieldValue.serverTimestamp();
      }
      batch.set(docRef, payload, SetOptions(merge: true));
    }
    await batch.commit();
  }

  // Delete habit from cloud and local
  Future<void> deleteHabit(String docId, List<Map<String, dynamic>> updatedList) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('habits', json.encode(updatedList));

    final ref = _habitsRef;
    if (ref != null) {
      await ref.doc(docId).delete();
    }
  }

  // Load habits: first checks Firestore, falls back to SharedPreferences if offline
  Future<List<Map<String, dynamic>>> loadHabits() async {
    final ref = _habitsRef;
    if (ref != null) {
      try {
        final snapshot = await ref.orderBy('createdAt', descending: false).get();
        if (snapshot.docs.isNotEmpty) {
          final list = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();

          // Sync to cache
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('habits', json.encode(list));
          return list;
        }
      } catch (e) {
        // Fallback to local cache if network error
      }
    }

    // Fallback
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('habits');
    if (data != null) {
      return List<Map<String, dynamic>>.from(json.decode(data));
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // 🔹 ATTENDANCE (SUBJECTS)
  // ---------------------------------------------------------------------------
  CollectionReference<Map<String, dynamic>>? get _subjectsRef {
    final uid = currentUid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('attendance');
  }

  // Save/Update subjects to cloud & local
  Future<void> saveSubjects(List<Map<String, dynamic>> subjects) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('subjects', json.encode(subjects));

    final ref = _subjectsRef;
    if (ref == null) return;

    final batch = _firestore.batch();
    for (int i = 0; i < subjects.length; i++) {
      final s = subjects[i];
      final docId = s['id']?.toString() ?? 'subject_$i';
      final docRef = ref.doc(docId);
      final payload = Map<String, dynamic>.from(s);
      payload.remove('id');
      batch.set(docRef, payload, SetOptions(merge: true));
    }
    await batch.commit();
  }

  // Delete subject
  Future<void> deleteSubject(String docId, List<Map<String, dynamic>> updatedList) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('subjects', json.encode(updatedList));

    final ref = _subjectsRef;
    if (ref != null) {
      await ref.doc(docId).delete();
    }
  }

  // Load subjects
  Future<List<Map<String, dynamic>>> loadSubjects() async {
    final ref = _subjectsRef;
    if (ref != null) {
      try {
        final snapshot = await ref.get();
        if (snapshot.docs.isNotEmpty) {
          final list = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('subjects', json.encode(list));
          return list;
        }
      } catch (e) {
        // Fallback
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('subjects');
    if (data != null) {
      return List<Map<String, dynamic>>.from(json.decode(data));
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // 🔹 DAILY HEALTH TRACKING: WATER & STEPS
  // ---------------------------------------------------------------------------
  DocumentReference<Map<String, dynamic>>? get _todayHealthRef {
    final uid = currentUid;
    if (uid == null) return null;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return _firestore.collection('users').doc(uid).collection('health').doc(today);
  }

  // Save water & steps data
  Future<void> saveDailyHealth({
    required int waterGlasses,
    required int waterTarget,
    required int stepsCount,
    required int stepsTarget,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setInt('water_glasses_$today', waterGlasses);
    await prefs.setInt('water_target', waterTarget);
    await prefs.setInt('steps_count_$today', stepsCount);
    await prefs.setInt('steps_target', stepsTarget);

    final ref = _todayHealthRef;
    if (ref != null) {
      await ref.set({
        'date': today,
        'waterGlasses': waterGlasses,
        'waterTarget': waterTarget,
        'stepsCount': stepsCount,
        'stepsTarget': stepsTarget,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // Load today's health metrics
  Future<Map<String, int>> loadDailyHealth() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final prefs = await SharedPreferences.getInstance();

    int waterGlasses = prefs.getInt('water_glasses_$today') ?? 0;
    int waterTarget = prefs.getInt('water_target') ?? 8;
    int stepsCount = prefs.getInt('steps_count_$today') ?? 0;
    int stepsTarget = prefs.getInt('steps_target') ?? 6000;

    final ref = _todayHealthRef;
    if (ref != null) {
      try {
        final doc = await ref.get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          waterGlasses = (data['waterGlasses'] ?? waterGlasses) as int;
          waterTarget = (data['waterTarget'] ?? waterTarget) as int;
          stepsCount = (data['stepsCount'] ?? stepsCount) as int;
          stepsTarget = (data['stepsTarget'] ?? stepsTarget) as int;
        }
      } catch (_) {}
    }

    return {
      'waterGlasses': waterGlasses,
      'waterTarget': waterTarget,
      'stepsCount': stepsCount,
      'stepsTarget': stepsTarget,
    };
  }
}

