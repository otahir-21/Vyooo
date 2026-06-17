import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../theme/app_spacing.dart';
import 'auth_social_icon_button.dart';

/// Platform social sign-in icons under "Or sign in/up with".
/// iOS: Google + Apple. Android: Google only.
class AuthSocialSignInRow extends StatelessWidget {
  const AuthSocialSignInRow({
    super.key,
    required this.onGoogleTap,
    required this.onAppleTap,
    this.isGoogleLoading = false,
    this.isAppleLoading = false,
  });

  final VoidCallback? onGoogleTap;
  final VoidCallback? onAppleTap;
  final bool isGoogleLoading;
  final bool isAppleLoading;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AuthSocialIconButton(
            icon: FontAwesomeIcons.google,
            isLoading: isGoogleLoading,
            onTap: onGoogleTap,
          ),
        ],
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AuthSocialIconButton(
            icon: FontAwesomeIcons.google,
            isLoading: isGoogleLoading,
            onTap: onGoogleTap,
          ),
          const SizedBox(width: AppSpacing.socialRowGap),
          AuthSocialIconButton(
            icon: FontAwesomeIcons.apple,
            isLoading: isAppleLoading,
            onTap: onAppleTap,
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
