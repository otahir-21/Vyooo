import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../theme/app_typography.dart';

/// Figma Frame 2147224757 — avatar + title row (progress bar is separate, full bleed).
class LiveFeedHostCaptionRow extends StatelessWidget {
  const LiveFeedHostCaptionRow({
    super.key,
    required this.avatarUrl,
    required this.caption,
    required this.hostInitial,
    this.onTap,
  });

  final String? avatarUrl;
  final String caption;
  final String hostInitial;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = avatarUrl?.isNotEmpty == true;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.deferToChild,
      child: SizedBox(
        height: AppSizes.liveFeedHostRowHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _HostAvatar(
              avatarUrl: hasImage ? avatarUrl : null,
              hostInitial: hostInitial,
            ),
            const SizedBox(width: AppSizes.liveFeedHostAvatarToCaptionGap),
            Expanded(
              child: Text(
                caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.liveFeedHostCaption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Figma avatar-border — 36×36, 2px #FFFFFF ring, border-radius 18.
class _HostAvatar extends StatelessWidget {
  const _HostAvatar({
    required this.avatarUrl,
    required this.hostInitial,
  });

  final String? avatarUrl;
  final String hostInitial;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSizes.liveFeedHostAvatarSize,
      height: AppSizes.liveFeedHostAvatarSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipOval(
            child: SizedBox(
              width: AppSizes.liveFeedHostAvatarInnerSize,
              height: AppSizes.liveFeedHostAvatarInnerSize,
              child: avatarUrl != null
                  ? Image.network(
                      avatarUrl!,
                      width: AppSizes.liveFeedHostAvatarInnerSize,
                      height: AppSizes.liveFeedHostAvatarInnerSize,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _avatarFallback(hostInitial),
                    )
                  : _avatarFallback(hostInitial),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: AppSizes.liveFeedHostAvatarBorderWidth,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String initial) {
    return ColoredBox(
      color: Colors.white.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          initial.isNotEmpty ? initial[0].toUpperCase() : '?',
          style: AppTypography.liveFeedHostCaption.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 11,
            height: 1,
          ),
        ),
      ),
    );
  }
}
