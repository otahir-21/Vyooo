import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../constants/app_colors.dart';

/// Reusable onboarding progress bar. Same style across profile, interests, etc.
/// [progress] should be between 0.0 and 1.0.
class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth = constraints.maxWidth;
        final fillWidth = fullWidth * progress.clamp(0.0, 1.0);
        return ClipRRect(
          borderRadius: AppRadius.inputRadius,
          child: SizedBox(
            height: 3,
            width: double.infinity,
            child: Stack(
              children: [
                Container(
                  width: fullWidth,
                  height: 3,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                SizedBox(
                  width: fillWidth,
                  child: Container(
                    height: 3,
                    decoration: const BoxDecoration(
                      color: AppColors.brandPink,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(10),
                        right: Radius.zero,
                      ),
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
