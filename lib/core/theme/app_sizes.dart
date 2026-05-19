// 🔴 IMPORTANT:
// Use AppSizes for non-spacing dimensions (fonts, control heights, icon boxes).
// Use AppSpacing / AppPadding for gaps and insets.

/// Shared layout dimensions (4pt grid where applicable).
abstract final class AppSizes {
  // — Controls (typography → [AppTypography]) —
  static const double buttonHeight = 56;
  static const double authToggleHeight = 54;
  static const double authLogoHeight = 30;
  static const double feedLogoHeight = 28;

  /// Settings / account inner app bar — compact wordmark on the right.
  static const double settingsInnerLogoHeight = 20;

  /// Nav tab chip height ≈ 16px label + 12px vertical padding (Figma hug ~33).
  static const double feedTabChipHeight = 33;

  /// Feed header row — tallest of logo vs tab chips.
  static const double feedHeaderRowHeight = feedTabChipHeight;

  /// Feed notification bell — frosted circle + icon (scaled up for legibility).
  static const double feedNotificationCircle = 36;
  static const double feedNotificationIcon = 26;
  static const double feedNotificationTapTarget = 40;
  static const double progressIndicator = 24;

  // — Icons —
  static const double fieldIcon = 22;
  static const double socialIcon = 24;
  static const double socialIconContainer = 40;
  static const double iconTapTarget = 40;

  // — OTP —
  static const double authOtpBoxSize = 70;
}
