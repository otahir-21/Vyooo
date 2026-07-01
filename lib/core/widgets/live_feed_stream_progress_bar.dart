import 'package:flutter/material.dart';

import '../theme/app_gradients.dart';
import '../theme/app_sizes.dart';

/// Figma live stream progress — full-bleed 402×3, track @ 34% white, gradient fill.
class LiveFeedStreamProgressBar extends StatelessWidget {
  const LiveFeedStreamProgressBar({
    super.key,
    required this.progress,
    this.onSeekStart,
    this.onSeekUpdate,
    this.onSeekEnd,
  });

  /// Normalized position within the live session (0 = start, 1 = live edge).
  final double progress;

  final VoidCallback? onSeekStart;
  final ValueChanged<double>? onSeekUpdate;
  final VoidCallback? onSeekEnd;

  void _handleSeek(double localX, double width) {
    if (width <= 0) return;
    onSeekUpdate?.call((localX / width).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fillWidth = width * clamped;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => onSeekStart?.call(),
          onHorizontalDragUpdate: (details) {
            _handleSeek(details.localPosition.dx, width);
          },
          onHorizontalDragEnd: (_) => onSeekEnd?.call(),
          onTapDown: (details) {
            onSeekStart?.call();
            _handleSeek(details.localPosition.dx, width);
            onSeekEnd?.call();
          },
          child: SizedBox(
            height: AppSizes.liveFeedStreamProgressHitHeight,
            width: double.infinity,
            child: Align(
              alignment: Alignment.topCenter,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  AppSizes.liveFeedStreamProgressRadius,
                ),
                child: SizedBox(
                  height: AppSizes.liveFeedStreamProgressHeight,
                  width: double.infinity,
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
              ),
            ),
          ),
        );
      },
    );
  }
}
