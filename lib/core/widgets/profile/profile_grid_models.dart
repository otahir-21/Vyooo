/// Span of one cell on a modular square grid.
enum ProfileGridSpan {
  /// 1×1 unit square.
  unit,

  /// 2×2 unit square.
  double,
}

/// One tile in the profile grid (index matches the caller's post list).
class ProfileGridItem {
  const ProfileGridItem({
    required this.sourceIndex,
    required this.thumbnailUrl,
    required this.views,
    this.isVideo = false,
    this.showVrBadge = false,
  });

  final int sourceIndex;
  final String thumbnailUrl;
  final int views;
  final bool isVideo;
  final bool showVrBadge;
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
