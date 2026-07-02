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

  /// Nav tab chip height (Figma 29px).
  static const double feedTabChipHeight = 29;

  /// Frosted feed tab backdrop blur (Figma ~50px backdrop-filter).
  static const double feedTabBlurSigma = 25;

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

  /// Reel playback control pill — pause + speaker (Figma 114×50).
  static const double feedReelPlaybackControlPillWidth = 114;
  static const double feedReelPlaybackControlPillHeight = 50;
  static const double feedReelPlaybackControlDividerWidth = 2;
  static const double feedReelPlaybackControlDividerHeight = 25;
  static const double feedReelPlaybackControlIconSize = 24;
  static const double feedReelPlaybackControlPlayIconWidth = 14;
  static const double feedReelPlaybackControlBlurSigma = 2.63;

  /// Live stream comment field height (Figma 32).
  static const double liveCommentInputHeight = 32;

  /// Live stream comment field width (Figma 224).
  static const double liveCommentInputWidth = 224;

  /// Live comment placeholder / input — DM Sans 400, 12 / 15, −1% tracking.
  static const double liveCommentInputFontSize = 12;
  static const double liveCommentInputLineHeight = 15;
  static const double liveCommentInputLetterSpacing = -0.12;

  /// Live feed bottom action row height (Figma 32).
  static const double liveFeedActionRowHeight = 32;

  /// Chevron beside comment field (Figma 24×24).
  static const double liveFeedChevronSize = 24;

  /// Share icon in live feed action row (Figma 24×24).
  static const double liveFeedShareIconSize = 24;

  /// Like + count cluster width (Figma 50×24).
  static const double liveFeedLikeClusterWidth = 50;

  /// Gap: comment field → chevron (Figma 12px).
  static const double liveFeedCommentToChevronGap = 12;

  /// Gap: chevron → like cluster (Figma 17px).
  static const double liveFeedChevronToLikeGap = 17;

  /// Gap: like cluster → share (Figma 13px).
  static const double liveFeedLikeToShareGap = 13;

  /// Live feed host row — Figma Frame 2147224757 (370×36).
  static const double liveFeedHostRowWidth = 370;
  static const double liveFeedHostRowHeight = 36;

  /// Live stream title / caption (Figma 16px / 17px line).
  static const double liveFeedHostCaptionFontSize = 16;
  static const double liveFeedHostCaptionLineHeight = 17;

  /// Host avatar in live feed host row (Figma avatar-border 36×36, rx 18).
  static const double liveFeedHostAvatarSize = 36;
  static const double liveFeedHostAvatarBorderWidth = 2;
  static const double liveFeedHostAvatarInnerSize =
      liveFeedHostAvatarSize - liveFeedHostAvatarBorderWidth * 2;

  /// Avatar → title gap (Figma gap 17px).
  static const double liveFeedHostAvatarToCaptionGap = 17;

  /// Title row → live stream progress bar gap (broadcast chrome).
  static const double liveFeedHostToProgressGap = 12;

  /// Live stream progress bar (Figma 402×3, rx 1.5).
  static const double liveFeedStreamProgressHeight = 3;
  static const double liveFeedStreamProgressRadius = 1.5;

  /// Touch target below the 3px live progress bar (scrub area extends downward).
  static const double liveFeedStreamProgressHitHeight = 12;

  /// Inset above clip bottom so the 3px bar sits inside the rounded feed area.
  static const double liveFeedProgressClipBottomInset = 8;

  /// Gap between progress bar and bottom navigation pill (Figma 8px).
  static const double liveFeedProgressToBottomNavGap = 8;

  /// Live stream comment field corner radius (Figma rx=8).
  static const double liveCommentInputRadius = 8;

  /// Live stream share icon (Figma 20×18).
  static const double liveShareIconWidth = 20;
  static const double liveShareIconHeight = 18;

  /// Live feed chat card (Figma card 1 — 370×54).
  static const double liveChatCardHeight = 54;

  /// Top inset for avatar + text inside chat card (Figma 10px).
  static const double liveChatCardContentTopInset = 10;

  /// Live feed chat avatar diameter (Figma 20×20, +10% in app = 22).
  static const double liveChatAvatarSize = 22;

  /// Avatar → text column gap (Figma 16px).
  static const double liveChatAvatarToTextGap = 16;

  /// Username → message gap (Figma 1px).
  static const double liveChatUsernameMessageGap = 1;

  /// Live feed chat username — DM Sans Medium 12 / 16px line.
  static const double liveChatUsernameFontSize = 12;
  static const double liveChatUsernameLineHeight = 16;

  /// Live feed chat message — DM Sans Regular 13 / 17px line.
  static const double liveChatMessageFontSize = 13;
  static const double liveChatMessageLineHeight = 17;

  /// Reel author avatar on feed overlay.
  static const double feedReelAvatarRadius = 18;

  /// Reel overlay "+ Follow" pill (Figma 71×24).
  static const double feedReelFollowButtonHeight = 24;

  /// Plus glyph inside reel follow pill (Figma ~6px).
  static const double feedReelFollowPlusIcon = 10;

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

  /// Live feed Figma artboard (Frame 2147224967 — 402×932).
  static const double liveFeedDesignArtboardWidth = 402;
  static const double liveFeedDesignArtboardHeight = 932;

  /// Horizontal scale vs Figma width — clamped so SE / Pro Max stay usable.
  static double liveFeedWidthScale(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= 0) return 1;
    return (width / liveFeedDesignArtboardWidth).clamp(0.88, 1.12);
  }

  /// Vertical scale vs Figma height.
  static double liveFeedHeightScale(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    if (height <= 0) return 1;
    return (height / liveFeedDesignArtboardHeight).clamp(0.88, 1.12);
  }

  static double liveFeedScaleW(BuildContext context, double designPx) =>
      designPx * liveFeedWidthScale(context);

  static double liveFeedScaleH(BuildContext context, double designPx) =>
      designPx * liveFeedHeightScale(context);

  // — Bottom nav —
  /// Figma tab icon slot — BottomNavBar SVGs use a 24×24 viewBox.
  static const double bottomNavIconSlot = 25;

  /// Tab icon render size inside the tap target / selected pill.
  static const double bottomNavIcon = bottomNavIconSlot;

  /// Profile tab — avatar / placeholder larger than other tab icons.
  static const double bottomNavProfileIcon = 50;
  static const double bottomNavTapTarget = 45;
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
  static const double chatInboxAvatar = 66;
  static const double chatInboxAvatarIcon = 30;
  static const double chatThreadBubbleAvatar = 31;
  static const double chatThreadBubbleAvatarSourceWidth = 30.998;
  static const double chatThreadBubbleAvatarSourceHeight = 37.171;
  static const double chatIncomingBubbleMinHeight = 40.82;
  static const double chatOutgoingBubbleMinHeight = 40.82;
  static const double chatCallBubbleHeight = 66;
  static const double chatCallBubbleRadius = 24;
  static const double chatCallBubbleIcon = 43;
  static const double chatForwardButton = 40;
  /// Chat thread photo/video frame — Figma 185×370 (aspect 1:2).
  static const double chatMediaMessageWidth = 185;
  static const double chatMediaMessageHeight = 370;
  static const double chatNoteAvatar = 64;
  static const double chatNoteAvatarIcon = 26;
  static const double chatNoteItemWidth = 64;
  static const double chatNoteBubbleWidth = 66;
  static const double chatNoteBubbleHeight = 38;
  /// Lifts the note bubble above the avatar — clears profile overlap.
  static const double chatNoteBubbleLift = 12;
  /// Rounded bubble body above the tail — matches note_bubble.svg geometry.
  static const double chatNoteBubbleBodyHeight = 33;
  static const double chatNoteItemStackHeight = 90;
  static const double chatNoteItemGap = 4;
  static const double chatNoteLabelGap = 2;
  static const double chatNoteYourNoteLabelHeight = 9;
  static const double chatNoteNameLabelHeight = 17;
  static const double chatNotesRowHeight =
      chatNoteItemStackHeight + chatNoteLabelGap + chatNoteNameLabelHeight;
  static const double chatNoteNameWidth = 61;
  static const double chatMessagesTitleWidth = 101;
  static const double chatMessagesTitleHeight = 14;
  static const double chatRequestsTitleWidth = 119;
  static const double chatRequestsTitleHeight = 14;
  static const double chatTileUnreadDot = 8;
  static const double chatTileCamera = 24;
  static const double chatTileVerifiedBadge = 14;
  /// Chat thread header profile — Figma mask 41.33 circle (image 41.176×49.375).
  static const double chatThreadHeaderAvatar = 41.33;
  static const double chatThreadHeaderAvatarSourceWidth = 41.176;
  static const double chatThreadHeaderAvatarSourceHeight = 49.375;
  static const double chatSearchHeight = 34;
  static const double chatInboxSectionGap = 20;
  static const double chatComposeButton = 34;
  static const double chatMessageInputHeight = 64;
  static const double chatInputCameraButton = 40;
  static const double chatInputActionIcon = 22;

  /// Chat inbox Figma artboard (402×932).
  static const double chatInboxDesignArtboardWidth = 402;
  static const double chatInboxDesignArtboardHeight = 932;

  static double chatInboxWidthScale(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= 0) return 1;
    return (width / chatInboxDesignArtboardWidth).clamp(0.88, 1.12);
  }

  static double chatInboxHeightScale(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    if (height <= 0) return 1;
    return (height / chatInboxDesignArtboardHeight).clamp(0.88, 1.12);
  }

  static double chatInboxScaleW(BuildContext context, double designPx) =>
      designPx * chatInboxWidthScale(context);

  static double chatInboxScaleH(BuildContext context, double designPx) =>
      designPx * chatInboxHeightScale(context);
}
