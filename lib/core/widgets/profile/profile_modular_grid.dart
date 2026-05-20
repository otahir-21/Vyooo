import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../models/reel_count_privacy.dart';
import '../../theme/app_spacing.dart';
import '../../utils/reel_engagement.dart';
import 'profile_grid_layout_engine.dart';
import 'profile_grid_models.dart';
import 'profile_grid_posts.dart';
import 'profile_grid_tile.dart';

/// Modular square grid (1×1 and 2×2) for profile Posts / VR / Saved tabs.
class ProfileModularGrid extends StatelessWidget {
  const ProfileModularGrid({
    super.key,
    required this.items,
    required this.onItemTap,
    this.layoutMode = ProfileGridLayoutMode.artistModern,
    this.crossAxisCount = 3,
    this.gap = AppSpacing.xs,
    this.minViewsForDouble = 0,
    this.padding = EdgeInsets.zero,
  });

  final List<ProfileGridItem> items;
  final void Function(int sourceIndex) onItemTap;
  final ProfileGridLayoutMode layoutMode;
  final int crossAxisCount;
  final double gap;
  final int minViewsForDouble;
  final EdgeInsetsGeometry padding;

  /// 12-tile artist block: 2×2 hero + four 1×1 + seven 1×1 rows (3-wide).
  static const List<QuiltedGridTile> artistQuiltedPattern = [
    QuiltedGridTile(2, 2),
    QuiltedGridTile(1, 1),
    QuiltedGridTile(1, 1),
    QuiltedGridTile(1, 1),
    QuiltedGridTile(1, 1),
    QuiltedGridTile(1, 1),
    QuiltedGridTile(1, 1),
    QuiltedGridTile(1, 1),
    QuiltedGridTile(1, 1),
    QuiltedGridTile(1, 1),
    QuiltedGridTile(1, 1),
    QuiltedGridTile(1, 1),
  ];

  static const List<QuiltedGridTile> uniformQuiltedPattern = [
    QuiltedGridTile(1, 1),
  ];

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final viewsByIndex = List<int>.filled(items.length, 0);
    final spanOverrideByIndex = List<ProfileGridSpanOverride>.filled(
      items.length,
      ProfileGridSpanOverride.auto,
    );
    for (final item in items) {
      if (item.sourceIndex >= 0 && item.sourceIndex < viewsByIndex.length) {
        viewsByIndex[item.sourceIndex] = item.views;
        spanOverrideByIndex[item.sourceIndex] = item.spanOverride;
      }
    }

    final placements = ProfileGridLayoutEngine.layout(
      itemCount: items.length,
      viewsByIndex: viewsByIndex,
      mode: layoutMode,
      minViewsForDouble: minViewsForDouble,
      spanOverrideByIndex: spanOverrideByIndex,
    );

    final bySourceIndex = <int, ProfileGridItem>{
      for (final item in items) item.sourceIndex: item,
    };

    final pattern = placements
        .map(
          (p) => p.span == ProfileGridSpan.double
              ? const QuiltedGridTile(2, 2)
              : const QuiltedGridTile(1, 1),
        )
        .toList(growable: false);

    if (pattern.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: padding,
      child: GridView.custom(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverQuiltedGridDelegate(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
          repeatPattern: QuiltedGridRepeatPattern.same,
          pattern: pattern,
        ),
        childrenDelegate: SliverChildBuilderDelegate(
          (context, visualIndex) {
            if (visualIndex >= placements.length) {
              return const SizedBox.shrink();
            }
            final placement = placements[visualIndex];
            final gridItem = bySourceIndex[placement.sourceIndex];
            if (gridItem == null) return const SizedBox.shrink();

            final isHero = placement.span == ProfileGridSpan.double;

            return ProfileGridTile(
              thumbnailUrl: gridItem.thumbnailUrl,
              isVideo: gridItem.isVideo,
              showVrBadge: gridItem.showVrBadge,
              viewCount: gridItem.views,
              likeCount: gridItem.likes,
              shareCount: gridItem.shares,
              privacy: gridItem.privacy,
              isHero: isHero,
              isRepost: gridItem.isRepost,
              onTap: () => onItemTap(gridItem.sourceIndex),
            );
          },
          childCount: placements.length,
        ),
      ),
    );
  }
}

ProfileGridSpanOverride profileGridSpanOverrideFromReel(
  Map<String, dynamic> reel,
) {
  final raw = ((reel['profileGridSpan'] as String?) ?? '').toLowerCase().trim();
  return switch (raw) {
    'double' || 'large' || 'hero' => ProfileGridSpanOverride.double,
    'unit' || 'small' => ProfileGridSpanOverride.unit,
    _ => ProfileGridSpanOverride.auto,
  };
}

List<ProfileGridItem> profileGridItemsFromReels({
  required List<Map<String, dynamic>> reels,
  required String Function(Map<String, dynamic> reel) thumbnailFor,
  bool showVrBadge = false,
}) {
  return List.generate(reels.length, (index) {
    final reel = reels[index];
    final mediaType = ProfileGridPosts.mediaType(reel);
    return ProfileGridItem(
      sourceIndex: index,
      thumbnailUrl: thumbnailFor(reel),
      views: (reel['views'] as num?)?.toInt() ?? 0,
      likes: (reel['likes'] as num?)?.toInt() ?? 0,
      shares: ReelEngagement.repostCount(reel),
      privacy: ReelCountPrivacy.fromMap(reel),
      isVideo: mediaType == 'video',
      showVrBadge: showVrBadge || reel['isVR'] == true,
      isRepost: reel['isRepost'] == true,
      spanOverride: profileGridSpanOverrideFromReel(reel),
    );
  });
}
