/// Per-post visibility for engagement counters (Instagram-style).
class ReelCountPrivacy {
  const ReelCountPrivacy({
    this.hideLikeCount = false,
    this.hideViewCount = false,
    this.hideShareCount = false,
    this.hideCommentCount = false,
    this.hideSaveCount = false,
  });

  final bool hideLikeCount;
  final bool hideViewCount;
  final bool hideShareCount;
  final bool hideCommentCount;
  final bool hideSaveCount;

  static const ReelCountPrivacy visible = ReelCountPrivacy();

  factory ReelCountPrivacy.fromMap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return visible;
    bool flag(String key) => data[key] == true;
    return ReelCountPrivacy(
      hideLikeCount: flag('hideLikeCount'),
      hideViewCount: flag('hideViewCount'),
      hideShareCount: flag('hideShareCount'),
      hideCommentCount: flag('hideCommentCount'),
      hideSaveCount: flag('hideSaveCount'),
    );
  }

  static String formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  /// Merges privacy flags into an existing reel map.
  static Map<String, dynamic> mergeIntoReelMap(Map<String, dynamic> reel) {
    final privacy = ReelCountPrivacy.fromMap(reel);
    return {
      ...reel,
      'hideLikeCount': privacy.hideLikeCount,
      'hideViewCount': privacy.hideViewCount,
      'hideShareCount': privacy.hideShareCount,
      'hideCommentCount': privacy.hideCommentCount,
      'hideSaveCount': privacy.hideSaveCount,
    };
  }

  Map<String, dynamic> toFirestoreFields() => {
        'hideLikeCount': hideLikeCount,
        'hideViewCount': hideViewCount,
        'hideShareCount': hideShareCount,
        'hideCommentCount': hideCommentCount,
        'hideSaveCount': hideSaveCount,
      };

  ReelCountPrivacy copyWith({
    bool? hideLikeCount,
    bool? hideViewCount,
    bool? hideShareCount,
    bool? hideCommentCount,
    bool? hideSaveCount,
  }) {
    return ReelCountPrivacy(
      hideLikeCount: hideLikeCount ?? this.hideLikeCount,
      hideViewCount: hideViewCount ?? this.hideViewCount,
      hideShareCount: hideShareCount ?? this.hideShareCount,
      hideCommentCount: hideCommentCount ?? this.hideCommentCount,
      hideSaveCount: hideSaveCount ?? this.hideSaveCount,
    );
  }

  bool showViews() => !hideViewCount;
  bool showLikes() => !hideLikeCount;
  bool showShares() => !hideShareCount;
  bool showComments() => !hideCommentCount;
  bool showSaves() => !hideSaveCount;
}

enum ReelCountMetric { views, likes, shares, comments, saves }

extension ReelCountPrivacyDisplay on ReelCountPrivacy {
  bool showMetric(ReelCountMetric metric) {
    switch (metric) {
      case ReelCountMetric.views:
        return showViews();
      case ReelCountMetric.likes:
        return showLikes();
      case ReelCountMetric.shares:
        return showShares();
      case ReelCountMetric.comments:
        return showComments();
      case ReelCountMetric.saves:
        return showSaves();
    }
  }

  /// Formatted count or empty when hidden (icon-only).
  String displayCount(ReelCountMetric metric, int value) {
    if (!showMetric(metric)) return '';
    return ReelCountPrivacy.formatCount(value);
  }
}
