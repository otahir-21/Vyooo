import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'email_otp_service.dart';
import 'push_messaging_service.dart';

/// Result of an auth operation. No raw Firebase exceptions exposed to UI.
class AuthResult {
  const AuthResult({required this.success, this.message, this.user});

  final bool success;
  final String? message;
  final User? user;
}

/// Centralized Firebase Authentication logic.
/// No UI imports, no BuildContext, no Navigator.
/// Screens must use this service instead of calling Firebase directly.
class AuthService {
  AuthService._();
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  /// Current signed-in user, or null.
  User? get currentUser => _auth.currentUser;

  /// Register with email and password.
  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AuthResult(success: true, user: cred.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _mapAuthException(e.code));
    } catch (e) {
      return AuthResult(success: false, message: _genericMessage(e));
    }
  }

  /// Sign in with email and password.
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AuthResult(success: true, user: cred.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _mapAuthException(e.code));
    } catch (e) {
      return AuthResult(success: false, message: _genericMessage(e));
    }
  }

  /// Send verification email to current user.
  Future<AuthResult> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return const AuthResult(success: false, message: 'No user signed in.');
      }
      await user.sendEmailVerification();
      return AuthResult(success: true, user: user);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _mapAuthException(e.code));
    } catch (e) {
      return AuthResult(success: false, message: _genericMessage(e));
    }
  }

  /// Send password reset email to the given address.
  Future<AuthResult> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return const AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _mapAuthException(e.code));
    } catch (e) {
      return AuthResult(success: false, message: _genericMessage(e));
    }
  }

  /// Sends a 4-digit OTP to the signed-in user's email (Firestore trigger + Resend).
  Future<AuthResult> sendSignupEmailOtp() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return const AuthResult(success: false, message: 'No user signed in.');
      }
      await EmailOtpService().requestSendOtp();
      return AuthResult(success: true, user: user);
    } catch (e) {
      return AuthResult(success: false, message: _genericMessage(e));
    }
  }

  /// Verifies the email OTP and sets [emailOtpVerified] on the user profile (server).
  Future<AuthResult> verifySignupEmailOtp(String code) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return const AuthResult(success: false, message: 'No user signed in.');
      }
      await EmailOtpService().verifyOtp(code);
      return AuthResult(success: true, user: user);
    } catch (e) {
      return AuthResult(success: false, message: _genericMessage(e));
    }
  }

  /// Confirm password reset using the code from the reset email link.
  Future<AuthResult> confirmPasswordReset({
    required String oobCode,
    required String newPassword,
  }) async {
    try {
      await _auth.confirmPasswordReset(code: oobCode, newPassword: newPassword);
      return const AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _mapAuthException(e.code));
    } catch (e) {
      return AuthResult(success: false, message: _genericMessage(e));
    }
  }

  /// Change current user's password by reauthenticating with current password.
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return const AuthResult(success: false, message: 'No user signed in.');
      }
      final email = user.email;
      if (email == null || email.isEmpty) {
        return const AuthResult(
          success: false,
          message: 'Password change is not available for this account.',
        );
      }

      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      return const AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return const AuthResult(
          success: false,
          message: 'Your current password is not correct.',
        );
      }
      return AuthResult(success: false, message: _mapAuthException(e.code));
    } catch (e) {
      return AuthResult(success: false, message: _genericMessage(e));
    }
  }

  /// Sign in with Apple ID (iOS). Uses Firebase OAuth + nonce for security.
  Future<AuthResult> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // Apple only shares the name on the very first sign-in.
      final fullName = [appleCredential.givenName, appleCredential.familyName]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ');
      if (fullName.isNotEmpty) {
        await userCredential.user?.updateDisplayName(fullName);
      }

      return AuthResult(success: true, user: userCredential.user);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return const AuthResult(success: false, message: '');
      }
      return AuthResult(success: false, message: 'Apple sign-in failed.');
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _mapAuthException(e.code));
    } catch (e) {
      return AuthResult(success: false, message: _genericMessage(e));
    }
  }

  /// Sign in with Google.
  Future<AuthResult> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn.instance;
    try {
      // Primary path: GoogleSignIn plugin then Firebase credential sign-in.
      // This gives us explicit control over cancellation and token handling.
      await googleSignIn.initialize();
      final googleUser = await googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;
      if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
        throw Exception('Google authentication did not return tokens.');
      }
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      return AuthResult(success: true, user: userCredential.user);
    } on GoogleSignInException catch (e) {
      // User dismissed the account picker.
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const AuthResult(success: false, message: '');
      }
      debugPrint('GoogleSignInException: ${e.code} ${e.description}');
      // Try provider-based fallback before surfacing an error.
      final fallback = await _signInWithGoogleProviderFallback();
      if (fallback.success) return fallback;
      return AuthResult(
        success: false,
        message: fallback.message ?? 'Google sign-in failed.',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _mapAuthException(e.code));
    } catch (e) {
      final fallback = await _signInWithGoogleProviderFallback();
      if (fallback.success) return fallback;
      debugPrint('Google sign-in fallback failed after primary error: $e');
      return AuthResult(
        success: false,
        message: fallback.message ??
            'Google sign-in failed. Check Firebase Google provider and Android SHA settings.',
      );
    }
  }

  Future<AuthResult> _signInWithGoogleProviderFallback() async {
    try {
      final provider = GoogleAuthProvider();
      provider.setCustomParameters({'prompt': 'select_account'});
      final userCredential = await _auth.signInWithProvider(provider);
      return AuthResult(success: true, user: userCredential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _mapAuthException(e.code));
    } catch (e) {
      return AuthResult(
        success: false,
        message:
            'Google sign-in failed. Check Firebase Google provider and Android SHA settings.',
      );
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      await PushMessagingService.instance.clearForSignOut(uid);
    }
    await _auth.signOut();
  }

  /// Permanently deletes current user's app data and then their auth account.
  ///
  /// Note: Firebase may require recent login for the final auth delete step.
  Future<AuthResult> deleteCurrentAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const AuthResult(success: false, message: 'No user signed in.');
    }
    final uid = user.uid;
    final db = FirebaseFirestore.instance;

    try {
      // 1) Delete user-owned reels + nested comments.
      final reels = await db.collection('reels').where('userId', isEqualTo: uid).get();
      for (final reel in reels.docs) {
        await _deleteSubcollection(
          db.collection('reels').doc(reel.id).collection('comments'),
        );
        await reel.reference.delete();
      }

      // 2) Delete supporting docs created by this user.
      await _deleteQueryDocs(db.collection('verification_requests').where('uid', isEqualTo: uid));
      await _deleteQueryDocs(db.collection('cloudflare_upload_requests').where('userId', isEqualTo: uid));
      await _deleteQueryDocs(db.collection('token_requests').where('userId', isEqualTo: uid));
      await _deleteQueryDocs(db.collection('email_otp_send_requests').where('userId', isEqualTo: uid));
      await _deleteQueryDocs(db.collection('email_otp_verify_requests').where('userId', isEqualTo: uid));
      await db.collection('email_otp_challenges').doc(uid).delete().catchError((_) {});

      // 3) Remove this uid from other users' arrays.
      await _removeUidFromUserArray('following', uid);
      await _removeUidFromUserArray('blockedUsers', uid);

      // 4) Delete user profile doc.
      await db.collection('users').doc(uid).delete().catchError((_) {});

      // 5) Best-effort delete user storage folder.
      await FirebaseStorage.instance.ref().child('users/$uid').listAll().then((root) async {
        for (final item in root.items) {
          await item.delete().catchError((_) {});
        }
        for (final prefix in root.prefixes) {
          await _deleteStorageFolder(prefix);
        }
      }).catchError((_) {});

      // 6) Clear push token + auth account.
      await PushMessagingService.instance.clearForSignOut(uid);
      await user.delete();

      return const AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return const AuthResult(
          success: false,
          message: 'For security, please log in again and then delete your account.',
        );
      }
      return AuthResult(success: false, message: _mapAuthException(e.code));
    } catch (e) {
      return AuthResult(success: false, message: _genericMessage(e));
    }
  }

  Future<void> _deleteSubcollection(CollectionReference<Map<String, dynamic>> ref) async {
    while (true) {
      final snap = await ref.limit(200).get();
      if (snap.docs.isEmpty) break;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteQueryDocs(Query<Map<String, dynamic>> query) async {
    while (true) {
      final snap = await query.limit(200).get();
      if (snap.docs.isEmpty) break;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _removeUidFromUserArray(String field, String uid) async {
    while (true) {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where(field, arrayContains: uid)
          .limit(200)
          .get();
      if (snap.docs.isEmpty) break;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {
          field: FieldValue.arrayRemove([uid]),
        });
      }
      await batch.commit();
    }
  }

  Future<void> _deleteStorageFolder(Reference folderRef) async {
    final list = await folderRef.listAll();
    for (final item in list.items) {
      await item.delete().catchError((_) {});
    }
    for (final nested in list.prefixes) {
      await _deleteStorageFolder(nested);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
        length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static String _mapAuthException(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'email-already-in-use':
        return 'Email already registered. If you used Google, continue with Google sign-in.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Invalid email or password. If this email was created with Google, use Google sign-in first.';
      case 'operation-not-allowed':
        return 'Sign-in method is not enabled.';
      case 'account-exists-with-different-credential':
        return 'This email is already linked with a different sign-in method.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'expired-action-code':
        return 'Reset link has expired. Please request a new one.';
      case 'invalid-action-code':
        return 'Invalid or already used reset link.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  static String _genericMessage(Object e) {
    var s = e.toString();
    if (s.startsWith('Exception: ')) {
      s = s.substring('Exception: '.length);
    }
    if (s.isEmpty) return 'Something went wrong. Please try again.';
    return s;
  }
}
