import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import 'user_service.dart';

/// Firebase Storage operations. No UI, no BuildContext.
/// Do NOT store file locally long-term; upload and use download URL.
class StorageService {
  StorageService._();
  static final StorageService _instance = StorageService._();
  factory StorageService() => _instance;

  final UserService _userService = UserService();

  static String _profilePath(String uid) => 'users/$uid/profile.jpg';
  static String _verificationPdfPath(String uid, String requestRef) =>
      'users/$uid/verification_requests/$requestRef.pdf';

  /// Uploads profile image to users/{uid}/profile.jpg, returns download URL.
  /// After upload, updates Firestore user document with [UserService.updateUserProfile(profileImage: downloadURL)].
  Future<String> uploadProfileImage({
    required File imageFile,
    required String uid,
  }) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(_profilePath(uid));
      await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final downloadUrl = await ref.getDownloadURL();
      await _userService.updateUserProfile(uid: uid, profileImage: downloadUrl);
      return downloadUrl;
    } catch (e) {
      rethrow;
    }
  }

  /// Returns download URL for current profile image if it exists. Does not upload.
  Future<String?> getProfileImageUrl(String uid) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(_profilePath(uid));
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  /// Uploads verification PDF and returns public download URL.
  Future<String> uploadVerificationPdf({
    required File pdfFile,
    required String uid,
    required String requestRef,
  }) async {
    final ref = FirebaseStorage.instance.ref().child(
      _verificationPdfPath(uid, requestRef),
    );
    await ref.putFile(
      pdfFile,
      SettableMetadata(contentType: 'application/pdf'),
    );
    return await ref.getDownloadURL();
  }
}
