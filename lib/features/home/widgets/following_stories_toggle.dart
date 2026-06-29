import 'package:flutter/material.dart';

import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';

/// Pink chevron control for expanding / collapsing the Following tab story row.
class FollowingStoriesToggle extends StatelessWidget {
  const FollowingStoriesToggle({
    super.key,
    required this.isExpanded,
    required this.onTap,
  });

  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.inputRadius,
        child: Ink(
          width: AppSizes.followingStoriesToggleSize,
          height: AppSizes.followingStoriesToggleSize,
          decoration: BoxDecoration(
            gradient: AppGradients.vrGetStartedButtonGradient,
            borderRadius: AppRadius.inputRadius,
          ),
          child: Icon(
            isExpanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: Colors.white,
            size: AppSizes.followingStoriesToggleIcon,
          ),
        ),
      ),
    );
  }
}

/// Vertical offset for the toggle — centered on story avatars when expanded,
/// tucked under the tab row when collapsed.
double followingStoriesToggleTop({
  required double headerBottom,
  required double storiesRowTop,
  required double collapseT,
}) {
  final expandedTop =
      storiesRowTop +
      (AppSizes.followingStoryAvatarSize -
              AppSizes.followingStoriesToggleSize) /
          2;
  final collapsedTop = headerBottom + AppSpacing.xs;
  return expandedTop + (collapsedTop - expandedTop) * collapseT;
}
