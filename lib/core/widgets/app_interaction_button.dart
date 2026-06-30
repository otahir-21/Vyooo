import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// Standard interaction button used across the app (reels, stories, posts, etc).
/// Vertical layout: frosted circle icon, optional count or [label] below.
class AppInteractionButton extends StatelessWidget {
  const AppInteractionButton({
    super.key,
    this.icon,
    this.iconAsset,
    this.iconAssetActive,
    this.count = '',
    this.label,
    this.isActive = false,
    this.onTap,
    this.activeColor = const Color(0xFFD10057),
    this.defaultColor = Colors.white,
    this.iconColor,
    this.countColor,
    this.iconSize = AppSizes.feedInteractionIcon,
    this.textSize = 10,
    this.countTextStyle,
    this.colorizeAsset = true,
    this.spacing = 4,
    this.showCircleBackground = true,
    this.circleSize = AppSizes.feedInteractionCircle,
    this.useFeedFrostedStyle = false,
  }) : assert(
         icon != null || iconAsset != null || iconAssetActive != null,
         'Provide icon or iconAsset',
       );

  final IconData? icon;
  final String? iconAsset;

  /// When [isActive], shown instead of [iconAsset] (e.g. saved vs unsaved).
  final String? iconAssetActive;

  /// When false, PNG assets render without a color tint (full-color icons).
  final bool colorizeAsset;
  final String count;

  /// Static label below the icon (e.g. "Save", "Share"). Shown when [count] is empty.
  final String? label;
  final bool isActive;
  final VoidCallback? onTap;
  final Color activeColor;
  final Color defaultColor;

  /// Override icon color (e.g. yellow for Crown). If null, uses active/default.
  final Color? iconColor;

  /// Count / label color. If null, matches the icon tint (except when only icon is active).
  final Color? countColor;
  final double iconSize;
  final double textSize;
  final TextStyle? countTextStyle;
  final double spacing;
  final bool showCircleBackground;
  final double circleSize;

  /// Figma home reel column — 10% white fill, 2px blur, soft drop shadow.
  final bool useFeedFrostedStyle;

  String? get _resolvedAsset {
    if (isActive && iconAssetActive != null) return iconAssetActive;
    return iconAsset;
  }

  Widget _buildIcon(Color color) {
    final asset = _resolvedAsset;
    final renderSize =
        useFeedFrostedStyle && asset != null && asset.endsWith('.svg')
        ? circleSize
        : iconSize;
    final tintActiveAsset =
        asset != null &&
        (asset.contains('/interactions/like_active') ||
            asset.contains('/interactions/star_active'));

    if (asset != null) {
      if (asset.endsWith('.svg')) {
        return SvgPicture.asset(
          asset,
          width: renderSize,
          height: renderSize,
          fit: BoxFit.contain,
          colorFilter: tintActiveAsset
              ? null
              : (colorizeAsset
                    ? ColorFilter.mode(iconColor ?? color, BlendMode.srcIn)
                    : (iconColor != null
                          ? ColorFilter.mode(iconColor!, BlendMode.srcIn)
                          : null)),
        );
      }
      return Image.asset(
        asset,
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        color: colorizeAsset ? (iconColor ?? color) : iconColor,
        errorBuilder: (_, error, stackTrace) => Icon(
          icon ?? Icons.image_not_supported_outlined,
          size: iconSize,
          color: color,
        ),
      );
    }
    return Icon(icon, size: iconSize, color: color);
  }

  Widget _buildLegacyFrostedCircle() {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: circleSize,
          height: circleSize,
          color: White30.value,
        ),
      ),
    );
  }

  Widget _buildFeedFrostedCircle() {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: Container(
            width: circleSize,
            height: circleSize,
            color: AppColors.feedInteractionCircleFill,
          ),
        ),
      ),
    );
  }

  Widget _buildIconSlot(Color color) {
    final iconWidget = _buildIcon(color);
    if (!showCircleBackground) return iconWidget;

    return SizedBox(
      width: circleSize,
      height: circleSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          useFeedFrostedStyle
              ? _buildFeedFrostedCircle()
              : _buildLegacyFrostedCircle(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: child,
            ),
            child: KeyedSubtree(
              key: ValueKey<bool>(isActive),
              child: iconWidget,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iconTint = iconColor ?? (isActive ? activeColor : defaultColor);
    final countTint = countColor ?? Colors.white;
    final caption = count.isNotEmpty ? count : (label ?? '');
    final tapTarget = useFeedFrostedStyle
        ? AppSizes.feedInteractionTapTarget
        : AppSizes.iconTapTarget;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: tapTarget,
            height: tapTarget,
            child: Center(child: _buildIconSlot(iconTint)),
          ),
          if (caption.isNotEmpty) ...[
            SizedBox(height: spacing),
            Text(
              caption,
              style: (countTextStyle ?? AppTypography.feedReelMetric)
                  .copyWith(
                fontSize: countTextStyle == null ? textSize : null,
                color: countTint,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
