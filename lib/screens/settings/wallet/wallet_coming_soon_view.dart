import 'package:flutter/material.dart';

import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/settings/settings_inner_app_bar.dart';

/// Placeholder while Vyooo Wallet / Vyooo coin are not yet available.
class WalletComingSoonView extends StatelessWidget {
  const WalletComingSoonView({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.personalProfileBackgroundGradient,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showAppBar) const SettingsInnerAppBar(title: 'Vyooo Wallet'),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/vyooO_icons/Settings/Wallet.png',
                            width: 44,
                            height: 44,
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Coming Soon',
                        textAlign: TextAlign.center,
                        style: AppTypography.onboardingSectionTitle,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Vyooo coin and your wallet balance are on the way.\nStay tuned!',
                        textAlign: TextAlign.center,
                        style: AppTypography.onboardingPrivacyBody,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: AppRadius.pillRadius,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          'Vyooo coin',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
