import 'package:flutter/material.dart';

/// Figma profile screen measurements (Personal profile frame).
abstract final class ProfileFigmaTokens {
  /// Username/handle for profile UI (no leading `@`).
  static String displayUsername(String? raw) =>
      (raw ?? '').replaceAll('@', '').trim();
  // Background gradient stops — see [AppGradients.personalProfileBackgroundGradient].

  /// Profile ring / accents — Figma selection (#D22C6C).
  static const Color accentMagenta = Color(0xFFD22C6C);

  /// Ring alternate from Figma (#F92244).
  static const Color accentMagentaAlt = Color(0xFFF92244);

  /// Tab track fill.
  static const Color tabTrack = Color(0xFF2B1C2D);

  /// Edit / Share pill fill.
  static const Color actionButtonFill = Color(0xFF1C1C1F);

  /// Edit / Share inside stroke — white @ 15%.
  static const Color actionButtonStroke = Color(0x26FFFFFF);

  static const double avatarOuterSize = 169;
  static const double avatarRingPadding = 6.06;
  static const double avatarRingWidth = 3;

  static const double displayNameFontSize = 20;
  static const double displayNameHeight = 25 / 20;
  static const double nameVerifiedGap = 6.79;
  static const double verifiedBadgeSize = 18;

  static const double statChipWidth = 76;
  static const double statChipRadius = 5.49;
  static const double statChipBorderWidth = 0.69;
  static const double statValueFontSize = 16;
  static const double statLabelFontSize = 9;

  static const double actionButtonWidth = 154;
  static const double actionButtonHeight = 45;
  static const double actionButtonRadius = 52;
  static const double actionButtonPaddingH = 26;
  static const double actionButtonPaddingV = 10;
  static const double actionButtonGap = 8;
  static const double actionIconGap = 5;

  static const double bioFontSize = 16;
  static const double musicFontSize = 12;

  /// Posts / VR / Streams panel — matches other-user profile surface.
  static const Color contentSurface = Color(0xFF1A0B1E);

  static const double contentTopRadius = 24;
  static const double tabBarOuterPadding = 4;
  static const double tabVerticalPadding = 10;
  static const double tabFontSize = 13;

  static const double headerUsernameFontSize = 18;
}
