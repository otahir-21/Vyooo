/// Helpers for likes, comments, and reposts on reel maps.
abstract final class ReelEngagement {
  ReelEngagement._();

  /// Original post id when [reel] is a profile repost stub.
  static String sourceReelId(Map<String, dynamic> reel) {
    if (reel['isRepost'] == true) {
      final original = (reel['repostOf'] as String?)?.trim() ?? '';
      if (original.isNotEmpty) return original;
    }
    return (reel['id'] as String?)?.trim() ?? '';
  }

  static int repostCount(Map<String, dynamic> reel) {
    final reposts = reel['reposts'];
    if (reposts is num) return reposts.toInt();
    final shares = reel['shares'];
    if (shares is num) return shares.toInt();
    return 0;
  }

  static bool isRepostStub(Map<String, dynamic> reel) =>
      reel['isRepost'] == true;

  /// Discovery tabs (For You / Trending / VR) — exclude profile repost stubs.
  static bool isDiscoveryFeedEligible(Map<String, dynamic> reel) =>
      !isRepostStub(reel);
}
