import '../../models/reel_count_privacy.dart';

/// Span of one cell on a modular square grid.
enum ProfileGridSpan {
  /// 1×1 unit square.
  unit,

  /// 2×2 unit square.
  double,
}

/// Per-post profile tile size. [auto] uses layout mode (e.g. views for artist grid).
enum ProfileGridSpanOverride {
  auto,
  unit,
  double,
}

/// One tile in the profile grid (index matches the caller's post list).
class ProfileGridItem {
  const ProfileGridItem({
    required this.sourceIndex,
    required this.thumbnailUrl,
    required this.views,
    this.likes = 0,
    this.shares = 0,
    this.privacy = ReelCountPrivacy.visible,
    this.isVideo = false,
    this.showVrBadge = false,
    this.isRepost = false,
    this.spanOverride = ProfileGridSpanOverride.auto,
  });

  final int sourceIndex;
  final String thumbnailUrl;
  final int views;
  final int likes;
  final int shares;
  final ReelCountPrivacy privacy;
  final bool isVideo;
  final bool showVrBadge;
  final bool isRepost;
  final ProfileGridSpanOverride spanOverride;
}

/// Visual placement produced by [ProfileGridLayoutEngine].
class ProfileGridPlacement {
  const ProfileGridPlacement({
    required this.sourceIndex,
    required this.span,
  });

  final int sourceIndex;
  final ProfileGridSpan span;
}

enum ProfileGridLayoutMode {
  /// All 1×1 tiles (classic uniform profile grid).
  uniform,

  /// 12-post blocks: highest views → 2×2, next four → featured 1×1, rest → 1×1.
  artistModern,
}
