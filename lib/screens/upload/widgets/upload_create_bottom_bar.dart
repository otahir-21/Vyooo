import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Bottom row for the create hub: **Story | Gallery | Live** — same chrome as [UploadScreen].
///
/// [selectedSegment]: `0` Story, `1` Gallery (post), `2` Live.
class UploadCreateBottomBar extends StatelessWidget {
  const UploadCreateBottomBar({
    super.key,
    required this.selectedSegment,
    required this.onStoryTap,
    required this.onPostTap,
    required this.onLiveTap,
    this.lightSurface = true,
  });

  final int selectedSegment;
  final VoidCallback onStoryTap;
  final VoidCallback onPostTap;
  final VoidCallback onLiveTap;

  /// White chrome with burgundy active pill (Figma). Pass `false` for legacy dark chrome.
  final bool lightSurface;

  @override
  Widget build(BuildContext context) {
    final seg = selectedSegment.clamp(0, 2);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: lightSurface
            ? AppColors.chatBackground
            : const Color(0xFF1E0A1E).withValues(alpha: 0.4),
        border: Border(
          top: BorderSide(
            color: lightSurface
                ? AppColors.chatDivider
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm + AppSpacing.xs,
          AppSpacing.md,
          bottomInset,
        ),
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: UploadCreateSegmentButton(
                  label: 'Story',
                  iconPath: 'assets/vyooO_icons/Upload_Story_Live/story.png',
                  selected: seg == 0,
                  onTap: onStoryTap,
                  lightSurface: lightSurface,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: UploadCreateSegmentButton(
                  label: 'Gallery',
                  iconPath: 'assets/vyooO_icons/Upload_Story_Live/gallery.png',
                  selected: seg == 1,
                  onTap: onPostTap,
                  lightSurface: lightSurface,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: UploadCreateSegmentButton(
                  label: 'Live',
                  iconPath: 'assets/vyooO_icons/Upload_Story_Live/live.png',
                  selected: seg == 2,
                  onTap: onLiveTap,
                  lightSurface: lightSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UploadCreateSegmentButton extends StatelessWidget {
  const UploadCreateSegmentButton({
    super.key,
    required this.label,
    required this.iconPath,
    required this.selected,
    required this.onTap,
    this.lightSurface = true,
  });

  final String label;
  final String iconPath;
  final bool selected;
  final VoidCallback onTap;
  final bool lightSurface;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final Color? pillColor;
    if (lightSurface) {
      color = selected ? Colors.white : AppColors.chatTextSecondary;
      pillColor = selected ? AppColors.authBrandBurgundy : Colors.transparent;
    } else {
      color = selected ? Colors.white : Colors.white.withValues(alpha: 0.6);
      pillColor = selected ? AppColors.brandDeepMagenta : Colors.transparent;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md + AppSpacing.xs,
          vertical: AppSpacing.sm + AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: pillColor,
          borderRadius: AppRadius.buttonRadius,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                iconPath,
                width: 20,
                height: 20,
                color: color,
                errorBuilder: (_, _, _) => Icon(
                  label == 'Story'
                      ? Icons.videocam_outlined
                      : label == 'Gallery'
                          ? Icons.grid_view_rounded
                          : Icons.wifi_tethering_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
              Text(
                label,
                style: AppTypography.chatTileName.copyWith(
                  color: color,
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
