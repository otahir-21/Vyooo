import 'package:flutter/material.dart';

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

  /// Story ring / selected tab accent.
  static const Color accentMagenta = Color(0xFF750047);

  /// Legacy alias used by verification-adjacent accents.
  static const Color accentMagentaAlt = accentMagenta;

  /// Tab track fill — white pill behind Posts / VR / Clips / Tags labels.
  static const Color tabTrack = screenBackground;

  /// Bookmark / star accessory buttons beside the tab pill.
  static const Color tabAccessoryBorder = Color(0xFFD4D4D4);
  static const double tabAccessorySize = 36;
  static const double tabAccessoryIconSize = 18;

  /// Fixed height of the white tab pill.
  static const double tabBarHeight = 36;

  static const double highlightTileWidth = 72;
  static const double highlightTileHeight = 72;
  static const double highlightTileRadius = 12;
  static const double highlightTileGap = 10;
  static const double highlightLabelGap = 6;
  static const double highlightLabelFontSize = 11;
  static const FontWeight highlightLabelFontWeight = FontWeight.w700;
  static const double highlightLabelLineHeight = 14;
  static const Color highlightLabelColor = Color(0xFF494949);

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

  static const double displayNameFontSize = 20;
  static const double displayNameHeight = 25 / 20;
  static const double nameVerifiedGap = 6.79;
  static const double verifiedBadgeSize = 18;

  static const double statChipRadius = 12;
  static const double statChipWidth = 76;
  static const double statChipGap = 12;
  static const double statValueFontSize = 16;
  static const double statLabelFontSize = 12;

  static const double actionButtonHeight = 45;
  static const double actionButtonRadius = 52;
  static const double actionButtonPaddingH = 26;
  static const double actionButtonPaddingV = 10;
  static const double actionButtonGap = 8;
  static const double actionButtonFontSize = 13;
  static const FontWeight actionButtonFontWeight = FontWeight.w400;
  static const double actionIconButtonSize = 45;

  static const double bioFontSize = 14;
  static const double musicFontSize = 12;

  /// Posts / VR / Clips / Tags panel surface.
  static const Color contentSurface = cardBackground;

  /// White margin outside the grey content card (left + right).
  static const double contentSideMargin = 12;

  static const double contentTopRadius = 24;

  /// White gutter between profile post tiles (4pt grid).
  static const double contentGridGap = 2;
  static const double contentGridRadius = 0;
  static const double tabBarOuterPadding = 3;
  static const double tabFontSize = 12;

  static const double headerUsernameFontSize = 18;

  /// Profile side rail (magenta drawer) beside avatar.
  static const double profileSideRailWidth = 52;
  static const double profileSideRailSeparatorWidth = 6;
  static const double profileSideRailRadius = 20;
  /// Vertical offset — lines up with [AppSpacing.md] above the profile avatar.
  static const double profileSideRailTop = 16;
  /// Same height as [avatarOuterSize] (profile photo frame).
  static const double profileSideRailHeight = avatarOuterSize;
  static const double profileSideRailIconSize = 22;
  static const Color profileSideRailSeparator = Color(0xFF1C1C1C);
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
