import 'package:flutter/material.dart';

import '../../platform/app_system_ui.dart';
import '../../theme/app_spacing.dart';
import 'auth_floating_circle_button.dart';
import 'auth_floating_nav_visibility.dart';

/// Bottom-left floating back control (find-account / forgot-password placement).
class AuthFloatingBackButton extends StatelessWidget {
  const AuthFloatingBackButton({
    super.key,
    required this.onPressed,
    this.enabled = true,
    this.alwaysShowBack = false,
  });

  final VoidCallback? onPressed;
  final bool enabled;
  final bool alwaysShowBack;

  @override
  Widget build(BuildContext context) {
    final showBack = shouldShowAuthFloatingBack(
      context,
      hasBackHandler: onPressed != null,
      alwaysShowBack: alwaysShowBack,
    );
    if (!showBack) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: AppSpacing.xl,
      bottom:
          AppSpacing.authFloatingNavBottom +
          AppSystemUi.bottomChromeInset(context),
      child: AuthFloatingCircleButton.back(
        onPressed: onPressed,
        enabled: enabled,
      ),
    );
  }
}
