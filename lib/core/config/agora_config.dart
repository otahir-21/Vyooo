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
}
