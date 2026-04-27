import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Sends and verifies signup WhatsApp OTP via Firestore-triggered Cloud Functions
/// (`processWhatsAppOtpSendRequest` / `processWhatsAppOtpVerifyRequest`).
class WhatsAppOtpService {
  WhatsAppOtpService._();
  static final WhatsAppOtpService _instance = WhatsAppOtpService._();
  factory WhatsAppOtpService() => _instance;

  Future<void> requestSendOtp({required String phoneNumber}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No user signed in.');
    }
    final normalizedPhone = phoneNumber.trim();
    if (normalizedPhone.isEmpty || !normalizedPhone.startsWith('+')) {
      throw Exception('Enter a valid WhatsApp number with country code.');
    }
    final ref = FirebaseFirestore.instance
        .collection('whatsapp_otp_send_requests')
        .doc();
    await ref.set({
      'userId': user.uid,
      'phoneNumber': normalizedPhone,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _waitForRequest(
      ref,
      timeout: const Duration(seconds: 45),
      timeoutMessage: 'Could not send WhatsApp code. Try again.',
    );
  }

  Future<void> verifyOtp({
    required String code,
    required String phoneNumber,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No user signed in.');
    }
    final digits = code.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 4) {
      throw Exception('Enter the 4-digit code.');
    }
    final normalizedPhone = phoneNumber.trim();
    if (normalizedPhone.isEmpty || !normalizedPhone.startsWith('+')) {
      throw Exception('Enter a valid WhatsApp number with country code.');
    }
    final ref = FirebaseFirestore.instance
        .collection('whatsapp_otp_verify_requests')
        .doc();
    await ref.set({
      'userId': user.uid,
      'phoneNumber': normalizedPhone,
      'code': digits,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _waitForRequest(
      ref,
      timeout: const Duration(seconds: 45),
      timeoutMessage: 'WhatsApp verification timed out. Try again.',
    );
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
