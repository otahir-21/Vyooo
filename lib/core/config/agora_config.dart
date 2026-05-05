import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Agora configuration.
/// Replace [appId] with your App ID from https://console.agora.io
/// In production, App Certificate must be enabled and tokens generated
/// server-side via a Cloud Function — see AgoraTokenService below.
class AgoraConfig {
  AgoraConfig._();

  /// ⚠️  Replace with your Agora App ID.
  static const String appId = '443105d5684f492088bb004196b3fee8';

  /// Token TTL in seconds (1 hour). Token server should match this.
  static const int tokenExpirySeconds = 3600;

  /// Converts a Firebase UID to a deterministic positive 32-bit integer for Agora.
  static int agoraUidFromFirebaseUid(String firebaseUid) {
    final bytes = utf8.encode(firebaseUid);
    final hash = md5.convert(bytes);
    final b = hash.bytes;
    final raw = (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3];
    final uid = (raw & 0x7FFFFFFF);
    return uid == 0 ? 1 : uid;
  }
}
