import 'package:flutter/material.dart';

import '../../theme/app_background_assets.dart';
import '../../theme/app_gradients.dart';

/// Full-screen profile background (`assets/bgImages/Comment_section.png`).
class ProfileScreenBackground extends StatelessWidget {
  const ProfileScreenBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppBackgroundAssets.profile,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return const DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppGradients.personalProfileBackgroundGradient,
          ),
        );
      },
    );
  }
}
