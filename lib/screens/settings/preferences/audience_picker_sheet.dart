import 'package:flutter/material.dart';

import '../../../core/models/user_app_preferences.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_background_assets.dart';

Future<String?> showAudiencePickerSheet(
  BuildContext context, {
  required String title,
  required String currentValue,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage(AppBackgroundAssets.commentsSection),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    title,
                    style: AppTypography.onboardingSectionTitle.copyWith(
                      fontSize: 18,
                    ),
                  ),
                ),
                for (final value in AudienceOption.values)
                  ListTile(
                    title: Text(
                      AudienceOption.labels[value] ?? value,
                      style: AppTypography.authDialogOption,
                    ),
                    trailing: currentValue == value
                        ? const Icon(Icons.check_rounded, color: Color(0xFFF81945))
                        : null,
                    onTap: () => Navigator.pop(ctx, value),
                  ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      );
    },
  );
}
