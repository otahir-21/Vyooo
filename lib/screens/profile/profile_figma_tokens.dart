import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Profile screen measurements and light-theme tokens (redesign).
abstract final class ProfileFigmaTokens {
  /// Username/handle for profile UI (no leading `@`).
  static String displayUsername(String? raw) =>
      (raw ?? '').replaceAll('@', '').trim();

  // — Light profile palette —
  static const Color screenBackground = Color(0xFFFFFFFF);
  static const Color primaryText = Color(0xFF0C0C0C);
  static const Color secondaryText = Color(0xFF5A5A5A);
  static const Color cardBackground = Color(0xFFF2F2F2);

  /// Story ring around profile avatar (Figma #E51147).
  static const Color storyRing = AppColors.storyRing;

  /// Selected tab accent / profile side rail.
  static const Color accentMagenta = Color(0xFF750047);

  /// Legacy alias used by verification-adjacent accents.
  static const Color accentMagentaAlt = accentMagenta;

  /// Tab track fill — white pill behind Posts / VR / Clips / Tags labels.
  static const Color tabTrack = screenBackground;

  /// Bookmark / star accessory buttons beside the tab pill (Figma 35×39).
  static const double tabAccessoryWidth = 35;
  static const double tabAccessoryHeight = 39;
  static const double tabAccessoryRadius = 12;
  static const Color tabAccessoryIconColor = AppColors.profileTabAccessoryIcon;
  static const double tabAccessorySize = tabAccessoryWidth;
  static const double tabAccessoryIconSize = 18;

  /// Fixed height of the white tab pill (Figma 51px inner track).
  static const double tabBarHeight = 51;
  static const double tabBarRadius = 25.5;
  static const double tabSelectedPillRadius = 19.5;
  /// Drop shadow around tab track (Figma 12% black, 2px blur).
  static const Color tabBarShadowColor = Color(0x1F000000);
  static const double tabBarShadowBlur = 4;
  /// Selected tab fill (#660033).
  static const Color tabSelectedFill = AppColors.feedFollowButton;
  /// Unselected tab label (#5D5F5F).
  static const Color tabUnselectedLabelColor = AppColors.profileTabUnselectedLabel;

  static const double highlightTileWidth = 64;
  static const double highlightTileHeight = 64;
  static const double highlightTileRadius = 12;
  static const double highlightTileGap = 10;
  static const double highlightLabelGap = 6;
  static const double highlightLabelFontSize = 11;
  static const FontWeight highlightLabelFontWeight = FontWeight.w700;
  static const double highlightLabelLineHeight = 14;
  static const Color highlightLabelColor = Color(0xFF494949);
  /// Highlight album placeholder / empty cover (Figma #EFEDED).
  static const Color highlightTileBackground = AppColors.profileStatChipBackground;
  /// Story / highlight add "+" tile fill — matches selected tab chip (#660033).
  static const Color highlightAddFill = tabSelectedFill;

  /// Tile + gap + single-line label — used for the horizontal highlights row.
  static const double highlightRowHeight =
      highlightTileHeight + highlightLabelGap + highlightLabelLineHeight;

  /// Magenta chevron handle — toggles highlights list (width matches Posts tab cell).
  static const double highlightsToggleHeight = 24;
  /// Top corners only — bottom edge is square.
  static const double highlightsToggleTopRadius = 12;
  static const double highlightsToggleTopGap = 8;
  static const double highlightsSectionTopGap = 12;

  /// Edit Profile pill fill — near-black per Figma.
  static const Color actionButtonFill = primaryText;

  /// Secondary circular action buttons.
  static const Color secondaryActionFill = cardBackground;

  /// Total avatar frame (with story ring). ~46% of typical phone width.
  static const double avatarOuterSize = 180;
  static const double avatarRingPadding = 4;
  static const double avatarRingWidth = 3;

  /// Horizontal inset of the header column (matches [AppSpacing.md]).
  static const double profileHeaderHorizontalPad = 16;

  static const double displayNameFontSize = 20;
  static const double displayNameHeight = 25 / 20;
  /// Figma display-name fill (#1B1C1C).
  static const Color displayNameColor = AppColors.profileDisplayName;
  static const double nameVerifiedGap = 6.79;
  static const double verifiedBadgeSize = 18;

  static const double statChipRadius = 12;
  static const double statChipWidth = 100;
  static const double statChipHeight = 72;
  static const double statChipGap = 12;
  static const double statValueFontSize = 16;
  static const double statLabelFontSize = 12;
  /// Stat chip fill (#EFEDED).
  static const Color statChipBackground = AppColors.profileStatChipBackground;
  /// Stat counter value fill (#1B1C1C).
  static const Color statValueColor = AppColors.profileDisplayName;
  /// Stat chip label fill (#554247).
  static const Color statLabelColor = AppColors.profileStatLabel;

  static const double actionButtonHeight = 45;
  static const double actionButtonRadius = 52;
  static const double actionButtonPaddingH = 26;
  static const double actionButtonPaddingV = 10;
  static const double actionButtonGap = 8;
  static const double actionButtonFontSize = 16;
  static const FontWeight actionButtonFontWeight = FontWeight.w500;
  static const double actionIconButtonSize = 45;
  static const double actionIconSize = 22;

  static const double bioFontSize = 14;
  static const double musicFontSize = 12;

  /// Posts / VR / Clips / Tags panel surface.
  static const Color contentSurface = cardBackground;

  /// White margin outside the grey content card (left + right). Figma: full bleed.
  static const double contentSideMargin = 0;

  static const double contentTopRadius = 24;

  /// Gutter between profile post tiles (4pt grid).
  static const double contentGridGap = 2;

  /// Rounded corners on each profile post tile.
  static const double contentGridRadius = 8;

  /// Posts / VR / Saved masonry grid — 4 columns with 2×2 hero per block.
  static const int contentGridCrossAxisCount = 4;
  static const double tabBarOuterPadding = 6;
  static const double tabSelectedFontSize = 16;
  static const double tabUnselectedFontSize = 12;
  static const double tabFontSize = tabUnselectedFontSize;

  static const double headerUsernameFontSize = 18;

  /// Profile side rail (burgundy drawer) beside avatar.
  static const double profileSideRailWidth = 52;
  static const double profileSideRailRadius = 20;
  /// Drawer fill — open and collapsed handle (Figma #660033).
  static const Color sideDrawerFill = AppColors.feedFollowButton;
  /// Vertical offset — lines up with [profileHeaderHorizontalPad] above the avatar.
  static const double profileSideRailTop = 16;
  /// Same height as [avatarOuterSize] (profile photo frame).
  static const double profileSideRailHeight = avatarOuterSize;
  static const double profileSideRailIconSize = 22;
  static const double profileSideAccentWidth = 8;

  /// Collapsed drawer handle — narrow plum pill peeking from the left edge.
  static const double profileSideRailHandleWidth = 14;
  static const Duration profileSideDrawerAnimation = Duration(milliseconds: 260);

  /// Compact other-user profile top bar.
  static const double otherUserHeaderAvatarRadius = 18;
  static const double otherUserHeaderNameFontSize = 15;
  static const double otherUserHeaderHandleFontSize = 13;
  static const double otherUserHeaderFollowFontSize = 13;
  static const Color otherUserHeaderHandleColor = secondaryText;
  static const Color otherUserHeaderFollowBorder = Color(0xFFB0B0B0);

  /// Other-user profile action row — Following / Requested pill.
  static const double profileFollowButtonHeight = 45;
  static const double profileFollowLabelFontSize = 14;
  static const Color profileFollowingBorder = Color(0xFFB0B0B0);
}
