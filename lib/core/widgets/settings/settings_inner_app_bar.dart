import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../vyooo_brand_logo.dart';

/// Back + title (left) and [VyoooBrandLogo] (right) for settings/account sub-screens.
class SettingsInnerAppBar extends StatelessWidget {
  const SettingsInnerAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.showLogo = true,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack ?? () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.settingsInnerAppBarTitle,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.xs),
            trailing!,
          ],
          if (showLogo) ...[
            const SizedBox(width: AppSpacing.sm),
            const VyoooBrandLogo.innerHeader(),
          ],
        ],
      ),
    );
  }
}
