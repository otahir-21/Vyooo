import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../theme/app_typography.dart';

/// Vyooo wordmark for auth and onboarding headers.
///
/// [size] is the layout **height** in logical pixels. The PNG is square with
/// extra transparent padding, so [contentScale] zooms the asset inside that
/// slot — increasing [size] always changes what you see on screen.
class VyoooBrandLogo extends StatelessWidget {
  const VyoooBrandLogo({
    super.key,
    this.width,
    this.size,
    this.height,
    this.contentScale = defaultContentScale,
    this.center = true,
    this.alignment = Alignment.center,
  });

  static const String assetPath =
      'assets/BrandLogo/Logo2.png';

  /// Default layout height (auth headers).
  static const double defaultHeight = 52;

  /// Zoom inside the layout box to offset square-asset transparent padding.
  static const double defaultContentScale = 2.25;

  /// Inner settings/account header — smaller slot, less zoom (matches title scale).
  static const double innerHeaderContentScale = 1.55;

  /// Compact wordmark for [SettingsInnerAppBar] and similar inner screens.
  const VyoooBrandLogo.innerHeader({super.key})
      : width = null,
        size = AppSizes.settingsInnerLogoHeight,
        height = null,
        contentScale = innerHeaderContentScale,
        center = false,
        alignment = Alignment.centerRight;

  final double? width;
  final double? size;
  final double? height;
  final double contentScale;
  final bool center;
  final AlignmentGeometry alignment;

  double get _resolvedHeight => height ?? size ?? defaultHeight;

  @override
  Widget build(BuildContext context) {
    final paintedHeight = _resolvedHeight * contentScale;

    Widget logo = SizedBox(
      height: _resolvedHeight,
      child: ClipRect(
        child: Align(
          alignment: alignment,
          child: Image.asset(
            assetPath,
            width: width,
            height: paintedHeight,
            fit: BoxFit.fitHeight,
            errorBuilder: _errorFallback,
          ),
        ),
      ),
    );

    if (center) {
      logo = Center(child: logo);
    }

    return logo;
  }

  Widget _errorFallback(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    final fallbackSize = _resolvedHeight <= AppSizes.settingsInnerLogoHeight
        ? 14.0
        : (_resolvedHeight * 0.85).clamp(22.0, 42.0);
    return Text(
      'VyooO',
      style: AppTypography.brandFallback.copyWith(fontSize: fallbackSize),
    );
  }
}
