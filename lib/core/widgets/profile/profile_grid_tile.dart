import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';

/// Square thumbnail for profile modular grids.
class ProfileGridTile extends StatelessWidget {
  const ProfileGridTile({
    super.key,
    required this.thumbnailUrl,
    this.isVideo = false,
    this.showVrBadge = false,
    this.viewCount,
    this.isHero = false,
    this.onTap,
  });

  final String thumbnailUrl;
  final bool isVideo;
  final bool showVrBadge;
  final int? viewCount;
  final bool isHero;
  final VoidCallback? onTap;

  static String formatViewCount(int n) {
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    }
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}k';
    }
    return '$n';
  }

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
          if (showVrBadge)
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
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
          if (viewCount != null && viewCount! > 0)
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: isHero ? 14 : 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    formatViewCount(viewCount!),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: isHero ? 12 : 11,
                      fontWeight:
                          isHero ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
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
