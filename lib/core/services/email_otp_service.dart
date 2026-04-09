import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Sends and verifies signup email OTP via Firestore-triggered Cloud Functions
/// (`processEmailOtpSendRequest` / `processEmailOtpVerifyRequest`).
///
/// Avoids HTTPS callables, which require Cloud Run `allUsers` invoker IAM that
/// Metatech org policy blocks — same pattern as [AgoraTokenService].
class EmailOtpService {
  EmailOtpService._();
  static final EmailOtpService _instance = EmailOtpService._();
  factory EmailOtpService() => _instance;

  /// Create `email_otp_send_requests/{id}` and wait until status is `done` or `error`.
  Future<void> requestSendOtp() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No user signed in.');
    }
    final ref = FirebaseFirestore.instance
        .collection('email_otp_send_requests')
        .doc();
    await ref.set({
      'userId': user.uid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _waitForRequest(ref,
        timeout: const Duration(seconds: 30),
        timeoutMessage: 'Could not send code. Try again.');
  }

  /// Create `email_otp_verify_requests/{id}` with a 4-digit [code].
  Future<void> verifyOtp(String code) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No user signed in.');
    }
    final digits = code.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 4) {
      throw Exception('Enter the 4-digit code.');
    }
    final ref = FirebaseFirestore.instance
        .collection('email_otp_verify_requests')
        .doc();
    await ref.set({
      'userId': user.uid,
      'code': digits,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _waitForRequest(ref,
        timeout: const Duration(seconds: 30),
        timeoutMessage: 'Verification timed out. Try again.');
  }

  static Future<void> _waitForRequest(
    DocumentReference<Map<String, dynamic>> ref, {
    required Duration timeout,
    required String timeoutMessage,
  }) async {
    final completer = Completer<void>();
    late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> sub;

    sub = ref.snapshots().listen(
      (snap) {
        if (!snap.exists) return;
        final data = snap.data();
        if (data == null) return;
        final status = data['status'] as String?;
        if (status == 'done') {
          unawaited(ref.delete());
          if (!completer.isCompleted) completer.complete();
        } else if (status == 'error') {
          unawaited(ref.delete());
          final err = data['error'] as String? ?? 'Request failed.';
          if (!completer.isCompleted) {
            completer.completeError(Exception(err));
          }
        }
      },
      onError: (Object e) {
        unawaited(ref.delete());
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    try {
      await completer.future.timeout(
        timeout,
        onTimeout: () {
          unawaited(ref.delete());
          throw Exception(timeoutMessage);
        },
      );
    } finally {
      sub.cancel();
    }
  }
}
