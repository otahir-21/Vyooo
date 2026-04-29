import 'package:flutter/material.dart';

import '../theme/app_gradients.dart';

enum GradientType {
  auth,
  onboarding,
  dob,
  profile,
  feed,
  main,
  profileCardBackground,
  premiumDark,
}

/// Reusable full-screen gradient background.
/// Handles SafeArea internally. Padding is left to each screen.
class AppGradientBackground extends StatelessWidget {
  const AppGradientBackground({
    super.key,
    required this.child,
    this.type = GradientType.auth,
  });

  final Widget child;
  final GradientType type;

  LinearGradient get _gradient {
    switch (type) {
      case GradientType.onboarding:
        return AppGradients.onboardingGradient;
      case GradientType.dob:
        return AppGradients.dobGradient;
      case GradientType.profile:
        return AppGradients.profileGradient;
      case GradientType.feed:
        return AppGradients.feedGradient;
      case GradientType.auth:
        return AppGradients.mainBackgroundGradient;
      case GradientType.main:
        return AppGradients.mainBackgroundGradient;
      case GradientType.profileCardBackground:
        return AppGradients.profileCardBackground;
      case GradientType.premiumDark:
        return AppGradients.premiumDarkGradient;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(gradient: _gradient),
      child: SafeArea(child: child),
    );
  }
}
