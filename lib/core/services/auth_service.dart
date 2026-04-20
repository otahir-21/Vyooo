import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
