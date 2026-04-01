import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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

  /// Placeholder for phone or backend OTP verification. Implement when needed.
  Future<AuthResult> verifyOTP({String? verificationId, String? code}) async {
    // TODO: implement verifyPhoneNumber / signInWithCredential or backend OTP
    return const AuthResult(
      success: false,
      message: 'OTP verification not implemented yet.',
    );
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

  /// Sign out the current user.
  Future<void> signOut() async {
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
        return 'Email already registered.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Invalid email or password.';
      case 'operation-not-allowed':
        return 'Sign-in method is not enabled.';
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
    final s = e.toString();
    if (s.isEmpty) return 'Something went wrong. Please try again.';
    return s;
  }
}
