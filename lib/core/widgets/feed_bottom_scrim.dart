import 'package:flutter/material.dart';

import '../theme/app_gradients.dart';
import '../theme/app_radius.dart';
import '../theme/app_sizes.dart';

/// Figma `gradient-scrim` — tall fade over reel content above the nav chrome.
class FeedBottomScrim extends StatelessWidget {
  const FeedBottomScrim({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: AppSizes.feedBottomNavScrimHeight(context),
      child: IgnorePointer(
        child: ClipRRect(
          borderRadius: AppRadius.feedBottomChromeRadius,
          clipBehavior: Clip.antiAlias,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppGradients.feedBottomNavScrim,
              borderRadius: AppRadius.feedBottomChromeRadius,
            ),
          ),
        ),
      ),
    );
  }
}
