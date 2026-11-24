import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CircleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;
  String get today => DateTime.now().toIso8601String().substring(0, 10);

  // Generate a friendly 6-character code (e.g., STK892)
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  // Stream user's joined circles
  Stream<QuerySnapshot<Map<String, dynamic>>> streamUserCircles() {
    final uid = currentUid;
    if (uid == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('circles')
        .where('members', arrayContains: uid)
        .snapshots();
  }

  // Stream members of a specific circle
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamCircle(String circleId) {
    return _firestore.collection('circles').doc(circleId).snapshots();
  }

  // Helper to fetch user's synced avatar (from users doc or auth)
  Future<String> _getUserAvatar(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final avatar = doc.data()!['avatarBase64'] as String?;
        if (avatar != null && avatar.isNotEmpty) {
          return avatar;
        }
      }
    } catch (_) {}
    return _auth.currentUser?.photoURL ?? '';
  }

  // Create a new StreakUP Circle
  Future<String> createCircle({
    required String name,
    required String emoji,
    required String description,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    final inviteCode = _generateInviteCode();
    final docRef = _firestore.collection('circles').doc();
    final avatar = await _getUserAvatar(user.uid);

    final memberInfo = {
      'uid': user.uid,
      'name': user.displayName ?? (user.email?.split('@').first ?? 'User'),
      'avatar': avatar,
      'joinedAt': DateTime.now().toIso8601String(),
      'lastCompletedDate': today,
      'habitsDoneToday': 0,
      'totalHabits': 0,
    };

    await docRef.set({
      'id': docRef.id,
      'name': name.trim(),
      'emoji': emoji,
      'description': description.trim(),
      'inviteCode': inviteCode,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'members': [user.uid],
      'memberDetails': {
        user.uid: memberInfo,
      },
    });

    return docRef.id;
  }

  // Join an existing circle via 6-digit invite code
  Future<Map<String, dynamic>> joinCircleByCode(String code) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    final cleanCode = code.trim().toUpperCase();
    final query = await _firestore
        .collection('circles')
        .where('inviteCode', isEqualTo: cleanCode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception("Invalid invite code. No circle found.");
    }

    final doc = query.docs.first;
    final data = doc.data();
    final List members = data['members'] ?? [];

    if (members.contains(user.uid)) {
      return {'id': doc.id, 'name': data['name'], 'alreadyJoined': true};
    }

    final avatar = await _getUserAvatar(user.uid);
    final memberInfo = {
      'uid': user.uid,
      'name': user.displayName ?? (user.email?.split('@').first ?? 'User'),
      'avatar': avatar,
      'joinedAt': DateTime.now().toIso8601String(),
      'lastCompletedDate': '',
      'habitsDoneToday': 0,
      'totalHabits': 0,
    };

    await doc.reference.update({
      'members': FieldValue.arrayUnion([user.uid]),
      'memberDetails.${user.uid}': memberInfo,
    });

    return {'id': doc.id, 'name': data['name'], 'alreadyJoined': false};
  }

  // Update member's progress in all their circles when they complete a habit
  Future<void> syncMemberProgress({
    required int completed,
    required int total,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final circles = await _firestore
          .collection('circles')
          .where('members', arrayContains: user.uid)
          .get();

      final avatar = await _getUserAvatar(user.uid);
      final batch = _firestore.batch();
      for (final doc in circles.docs) {
        batch.update(doc.reference, {
          'memberDetails.${user.uid}.habitsDoneToday': completed,
          'memberDetails.${user.uid}.totalHabits': total,
          'memberDetails.${user.uid}.lastCompletedDate': today,
          'memberDetails.${user.uid}.avatar': avatar,
          'memberDetails.${user.uid}.name':
              user.displayName ?? (user.email?.split('@').first ?? 'User'),
        });
      }
      await batch.commit();
    } catch (_) {}
  }

  // Send a friendly "Nudge" to a circle member who hasn't completed their habits
  Future<void> sendNudge({
    required String circleId,
    required String targetUid,
    required String targetName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final senderName = user.displayName ?? (user.email?.split('@').first ?? 'Friend');

    await _firestore.collection('nudges').add({
      'circleId': circleId,
      'fromUid': user.uid,
      'fromName': senderName,
      'toUid': targetUid,
      'toName': targetName,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  // Remove a member from circle (Admin action)
  Future<void> removeMember({
    required String circleId,
    required String targetUid,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('circles').doc(circleId).get();
    if (!doc.exists) return;
    final createdBy = doc.data()?['createdBy'];

    // Only creator/admin can remove members
    if (createdBy != user.uid) {
      throw Exception("Only the Circle Admin can remove members.");
    }

    await doc.reference.update({
      'members': FieldValue.arrayRemove([targetUid]),
      'memberDetails.$targetUid': FieldValue.delete(),
    });
  }

  // Delete the circle completely (Admin action when all other members are removed)
  Future<void> deleteCircle(String circleId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('circles').doc(circleId).get();
    if (!doc.exists) return;

    final data = doc.data() ?? {};
    final createdBy = data['createdBy'];
    final List members = data['members'] ?? [];

    if (createdBy != user.uid) {
      throw Exception("Only the Circle Admin can delete this circle.");
    }

    // Check if other members are still present
    final otherMembers = members.where((m) => m != user.uid).toList();
    if (otherMembers.isNotEmpty) {
      throw Exception("Please remove all other members before deleting this circle.");
    }

    await doc.reference.delete();
  }

  // Leave a circle
  Future<void> leaveCircle(String circleId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('circles').doc(circleId).update({
      'members': FieldValue.arrayRemove([user.uid]),
      'memberDetails.${user.uid}': FieldValue.delete(),
    });
  }
}
