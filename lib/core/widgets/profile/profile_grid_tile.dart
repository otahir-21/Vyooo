import 'package:flutter/material.dart';

import '../../models/reel_count_privacy.dart';
import '../../theme/app_spacing.dart';
import 'profile_grid_metric_overlay.dart';

/// Square thumbnail for profile modular grids.
class ProfileGridTile extends StatelessWidget {
  const ProfileGridTile({
    super.key,
    required this.thumbnailUrl,
    this.isVideo = false,
    this.showVrBadge = false,
    this.viewCount,
    this.likeCount,
    this.shareCount,
    this.privacy = ReelCountPrivacy.visible,
    this.isHero = false,
    this.isRepost = false,
    this.onTap,
  });

  final String thumbnailUrl;
  final bool isVideo;
  final bool showVrBadge;
  final int? viewCount;
  final int? likeCount;
  final int? shareCount;
  final ReelCountPrivacy privacy;
  final bool isHero;
  final bool isRepost;
  final VoidCallback? onTap;

  static String formatViewCount(int n) => ReelCountPrivacy.formatCount(n);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Colors.grey.shade900),
          if (thumbnailUrl.isNotEmpty)
            Image.network(
              thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          if (isRepost)
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.repeat_rounded,
                      size: isHero ? 12 : 10,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'Repost',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: isHero ? 10 : 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (showVrBadge)
            Positioned(
              top: AppSpacing.sm,
              left: isRepost ? 56 : AppSpacing.sm,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'VR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          if (viewCount != null)
            ProfileGridMetricOverlay(
              views: viewCount!,
              likes: likeCount ?? 0,
              shares: shareCount ?? 0,
              privacy: privacy,
              isHero: isHero,
            ),
          if (isVideo)
            const Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xs),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
