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

  /// Reel action column — frosted circle behind each icon.
  static const double feedInteractionCircle = 28;
  static const double feedInteractionIcon = 14;
  static const double feedInteractionTapTarget = 36;

  /// Reel like heart icon — matches [feedInteractionIcon].
  static const double feedLikeIcon = 14;

  /// Reel author avatar on feed overlay.
  static const double feedReelAvatarRadius = 18;

  /// Following tab — story avatar diameter (Figma).
  static const double followingStoryAvatarSize = 68;
  static const double followingStoryBorderWidth = 3;

  /// Following tab — horizontal story row (avatar only, Figma).
  static const double followingStoryRowHeight = 80;

  /// Following tab — status chevron after tab pills.
  static const double followingStoriesToggleWidth = 50;
  static const double followingStoriesToggleHeight = 30;

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
  static const double bottomNavIcon = 20;
  static const double bottomNavTapTarget = 44;
  static const double bottomNavBarHeight = 60;

  // — Icons —
  static const double fieldIcon = 22;
  static const double socialIcon = 24;
  static const double socialIconContainer = 40;
  static const double iconTapTarget = 40;

  // — OTP —
  static const double authOtpBoxSize = 70;

  // — Chat (Figma inbox / thread) —
  static const double chatInboxAvatar = 48;
  static const double chatThreadBubbleAvatar = 24;
  static const double chatNoteAvatar = 50;
  static const double chatAppBarAvatar = 34;
  static const double chatSearchHeight = 36;
  static const double chatComposeButton = 34;
  static const double chatMessageInputHeight = 44;
  static const double chatInputCameraButton = 32;
  static const double chatInputActionIcon = 22;
}
