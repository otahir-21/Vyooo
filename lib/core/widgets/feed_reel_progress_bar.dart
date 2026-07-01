import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_sizes.dart';

/// Home reel progress — Figma 402×3 full-bleed bar (display only; parent handles scrub).
class FeedReelProgressBar extends StatelessWidget {
  const FeedReelProgressBar({
    super.key,
    required this.progress,
  });

  /// Normalized playback position (0 = start, 1 = end).
  final double progress;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fillWidth = width * clamped;

        return SizedBox(
          height: AppSizes.liveFeedStreamProgressHeight,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              AppSizes.liveFeedStreamProgressRadius,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: AppColors.feedReelProgressTrack),
                if (fillWidth > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: fillWidth,
                      decoration: const BoxDecoration(
                        gradient: AppGradients.liveFeedStreamProgressFill,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
