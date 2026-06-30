// 🔴 IMPORTANT:
// Use AppSizes for non-spacing dimensions (fonts, control heights, icon boxes).
// Use AppSpacing / AppPadding for gaps and insets.

import 'package:flutter/material.dart';

/// Shared layout dimensions (4pt grid where applicable).
abstract final class AppSizes {
  // — Controls (typography → [AppTypography]) —
  static const double buttonHeight = 56;
  /// Auth Phone/Email pill track (Figma 60×342, rx 27).
  static const double authToggleHeight = 60;

  /// Inset between auth toggle track edge and selected pill.
  static const double authToggleInset = 3;
  static const double authLogoHeight = 40;
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

  /// Reel action column — frosted circle behind each icon (Figma 42×42).
  static const double feedInteractionCircle = 42;
  static const double feedInteractionIcon = 42;
  static const double feedInteractionTapTarget = 48;

  /// Reel like heart icon inside the frosted circle.
  static const double feedLikeIcon = 42;

  /// Live stream comment field height (Figma 32).
  static const double liveCommentInputHeight = 32;

  /// Live stream comment field corner radius (Figma rx=8).
  static const double liveCommentInputRadius = 8;

  /// Live stream share icon (Figma 20×18).
  static const double liveShareIconWidth = 20;
  static const double liveShareIconHeight = 18;

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
  /// Figma tab icon slot — BottomNavBar SVGs use a 24×24 viewBox.
  static const double bottomNavIconSlot = 20;

  /// Tab icon render size inside the 44px tap target / selected pill.
  static const double bottomNavIcon = bottomNavIconSlot;

  /// Profile tab — avatar / placeholder larger than other tab icons.
  static const double bottomNavProfileIcon = 36;
  static const double bottomNavTapTarget = 44;
  static const double bottomNavBarHeight = 60;

  // — Icons —
  static const double fieldIcon = 22;

  /// Auth field prefix slot — aligns mixed-width Figma SVG icons.
  static const double authFieldPrefixWidth = 24;
  static const double authNameIconWidth = 15;
  static const double authNameIconHeight = 16;
  static const double authEmailIconWidth = 16;
  static const double authEmailIconHeight = 11;
  static const double authPhoneIconWidth = 14;
  static const double authPhoneIconHeight = 14;
  static const double authPasswordIconWidth = 15;
  static const double authPasswordIconHeight = 13;
  static const double authPasswordVisibilityIconWidth = 15;
  static const double authPasswordVisibilityIconHeight = 8;

  /// Figma auth divider line artboard height.
  static const double authDividerLineHeight = 9;

  /// Figma "Or sign up with" vector label height.
  static const double authDividerLabelHeight = 10;

  /// Figma remember-me label height.
  static const double authRememberMeLabelHeight = 9;

  /// Figma forgot-password label height.
  static const double authForgotPasswordLabelHeight = 12;

  /// Nudge divider_line.svg stroke (top of viewBox) to label vertical center.
  static const double authDividerLineStrokeOffsetY = 4;
  static const double socialIcon = 24;
  static const double socialIconContainer = 40;
  static const double iconTapTarget = 40;

  // — OTP (Figma verify-code: 50×50 boxes) —
  static const double authOtpBoxSize = 50;
  static const double authOtpBoxHeight = 50;

  /// Username onboarding — profile placeholder avatar (Figma 162×162).
  static const double onboardingProfileAvatarSize = 162;

  /// Username onboarding — input pill height (Figma 62).
  static const double onboardingUsernameFieldHeight = 62;

  /// Onboarding step progress bar height (Figma 2).
  static const double onboardingProgressBarHeight = 2;

  /// Onboarding DOB picker — Figma artboard 297×179.
  static const double onboardingDobPickerHeight = 179;
  static const double onboardingDobPickerItemExtent = 35;
  static const double onboardingDobPickerFadeHeight = 72;

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
