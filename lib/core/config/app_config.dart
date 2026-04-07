/// App-wide flags. Set [useMockSubscriptions] to false when App Store products are approved.
abstract final class AppConfig {
  /// When true, subscription screen uses mock plans and upgrade shows "Mock mode active".
  /// When false, uses RevenueCat offerings and real purchase.
  static const bool useMockSubscriptions = false;

  /// When true, VR grid is unlocked for testing without a subscription.
  /// Set to false before production so VR is gated by Subscriber/Creator.
  static const bool devBypassVRAccess = false;

  /// Local tier override screen for development only.
  /// Keep false for production and store sandbox testing.
  static const bool enableSubscriptionTierTesting = false;

  /// RevenueCat public SDK keys (from RevenueCat dashboard).
  /// Keep these non-empty for real billing tests in TestFlight / Play internal testing.
  static const String revenueCatApplePublicKey = 'appl_vPZwqxiBnbyvgMUEvKURLKzCRpj';
  static const String revenueCatGooglePublicKey = '';

  /// When true and [pexelsApiKey] is set, reels feed falls back to Pexels when Firestore is empty.
  /// Get a free API key at https://www.pexels.com/api/
  static const bool usePexelsFeed = false;

  /// Pexels API key (free at https://www.pexels.com/api/). If null, Pexels feed is disabled.
  static const String? pexelsApiKey = null; // Set your key here or via env

  /// Cloudflare Stream customer subdomain (from Stream dashboard). Used to build playback URLs.
  static const String cloudflareStreamSubdomain =
      'customer-gk6ay4ir3ijd6sux.cloudflarestream.com';

  /// Jamendo API client ID. Get a free key at https://devportal.jamendo.com
  static const String jamendoClientId = '78456e30';
}
