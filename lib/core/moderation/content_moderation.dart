/// Shared crowd-report moderation logic for posts, stories, and VR streams.
enum ModeratedContentKind { imagePost, videoPost, imageStory, videoStory, vrStream }

/// View-tier thresholds — must stay aligned with
/// `REPORT_MODERATION_TIERS` in `functions/src/index.ts`.
class ReportModerationThresholds {
  const ReportModerationThresholds._();

  static const List<({int minViews, double fraction})> tiers = [
    (minViews: 1000, fraction: 0.02),
    (minViews: 500, fraction: 0.10),
    (minViews: 100, fraction: 0.20),
  ];

  /// Returns the active fraction for [views], or `null` when below minimum.
  static double? fractionForViews(int views) {
    for (final tier in tiers) {
      if (views >= tier.minViews) return tier.fraction;
    }
    return null;
  }

  static int reportsNeeded(int views) {
    final fraction = fractionForViews(views);
    if (fraction == null || views <= 0) return 0;
    return (views * fraction).ceil();
  }
}

class ContentModeration {
  const ContentModeration._();

  static bool isReportCovered(Map<String, dynamic>? moderation) {
    if (moderation == null || moderation.isEmpty) return false;
    final status = _status(moderation);
    if (status == 'report_covered') return true;
    if (status == 'removed') {
      final reason = moderation['removedReason'];
      return reason == 'report_threshold';
    }
    return false;
  }

  static bool hasPendingDispute(Map<String, dynamic>? moderation) {
    if (moderation == null) return false;
    final dispute = moderation['disputeStatus'];
    return dispute == 'pending';
  }

  static String contentLabel(ModeratedContentKind kind) {
    switch (kind) {
      case ModeratedContentKind.imagePost:
      case ModeratedContentKind.videoPost:
        return 'post';
      case ModeratedContentKind.imageStory:
      case ModeratedContentKind.videoStory:
        return 'story';
      case ModeratedContentKind.vrStream:
        return 'stream';
    }
  }

  static ModeratedContentKind kindFromReel(Map<String, dynamic> reel) {
    if (reel['isVR'] == true) return ModeratedContentKind.vrStream;
    final mediaType = (reel['mediaType'] as String?)?.toLowerCase() ?? '';
    if (mediaType == 'image') return ModeratedContentKind.imagePost;
    return ModeratedContentKind.videoPost;
  }

  static ModeratedContentKind kindFromStory({required bool isVideo}) {
    return isVideo
        ? ModeratedContentKind.videoStory
        : ModeratedContentKind.imageStory;
  }

  static String coverMessage(ModeratedContentKind kind) {
    final label = contentLabel(kind);
    return 'This $label was reported to be abusive, indecent, graphic, or sexual.';
  }

  static String _status(Map<String, dynamic> moderation) {
    final raw = moderation['status'];
    if (raw == null) return '';
    return raw.toString().toLowerCase();
  }
}
