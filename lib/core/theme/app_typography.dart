import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'app_fonts.dart';
import 'app_sizes.dart';
import 'app_theme.dart';

// 🔴 IMPORTANT:
// Do NOT set fontFamily / fontSize inline in screens.
// Use [AppTypography] styles or [Theme.of(context).textTheme].

/// Figma-aligned text styles for Vyooo (auth + shared UI). All use DM Sans.
abstract final class AppTypography {
  // — Auth / section titles —
  static const double authHeadlineSize = 40;
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

  /// "Create an Account" / auth titles — Inter Semi Bold 40 / 100% line height / −3%.
  static const TextStyle authHeadline = TextStyle(
    fontFamily: AppFonts.headline,
    fontSize: authHeadlineSize,
    height: 1.0,
    fontWeight: FontWeight.w600,
    letterSpacing: authHeadlineSize * authHeadlineLetterSpacingPercent,
    color: AppTheme.defaultTextColor,
  );

  /// DOB privacy footnote — DM Sans 12 @ 61% white (Figma).
  static const Color onboardingPrivacyTextColor = Color(0x9CFFFFFF);

  /// Onboarding step title — DM Sans Semi Bold 24 / 98% line height / −3%.
  static const TextStyle onboardingSectionTitle = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: onboardingSectionTitleSize,
    height: 0.98,
    fontWeight: FontWeight.w600,
    letterSpacing:
        onboardingSectionTitleSize * onboardingSectionTitleLetterSpacingPercent,
    color: AppTheme.defaultTextColor,
  );

  /// Light onboarding step title — DM Sans Medium 24 / 98% / −3% / #464646 (Figma).
  static const Color onboardingLightSectionTitleColor = Color(0xFF464646);

  static const TextStyle onboardingLightSectionTitle = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: onboardingSectionTitleSize,
    height: 0.98,
    fontWeight: FontWeight.w500,
    letterSpacing:
        onboardingSectionTitleSize * onboardingSectionTitleLetterSpacingPercent,
    color: onboardingLightSectionTitleColor,
  );

  /// Light onboarding step subtitle — DM Sans Regular 12 @ #808080 (Figma).
  static const Color onboardingLightSectionSubtitleColor = Color(0xFF808080);

  static const TextStyle onboardingLightSectionSubtitle = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: smallBodySize,
    height: 14 / smallBodySize,
    fontWeight: FontWeight.w400,
    color: onboardingLightSectionSubtitleColor,
  );

  /// DOB privacy body — DM Sans Regular 12 @ 61% white.
  static const TextStyle onboardingPrivacyBody = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: smallBodySize,
    height: 1.25,
    fontWeight: FontWeight.w400,
    color: onboardingPrivacyTextColor,
  );

  /// DOB privacy link — DM Sans Bold 12 @ 61% white.
  static const TextStyle onboardingPrivacyLink = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: smallBodySize,
    height: 1.25,
    fontWeight: FontWeight.w700,
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

  /// Light onboarding DOB picker — selected row (DM Sans Semi Bold 20 / black).
  static const TextStyle onboardingDobPickerSelected = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 20,
    height: 1.0,
    fontWeight: FontWeight.w600,
    color: Color(0xFF000000),
  );

  /// Light onboarding DOB picker — adjacent faded row (DM Sans Regular 16).
  static const TextStyle onboardingDobPickerUnselected = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: inputSize,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: Color(0x85000000),
  );

  /// Username pill floating label — DM Sans Semi Bold 12 @ 52% white.
  static const TextStyle usernameFieldLabel = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: smallBodySize,
    height: 1.0,
    fontWeight: FontWeight.w600,
    color: usernameFieldLabelColor,
  );

  /// Light onboarding username pill label — DM Sans Semi Bold 12 / #686868 @ 52%.
  static const Color onboardingUsernameFieldLabelColor = Color(0x84686868);

  static const TextStyle onboardingUsernameFieldLabel = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: smallBodySize,
    height: 1.0,
    fontWeight: FontWeight.w600,
    color: onboardingUsernameFieldLabelColor,
  );

  /// Light onboarding username pill value — DM Sans Medium 16 / 100% lh / black.
  static const TextStyle onboardingUsernameFieldValue = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: inputSize,
    height: 1.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: Color(0xFF000000),
  );

  /// Username pill value — alias for light auth / onboarding surfaces.
  static const TextStyle usernameFieldValue = onboardingUsernameFieldValue;

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

  /// Username suggestion row — DM Sans Semi Bold 16 (light auth surfaces).
  static const TextStyle usernameSuggestion = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: inputSize,
    height: 1.0,
    fontWeight: FontWeight.w600,
    color: AppTheme.lightOnSurface,
  );

  /// Typed value in underline fields — DM Sans Regular 16.
  static const TextStyle input = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: inputSize,
    height: 1.25,
    fontWeight: FontWeight.w400,
    color: AppTheme.defaultTextColor,
  );

  /// Light auth underline field — typed text (Figma #000 @ 100% lh).
  static const TextStyle authInput = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: inputSize,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: AppTheme.lightOnSurface,
  );

  /// Light auth underline field — empty placeholder (Figma #999999).
  static const TextStyle authInputHint = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: inputSize,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: Color(0xFF999999),
  );

  /// Field placeholder — DM Sans 16 @ ~30% white.
  static const TextStyle inputHint = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: inputSize,
    height: 1.25,
    fontWeight: FontWeight.w400,
    color: Color(0x4DFFFFFF),
  );

  /// Live comment field — DM Sans Regular 12 / 15 @ #EEEEEE, −1% tracking.
  static const TextStyle liveCommentInput = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: AppSizes.liveCommentInputFontSize,
    height: AppSizes.liveCommentInputLineHeight /
        AppSizes.liveCommentInputFontSize,
    fontWeight: FontWeight.w400,
    letterSpacing: AppSizes.liveCommentInputLetterSpacing,
    color: AppColors.liveCommentInputText,
  );

  /// Live feed like count beside heart (Figma #FFFFFF).
  static const TextStyle liveFeedLikeCount = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 12,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: Colors.white,
  );

  /// Live feed host caption — Figma Poppins SemiBold 16/17 @ #F0F0F0 (DM Sans 600).
  static const TextStyle liveFeedHostCaption = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: AppSizes.liveFeedHostCaptionFontSize,
    height: AppSizes.liveFeedHostCaptionLineHeight /
        AppSizes.liveFeedHostCaptionFontSize,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AppColors.liveFeedHostCaption,
  );

  /// Live feed chat username — DM Sans Medium 12 / 16px line (Figma card 1).
  static const TextStyle liveChatUsername = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: AppSizes.liveChatUsernameFontSize,
    height: AppSizes.liveChatUsernameLineHeight /
        AppSizes.liveChatUsernameFontSize,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );

  /// Live feed chat message — DM Sans Regular 13 / 17px line @ 60% white.
  static const TextStyle liveChatMessage = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: AppSizes.liveChatMessageFontSize,
    height:
        AppSizes.liveChatMessageLineHeight / AppSizes.liveChatMessageFontSize,
    fontWeight: FontWeight.w400,
    color: Color(0x99FFFFFF),
  );

  /// Segmented toggle — DM Sans Regular 16, 100% line height (Figma).
  static const TextStyle toggleLabel = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: inputSize,
    height: 1.0,
    fontWeight: FontWeight.w400,
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

  /// Verify-code instruction line — DM Sans Regular 14 @ #808080.
  static const TextStyle authVerifyInstruction = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 14,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: Color(0xFF808080),
  );

  /// "Didn't receive OTP?" — DM Sans Regular 12 @ 78% #808080.
  static const TextStyle authVerifyMutedLabel = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: smallBodySize,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: Color(0xC7808080),
  );

  /// Verify-code masked destination — DM Sans Regular 14 @ #E51147.
  static const TextStyle authVerifyDestination = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 14,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: AppColors.authVerifyDestination,
  );

  /// Verify-code secondary link — DM Sans Regular 12 @ 90% black.
  static const TextStyle authVerifySecondaryLink = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: smallBodySize,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: Color(0xE6000000),
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

  /// Home feed tab labels (Figma Nav Bar) — both states use 16px / 100% line height.
  static const double feedTabLabelSize = 16;

  /// Home feed tab — unselected (Figma: DM Sans Regular 16, white).
  static const TextStyle feedTabLabel = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: feedTabLabelSize,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: AppTheme.primary,
  );

  /// Home feed tab — selected on white pill (Figma: DM Sans Bold 16, black).
  static const TextStyle feedTabLabelSelected = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: feedTabLabelSize,
    height: 1.0,
    fontWeight: FontWeight.w700,
    color: AppTheme.buttonTextColor,
  );

  // — Reel feed overlay (Figma) —
  static const double feedReelUsernameSize = 16;
  static const double feedReelDisplayNameSize = 20;
  static const double feedReelHandleSize = 14;
  static const double feedReelCaptionSize = 16;
  static const double feedReelHashtagSize = 14;
  static const double feedReelMetricSize = 10;
  static const double feedReelActionLabelSize = 10;
  static const double feedReelMusicSize = 12;
  static const double feedReelFollowChipSize = 12;

  /// @username on reel overlay — DM Sans Bold 16, white.
  static const TextStyle feedReelUsername = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: feedReelUsernameSize,
    height: 1.0,
    fontWeight: FontWeight.w700,
    color: AppTheme.primary,
  );

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

  /// Reel caption body — DM Sans Regular 16 @ 100% line height.
  static const TextStyle feedReelCaption = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: feedReelCaptionSize,
    fontWeight: FontWeight.w400,
    height: 1.0,
    color: AppTheme.primary,
  );

  /// Hashtags in reel caption — DM Sans Medium 14 @ #FFB3CC.
  static const TextStyle feedReelHashtag = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: feedReelHashtagSize,
    height: 1.0,
    fontWeight: FontWeight.w500,
    color: AppColors.feedReelHashtag,
  );

  /// "See more" on collapsed caption — DM Sans Regular 16 @ 90% white.
  static const TextStyle feedReelCaptionSeeMore = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: feedReelCaptionSize,
    fontWeight: FontWeight.w400,
    height: 1.0,
    color: smallBodyColor,
  );

  static const double profileGridTitleSize = 10;
  static const double profileGridTitleHeroSize = 11;
  static const double profileDisplayNameSize = 20;

  /// Profile header display name — DM Sans SemiBold 20 / #1B1C1C (Figma).
  static const TextStyle profileDisplayName = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: profileDisplayNameSize,
    fontWeight: FontWeight.w600,
    height: 25 / profileDisplayNameSize,
    color: AppColors.profileDisplayName,
  );

  /// Profile stat counter — DM Sans SemiBold 16 / #1B1C1C (Figma).
  static const TextStyle profileStatValue = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.0,
    color: AppColors.profileDisplayName,
  );

  /// Profile stat label — DM Sans Regular 12 / #554247 (Figma).
  static const TextStyle profileStatLabel = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.0,
    color: AppColors.profileStatLabel,
  );

  /// Highlights add chip label — DM Sans Regular 12 / #554247 (Figma).
  static const TextStyle profileHighlightAddLabel = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 14 / 12,
    color: AppColors.profileStatLabel,
  );

  /// Highlight album title — DM Sans Regular 12 / #1B1C1C (Figma).
  static const TextStyle profileHighlightAlbumLabel = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 14 / 12,
    color: AppColors.profileDisplayName,
  );

  /// Profile primary action pill — DM Sans Medium 16 / 16 line height / white (Figma Edit Profile).
  static const TextStyle profileActionButtonLabel = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.0,
    letterSpacing: 0,
    color: Colors.white,
  );

  /// Profile tab — selected chip label (Figma Inter Bold 16 / 18 / 0.55px / white).
  static const TextStyle profileTabSelectedLabel = TextStyle(
    fontFamily: AppFonts.headline,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 18 / 16,
    letterSpacing: 0.55,
    color: Colors.white,
  );

  /// Profile tab — unselected label (Figma #5D5F5F).
  static const TextStyle profileTabUnselectedLabel = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.0,
    color: AppColors.profileTabUnselectedLabel,
  );

  /// Short label on profile grid tiles — DM Sans SemiBold 10.
  static const TextStyle profileGridTitle = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: profileGridTitleSize,
    fontWeight: FontWeight.w600,
    height: 1.1,
    color: AppTheme.primary,
  );

  /// Profile grid title on 2×2 hero tiles.
  static const TextStyle profileGridTitleHero = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: profileGridTitleHeroSize,
    fontWeight: FontWeight.w600,
    height: 1.1,
    color: AppTheme.primary,
  );

  /// Like / comment counts — DM Sans Regular 10.
  static const TextStyle feedReelMetric = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: feedReelMetricSize,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: AppTheme.primary,
  );

  /// Save / Share labels under action icons — DM Sans SemiBold 10.
  static const TextStyle feedReelActionLabel = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: feedReelActionLabelSize,
    height: 1.0,
    fontWeight: FontWeight.w600,
    color: AppTheme.primary,
  );

  /// "+ Follow" chip on reel overlay — DM Sans Regular 12, white.
  static const TextStyle feedReelFollowChip = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: feedReelFollowChipSize,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: AppTheme.primary,
  );

  /// Music line under reel caption — DM Sans Regular 12 @ 80% white (Figma).
  static const TextStyle feedReelMusic = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: feedReelMusicSize,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: White80.value,
  );

  /// Expanded location label on reel caption.
  static const TextStyle feedReelLocation = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: feedReelHandleSize,
    fontWeight: FontWeight.w500,
    color: AppTheme.primary,
  );

  /// Logo text fallback — DM Sans Bold.
  static const TextStyle brandFallback = TextStyle(
    fontFamily: AppFonts.body,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppTheme.primary,
  );

  // — Chat (light inbox / thread — Figma) —

  static const TextStyle chatInboxTitle = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 17,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: AppColors.chatTextPrimary,
  );

  static const TextStyle chatSectionHeader = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: AppColors.chatTextPrimary,
  );

  static const TextStyle chatTileName = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: AppColors.chatTextPrimary,
  );

  static const TextStyle chatTilePreview = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w400,
    color: AppColors.chatTextSecondary,
  );

  static const TextStyle chatBubbleText = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle chatDateSeparator = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w400,
    color: AppColors.chatTextSecondary,
  );

  static const TextStyle chatAppBarName = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: AppColors.chatTextPrimary,
  );

  static const TextStyle chatAppBarUsername = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w400,
    color: AppColors.chatTextSecondary,
  );
}
