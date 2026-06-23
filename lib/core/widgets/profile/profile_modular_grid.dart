import 'package:flutter/material.dart';

import '../../models/reel_count_privacy.dart';
import '../../../screens/profile/profile_figma_tokens.dart';
import '../../utils/reel_engagement.dart';
import 'profile_grid_layout_engine.dart';
import 'profile_grid_models.dart';
import 'profile_grid_posts.dart';
import 'profile_grid_tile.dart';
import 'profile_grid_title.dart';
import 'profile_span_grid_layout.dart';

/// Modular square grid (1×1 and 2×2) for profile Posts / VR / Saved tabs.
class ProfileModularGrid extends StatelessWidget {
  const ProfileModularGrid({
    super.key,
    required this.items,
    required this.onItemTap,
    this.onItemLongPress,
    this.layoutMode = ProfileGridLayoutMode.artistModern,
    this.crossAxisCount = 3,
    this.gap = ProfileFigmaTokens.contentGridGap,
    this.minViewsForDouble = 0,
    this.padding = EdgeInsets.zero,
  });

  final List<ProfileGridItem> items;
  final void Function(int sourceIndex) onItemTap;
  final void Function(int sourceIndex)? onItemLongPress;
  final ProfileGridLayoutMode layoutMode;
  final int crossAxisCount;
  final double gap;
  final int minViewsForDouble;
  final EdgeInsetsGeometry padding;

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

    final slots = ProfileSpanGridLayout.pack(
      placements: placements,
      crossAxisCount: crossAxisCount,
    );
    if (slots.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (!width.isFinite || width <= 0) {
            return const SizedBox.shrink();
          }

          final cellSize =
              (width - gap * (crossAxisCount - 1)) / crossAxisCount;
          final rowCount = ProfileSpanGridLayout.rowCount(slots);
          final height = rowCount * cellSize + (rowCount - 1) * gap;

          return SizedBox(
            height: height,
            width: width,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                const Positioned.fill(
                  child: ColoredBox(
                    color: ProfileFigmaTokens.screenBackground,
                  ),
                ),
                for (final slot in slots)
                  _positionedTile(
                    slot: slot,
                    cellSize: cellSize,
                    gap: gap,
                    gridWidth: width,
                    gridHeight: height,
                    crossAxisCount: crossAxisCount,
                    rowCount: rowCount,
                    gridItem: bySourceIndex[slot.placement.sourceIndex],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _positionedTile({
    required ProfileSpanGridSlot slot,
    required double cellSize,
    required double gap,
    required double gridWidth,
    required double gridHeight,
    required int crossAxisCount,
    required int rowCount,
    required ProfileGridItem? gridItem,
  }) {
    if (gridItem == null) return const SizedBox.shrink();

    final left = slot.column * (cellSize + gap);
    final top = slot.row * (cellSize + gap);
    final spansLastColumn = slot.column + slot.columnSpan == crossAxisCount;
    final spansLastRow = slot.row + slot.rowSpan == rowCount;
    final tileWidth = spansLastColumn
        ? gridWidth - left
        : slot.columnSpan * cellSize + (slot.columnSpan - 1) * gap;
    final tileHeight = spansLastRow
        ? gridHeight - top
        : slot.rowSpan * cellSize + (slot.rowSpan - 1) * gap;
    final isHero = slot.placement.span == ProfileGridSpan.double;

    return Positioned(
      left: left,
      top: top,
      width: tileWidth,
      height: tileHeight,
      child: ClipRRect(
        borderRadius: gap > 0
            ? BorderRadius.circular(ProfileFigmaTokens.contentGridRadius)
            : BorderRadius.zero,
        child: ProfileGridTile(
          thumbnailUrl: gridItem.thumbnailUrl,
          isVideo: gridItem.isVideo,
          showVrBadge: gridItem.showVrBadge,
          viewCount: gridItem.views,
          likeCount: gridItem.likes,
          shareCount: gridItem.shares,
          privacy: gridItem.privacy,
          isHero: isHero,
          isRepost: gridItem.isRepost,
          gridTitle: gridItem.gridTitle,
          onTap: () => onItemTap(gridItem.sourceIndex),
          onLongPress: onItemLongPress != null
              ? () => onItemLongPress!(gridItem.sourceIndex)
              : null,
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
    'double' || 'large' || 'hero' || 'big' => ProfileGridSpanOverride.double,
    'unit' || 'small' => ProfileGridSpanOverride.unit,
    'auto' || '' => ProfileGridSpanOverride.auto,
    _ => ProfileGridSpanOverride.auto,
  };
}

/// Firestore value for [profileGridSpan].
String profileGridSpanToFirestore(ProfileGridSpanOverride override) {
  return switch (override) {
    ProfileGridSpanOverride.double => 'double',
    ProfileGridSpanOverride.unit => 'unit',
    ProfileGridSpanOverride.auto => 'auto',
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
      gridTitle: ProfileGridTitle.fromReel(reel),
    );
  });
}
