import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Live-synced avatar widget for circle members.
/// Automatically pulls the member's latest base64 cropped avatar directly
/// from their Firestore `users/{uid}` document in real time!
class MemberAvatar extends StatelessWidget {
  final String uid;
  final String fallbackName;
  final String? cachedAvatar;

  const MemberAvatar({
    super.key,
    required this.uid,
    required this.fallbackName,
    this.cachedAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        String? avatarBase64 = cachedAvatar;

        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final data = snapshot.data!.data();
          if (data != null) {
            final cloudAvatar = data['avatarBase64'] as String?;
            if (cloudAvatar != null && cloudAvatar.isNotEmpty) {
              avatarBase64 = cloudAvatar;
            }
          }
        }

        ImageProvider? imageProvider;
        if (avatarBase64 != null && avatarBase64.isNotEmpty) {
          if (avatarBase64.startsWith('http')) {
            imageProvider = NetworkImage(avatarBase64);
          } else {
            try {
              imageProvider = MemoryImage(base64Decode(avatarBase64));
            } catch (_) {}
          }
        }

        return CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
          backgroundImage: imageProvider,
          child: imageProvider == null
              ? Text(
                  fallbackName.isNotEmpty ? fallbackName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        );
      },
    );
  }
}
