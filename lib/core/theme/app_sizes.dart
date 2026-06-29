// 🔴 IMPORTANT:
// Use AppSizes for non-spacing dimensions (fonts, control heights, icon boxes).
// Use AppSpacing / AppPadding for gaps and insets.

import 'package:flutter/material.dart';

/// Shared layout dimensions (4pt grid where applicable).
abstract final class AppSizes {
  // — Controls (typography → [AppTypography]) —
  static const double buttonHeight = 56;
  static const double authToggleHeight = 54;
  static const double authLogoHeight = 52;
  static const double feedLogoHeight = 28;

  /// Settings / account inner app bar — compact wordmark on the right.
  static const double settingsInnerLogoHeight = 20;

  /// Nav tab chip height — 16px label + ~21px font box + 12px vertical padding (Figma).
  static const double feedTabChipHeight = 33;

  /// Feed header top row — logo vs notification bell tap target.
  static const double feedHeaderLogoRowHeight = 40;

  /// Feed header content: logo row + tab row (excludes vertical padding and row gap).
  static const double feedHeaderContentHeight =
      feedHeaderLogoRowHeight + feedTabChipHeight;

  /// Feed notification bell — frosted circle + icon.
  static const double feedNotificationCircle = 36;
  static const double feedNotificationIcon = 22;
  static const double feedNotificationTapTarget = 40;

  /// Reel action column — frosted circle behind each icon (80% of prior Figma base).
  static const double feedInteractionCircle = 44 * 0.8;
  static const double feedInteractionIcon = 22 * 0.8;
  static const double feedInteractionTapTarget = 44 * 0.8;

  /// Reel like heart icon (Figma ~18.28 × 16.47).
  static const double feedLikeIcon = 18;

  /// Reel author avatar on feed overlay.
  static const double feedReelAvatarRadius = 18;

  /// Following tab — story avatar diameter (Figma).
  static const double followingStoryAvatarSize = 68;
  static const double followingStoryBorderWidth = 3;

  /// Following tab — horizontal story row (avatar only, Figma).
  static const double followingStoryRowHeight = 80;

  /// Following tab — collapse chevron square (Figma, right of story row).
  static const double followingStoriesToggleSize = 28;
  static const double followingStoriesToggleIcon = 20;

  /// How far the story row slides up when collapsed (under header).
  static const double followingStoriesCollapsedOverlap = 30;
  static const double progressIndicator = 24;

  /// Figma bottom nav gradient scrim (430×392 frame on ~932pt artboard).
  static const double feedBottomNavScrimDesignHeight = 392;
  static const double feedBottomNavScrimDesignArtboardHeight = 932;

  static double feedBottomNavScrimHeight(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return screenHeight *
        (feedBottomNavScrimDesignHeight / feedBottomNavScrimDesignArtboardHeight);
  }

  // — Bottom nav —
  /// Tab icon asset size inside the 44px tap target / selected pill.
  static const double bottomNavIcon = 28;
  static const double bottomNavTapTarget = 44;
  static const double bottomNavBarHeight = 60;

  // — Icons —
  static const double fieldIcon = 22;
  static const double socialIcon = 24;
  static const double socialIconContainer = 40;
  static const double iconTapTarget = 40;

  // — OTP —
  static const double authOtpBoxSize = 70;
}
