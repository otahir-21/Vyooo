import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';

/// Maroon status chevron after the tab pills on Following (Figma SVG asset).
class FollowingStoriesToggle extends StatelessWidget {
  const FollowingStoriesToggle({
    super.key,
    required this.isExpanded,
    required this.onTap,
  });

  static const String asset =
      'assets/vyooO_icons/Home/following_status_toggle.svg';

  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isExpanded ? 'Hide status' : 'Show status',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: AppSizes.followingStoriesToggleWidth,
          height: AppSizes.feedTabChipHeight,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Transform.translate(
              offset: const Offset(0, AppSpacing.followingStoriesToggleDown),
              child: Transform.rotate(
                angle: isExpanded ? pi : 0,
                child: SvgPicture.asset(
                  asset,
                  width: AppSizes.followingStoriesToggleWidth,
                  height: AppSizes.followingStoriesToggleHeight,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
