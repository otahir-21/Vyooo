import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Fetches a signed Agora RTC token via a Firestore-triggered Cloud Function.
///
/// Flow:
///  1. Write a request doc to `token_requests/{id}` (requires auth via Firestore rules).
///  2. Cloud Function (`generateAgoraTokenOnRequest`) triggers on the write,
///     mints the token using the App Certificate, and updates the doc.
///  3. We listen to the doc and resolve when `status == 'done'`.
///  4. Clean up the request doc.
///
/// This design avoids the HTTP callable `allUsers` Cloud Run IAM requirement
/// that is blocked by the metatech.ae org-level domain restriction policy.
class AgoraTokenService {
  AgoraTokenService._();
  static final AgoraTokenService _instance = AgoraTokenService._();
  factory AgoraTokenService() => _instance;

  /// Returns a signed Agora RTC token for [channelName] + [uid].
  /// [isHost] = true → publisher role.  [isHost] = false → subscriber.
  Future<String> getToken({
    required String channelName,
    required int uid,
    required bool isHost,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Must be signed in to get a live token.');

    final firestore = FirebaseFirestore.instance;
    final requestRef = firestore.collection('token_requests').doc();

    final payload = {
      'userId': user.uid,
      'channelName': channelName,
      'uid': uid,
      'role': isHost ? 'publisher' : 'subscriber',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    };

    debugPrint('[AgoraToken] requestId=${requestRef.id}');
    debugPrint(
      '[AgoraToken] channelName="$channelName" uid=$uid role=${isHost ? "publisher" : "subscriber"}',
    );

    await requestRef.set(payload);
    debugPrint('[AgoraToken] token request doc created');

    // Listen for the function to write back the token
    final completer = Completer<String>();
    StreamSubscription<DocumentSnapshot>? sub;

    sub = requestRef.snapshots().listen(
      (snap) {
        if (!snap.exists) return;
        final data = snap.data();
        if (data == null) return;

        final status = data['status'] as String?;

        if (status == 'done') {
          final token = data['token'] as String?;
          sub?.cancel();
          requestRef.delete().ignore();
          if (token == null || token.isEmpty) {
            completer.completeError(
              Exception('Token generation failed: empty token returned.'),
            );
          } else {
            debugPrint('[AgoraToken] token received length=${token.length}');
            completer.complete(token);
          }
        } else if (status == 'error') {
          final error = data['error'] as String? ?? 'Unknown error';
          sub?.cancel();
          requestRef.delete().ignore();
          completer.completeError(Exception('Token generation failed: $error'));
        }
      },
      onError: (e) {
        sub?.cancel();
        requestRef.delete().ignore();
        completer.completeError(e);
      },
    );

    // 20-second timeout — Cloud Function should respond in <2 s normally
    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        sub?.cancel();
        requestRef.delete().ignore();
        throw Exception('Token request timed out. Check Cloud Function logs.');
      },
    );
  }

  /// Renew a token for an active channel.
  Future<String> renewToken({
    required String channelName,
    required int uid,
    required bool isHost,
  }) => getToken(channelName: channelName, uid: uid, isHost: isHost);
}
