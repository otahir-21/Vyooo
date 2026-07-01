import 'package:flutter/material.dart';

import '../theme/app_gradients.dart';
import '../theme/app_radius.dart';
import '../theme/app_sizes.dart';

/// Figma `gradient-scrim` — tall fade over reel content above the nav chrome.
class FeedBottomScrim extends StatelessWidget {
  const FeedBottomScrim({super.key, this.clipBottomCorners = true});

  /// When the parent already clips bottom corners, skip inner [ClipRRect].
  final bool clipBottomCorners;

  @override
  Widget build(BuildContext context) {
    final gradient = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppGradients.feedBottomNavScrim,
      ),
      child: const SizedBox.expand(),
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: AppSizes.feedBottomNavScrimHeight(context),
      child: IgnorePointer(
        child: clipBottomCorners
            ? ClipRRect(
                borderRadius: AppRadius.feedBottomChromeRadius,
                clipBehavior: Clip.antiAlias,
                child: gradient,
              )
            : gradient,
      ),
    );
  }
}
