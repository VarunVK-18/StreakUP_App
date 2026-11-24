import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class ProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  String? get currentUid => _auth.currentUser?.uid;

  // Stream current user profile data (including base64 avatar)
  Stream<DocumentSnapshot<Map<String, dynamic>>>? streamUserProfile() {
    final uid = currentUid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).snapshots();
  }

  // Save pre-cropped PNG/JPEG bytes to Cloud Firestore
  Future<String?> saveAvatarBytes(List<int> bytes) async {
    final uid = currentUid;
    if (uid == null) return null;

    final base64String = base64Encode(bytes);
    await _firestore.collection('users').doc(uid).set({
      'avatarBase64': base64String,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return base64String;
  }

  // Pick an image, compress to lightweight Base64, and save to Cloud Firestore (100% Free - No Blaze Plan Needed!)
  Future<String?> pickAndUploadAvatar({required ImageSource source}) async {
    final uid = currentUid;
    if (uid == null) return null;

    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 180,
      maxHeight: 180,
      imageQuality: 65,
    );

    if (pickedFile == null) return null;

    final bytes = await pickedFile.readAsBytes();
    final base64String = base64Encode(bytes);

    // Save directly into the user's Firestore document
    await _firestore.collection('users').doc(uid).set({
      'avatarBase64': base64String,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return base64String;
  }
}
