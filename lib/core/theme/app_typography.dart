import 'package:flutter/material.dart';

import 'app_fonts.dart';
import 'app_theme.dart';

// 🔴 IMPORTANT:
// Do NOT set fontFamily / fontSize inline in screens.
// Use [AppTypography] styles or [Theme.of(context).textTheme].

/// Figma-aligned text styles for Vyooo (auth + shared UI).
abstract final class AppTypography {
  // — Figma auth display (Inter) —
  static const double authHeadlineSize = 30;
  static const double authHeadlineLetterSpacingPercent = -0.03;

  // — Figma UI (DM Sans) —
  static const double inputSize = 16;
  static const double smallBodySize = 12;
  static const double smallBody3Size = 10;
  static const double buttonLabelSize = 20;

  /// White @ 90% — Figma layer opacity on small body copy.
  static const Color smallBodyColor = Color(0xE6FFFFFF);

  /// "Create an Account" — Inter Semi Bold 52 / −3% tracking.
  static const TextStyle authHeadline = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: authHeadlineSize,
    height: 1.0,
    fontWeight: FontWeight.w600,
    letterSpacing: authHeadlineSize * authHeadlineLetterSpacingPercent,
    color: AppTheme.defaultTextColor,
  );

  /// Typed value in underline fields — DM Sans Regular 16.
  static const TextStyle input = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: inputSize,
    height: 1.25,
    fontWeight: FontWeight.w400,
    color: AppTheme.defaultTextColor,
  );

  /// Field placeholder — DM Sans 16 @ ~30% white.
  static const TextStyle inputHint = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: inputSize,
    height: 1.25,
    fontWeight: FontWeight.w400,
    color: Color(0x4DFFFFFF),
  );

  /// Segmented toggle — DM Sans Medium 16.
  static const TextStyle toggleLabel = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: inputSize,
    height: 1.25,
    fontWeight: FontWeight.w500,
  );

  /// OTP digit in verify boxes — DM Sans Semi Bold 32.
  static const TextStyle authOtpDigit = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 32,
    height: 1.0,
    fontWeight: FontWeight.w600,
    color: AppTheme.primary,
  );

  /// Register / Verify CTA — DM Sans Regular 20.
  static const TextStyle primaryButton = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: buttonLabelSize,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: AppTheme.buttonTextColor,
  );

  /// "Already have an account?" — Ag Small body (2): DM Sans 12 @ 90%.
  static const TextStyle authSmallBody = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: smallBodySize,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: smallBodyColor,
  );

  /// "Sign in" / "Resend Code" — DM Sans Bold 12.
  static const TextStyle authSmallBodyBold = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: smallBodySize,
    height: 1.0,
    fontWeight: FontWeight.w700,
    color: AppTheme.primary,
  );

  /// Accent link (e.g. "Can't reset your password?") — DM Sans Medium 12.
  static const Color authAccentLinkColor = Color(0xFFD10057);

  static const TextStyle authAccentLink = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: smallBodySize,
    height: 1.0,
    fontWeight: FontWeight.w500,
    color: authAccentLinkColor,
  );

  /// "Or sign up with" — Ag Small body (3): DM Sans 10 @ 90%.
  static const TextStyle authDividerLabel = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: smallBody3Size,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: smallBodyColor,
  );

  /// Generic secondary 14 — non-auth screens (legacy).
  static const TextStyle label = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w400,
    color: AppTheme.secondaryTextColor,
  );

  /// Generic link 14 — non-auth screens (legacy).
  static const TextStyle labelLink = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: AppTheme.primary,
  );

  /// Errors — DM Sans Regular 12.
  static const TextStyle caption = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: smallBodySize,
    height: 1.3,
    fontWeight: FontWeight.w400,
  );

  /// Logo text fallback — Inter Bold.
  static const TextStyle brandFallback = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppTheme.primary,
  );
}
