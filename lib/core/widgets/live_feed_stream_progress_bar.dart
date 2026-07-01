import 'package:flutter/material.dart';

import '../theme/app_gradients.dart';
import '../theme/app_sizes.dart';

/// Figma live stream progress — 402×3 full-bleed bar (display only; parent handles scrub).
class LiveFeedStreamProgressBar extends StatelessWidget {
  const LiveFeedStreamProgressBar({
    super.key,
    required this.progress,
  });

  /// Normalized position within the live session (0 = start, 1 = live edge).
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
                ColoredBox(
                  color: Colors.white.withValues(alpha: 0.34),
                ),
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
