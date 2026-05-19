import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
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
  static const double onboardingSectionTitleSize = 24;
  static const double onboardingSectionTitleLetterSpacingPercent = -0.03;

  /// White @ 52% — username field floating label (Figma).
  static const Color usernameFieldLabelColor = Color(0x84FFFFFF);

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

  /// DOB privacy footnote — DM Sans 12 @ 61% white (Figma).
  static const Color onboardingPrivacyTextColor = Color(0x9CFFFFFF);

  /// Onboarding step title — Inter Semi Bold 24 / 98% line height / −3%.
  static const TextStyle onboardingSectionTitle = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: onboardingSectionTitleSize,
    height: 0.98,
    fontWeight: FontWeight.w600,
    letterSpacing:
        onboardingSectionTitleSize * onboardingSectionTitleLetterSpacingPercent,
    color: AppTheme.defaultTextColor,
  );

  /// DOB privacy body — DM Sans Regular 12 @ 61% white.
  static const TextStyle onboardingPrivacyBody = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: smallBodySize,
    height: 1.25,
    fontWeight: FontWeight.w400,
    color: onboardingPrivacyTextColor,
  );

  /// DOB privacy link — DM Sans Extra Bold 12 @ 61% white.
  static const TextStyle onboardingPrivacyLink = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: smallBodySize,
    height: 1.25,
    fontWeight: FontWeight.w800,
    color: onboardingPrivacyTextColor,
  );

  /// DOB picker — selected row (DM Sans Semi Bold 20).
  static const TextStyle dobPickerSelected = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 20,
    height: 1.0,
    fontWeight: FontWeight.w600,
    color: AppTheme.defaultTextColor,
  );

  /// DOB picker — unselected row (DM Sans Regular 16 @ 35% white).
  static const TextStyle dobPickerUnselected = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: inputSize,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: Color(0x59FFFFFF),
  );

  /// Username pill floating label — DM Sans Semi Bold 12 @ 52% white.
  static const TextStyle usernameFieldLabel = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: smallBodySize,
    height: 1.0,
    fontWeight: FontWeight.w600,
    color: usernameFieldLabelColor,
  );

  /// Username pill value — DM Sans Semi Bold 16.
  static const TextStyle usernameFieldValue = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: inputSize,
    height: 1.0,
    fontWeight: FontWeight.w600,
    color: AppTheme.defaultTextColor,
  );

  /// Username unavailable — DM Sans Regular 10 @ brand pink.
  static const TextStyle usernameAvailabilityError = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: smallBody3Size,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: AppColors.brandPink,
  );

  /// Settings / account inner screen app bar title — DM Sans Bold 16.
  static const TextStyle settingsInnerAppBarTitle = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 16,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: AppTheme.defaultTextColor,
  );

  /// Auth modal title — DM Sans Semi Bold 18.
  static const TextStyle authDialogTitle = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 18,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: AppTheme.defaultTextColor,
  );

  /// Auth modal option row — DM Sans Medium 16.
  static const TextStyle authDialogOption = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: inputSize,
    height: 1.25,
    fontWeight: FontWeight.w500,
    color: AppTheme.defaultTextColor,
  );

  /// Auth modal cancel — DM Sans Regular 16 @ 70% white.
  static const TextStyle authDialogCancel = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: inputSize,
    height: 1.25,
    fontWeight: FontWeight.w400,
    color: White70.value,
  );

  /// Username suggestion row — DM Sans Semi Bold 16.
  static const TextStyle usernameSuggestion = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: inputSize,
    height: 1.0,
    fontWeight: FontWeight.w600,
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

  /// Home feed tab label sizes (Figma Nav Bar).
  static const double feedTabLabelSize = 14;
  static const double feedTabLabelSelectedSize = 16;

  /// Home feed tab — unselected (Figma: DM Sans Regular 14, white 60%).
  static const TextStyle feedTabLabel = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: feedTabLabelSize,
    fontWeight: FontWeight.w400,
    color: White60.value,
  );

  /// Home feed tab — selected (Figma: DM Sans Bold 16, white).
  static const TextStyle feedTabLabelSelected = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: feedTabLabelSelectedSize,
    fontWeight: FontWeight.w700,
    color: AppTheme.primary,
  );

  // — Reel feed overlay (Figma) —
  static const double feedReelDisplayNameSize = 20;
  static const double feedReelHandleSize = 14;
  static const double feedReelCaptionSize = 16;
  static const double feedReelMetricSize = 10;

  /// Author display name on reel — DM Sans Regular 20.
  static const TextStyle feedReelDisplayName = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: feedReelDisplayNameSize,
    fontWeight: FontWeight.w400,
    color: AppTheme.primary,
  );

  /// @handle under display name — DM Sans Regular 14.
  static const TextStyle feedReelHandle = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: feedReelHandleSize,
    fontWeight: FontWeight.w400,
    color: White70.value,
  );

  /// Reel caption body — DM Sans Regular 16.
  static const TextStyle feedReelCaption = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: feedReelCaptionSize,
    fontWeight: FontWeight.w400,
    height: 1.25,
    color: AppTheme.primary,
  );

  /// "See more" on collapsed caption — DM Sans Regular 16 @ 90% white.
  static const TextStyle feedReelCaptionSeeMore = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: feedReelCaptionSize,
    fontWeight: FontWeight.w400,
    color: smallBodyColor,
  );

  /// Like / comment counts — DM Sans Regular 10 (Icons/active).
  static const TextStyle feedReelMetric = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: feedReelMetricSize,
    fontWeight: FontWeight.w400,
  );

  /// Expanded location label on reel caption.
  static const TextStyle feedReelLocation = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: feedReelHandleSize,
    fontWeight: FontWeight.w500,
    color: AppTheme.primary,
  );

  /// Logo text fallback — Inter Bold.
  static const TextStyle brandFallback = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppTheme.primary,
  );
}
