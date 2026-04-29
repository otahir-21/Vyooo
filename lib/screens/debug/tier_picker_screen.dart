import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/subscription/membership_tier.dart';
import '../../core/subscription/subscription_controller.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

/// Debug-only screen to pick subscription tier for testing. Shown at app start when [kDebugMode].
class TierPickerScreen extends StatelessWidget {
  const TierPickerScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  /// Three plans only: Standard, Subscriber, Creator (no Free).
  static const List<(MembershipTier, String, Widget)> _options = [
    (
      MembershipTier.standard,
      'Standard',
      Icon(Icons.star_outline_rounded),
    ),
    (
      MembershipTier.subscriber,
      'Subscriber',
      FaIcon(FontAwesomeIcons.crown),
    ),
    (
      MembershipTier.creator,
      'Creator',
      Icon(Icons.verified_user_rounded),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF14001F), Color(0xFF4A003F), Color(0xFFDE106B)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Select plan for testing',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a tier to test UI (debug only)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                Consumer<SubscriptionController>(
                  builder: (context, controller, _) {
                    return Column(
                      children: _options.map((e) {
                        final tier = e.$1;
                        final label = e.$2;
                        final icon = e.$3;
                        final isSelected = controller.currentTier == tier;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Material(
                            color: isSelected
                                ? AppColors.brandPink.withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              AppRadius.input,
                            ),
                            child: InkWell(
                              onTap: () => controller.setTestTier(tier),
                              borderRadius: BorderRadius.circular(
                                AppRadius.input,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.md,
                                ),
                                child: Row(
                                  children: [
                                    IconTheme(
                                      data: IconThemeData(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white.withValues(alpha: 0.8),
                                        size: 24,
                                      ),
                                      child: icon,
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.95,
                                          ),
                                          fontSize: 16,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    child: const Text('Continue to app'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
