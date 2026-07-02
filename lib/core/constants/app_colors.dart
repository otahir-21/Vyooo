import 'package:flutter/material.dart';

/// Shared color constants for Vyooo. Use these instead of hardcoded hex.
class AppColors {
  AppColors._();

  /// Branding Colors (New Gradient Theme)
  static const Color brandPink = Color(0xFFF81945);
  static const Color brandMagenta = Color(0xFFE11066);
  static const Color brandDeepMagenta = Color(0xFFDE106B);
  /// Reel overlay "+ Follow" pill + profile side drawer (Figma #660033).
  static const Color feedFollowButton = Color(0xFF660033);
  /// Light auth surfaces — wordmark and accent links (Figma #600030).
  static const Color authBrandBurgundy = Color(0xFF600030);
  /// Verify-code CTA + floating back (Figma #7B0A3F).
  static const Color authVerifyCta = Color(0xFF7B0A3F);
  /// Onboarding progress bar fill (Figma #D30A57).
  static const Color onboardingProgressFill = Color(0xFFD30A57);
  /// Onboarding progress bar track (Figma #D9D9D9).
  static const Color onboardingProgressTrack = Color(0xFFD9D9D9);
  /// Story avatar ring (Figma profile + feed #E51147).
  static const Color storyRing = Color(0xFFE51147);

  /// Profile display name + stat counter value (Figma #1B1C1C).
  static const Color profileDisplayName = Color(0xFF1B1C1C);

  /// Profile stat chip labels — Posts / Followers / Following (Figma #554247).
  static const Color profileStatLabel = Color(0xFF554247);

  /// Profile stat chip background — Posts / Followers / Following (Figma #EFEDED).
  static const Color profileStatChipBackground = Color(0xFFEFEDED);

  /// Profile tab unselected label — VR / Clips / Tags (Figma #5D5F5F).
  static const Color profileTabUnselectedLabel = Color(0xFF5D5F5F);

  /// Profile tab bookmark / star icon default (Figma #808080).
  static const Color profileTabAccessoryIcon = Color(0xFF808080);

  /// Reel music row ("note" layer) — DM Sans Regular 12 @ #808080.
  static const Color feedReelNoteText = profileTabAccessoryIcon;

  /// Profile side drawer — wallet / chat / revenue icons (Figma #EC709C @ 70%).
  static const Color profileDrawerSecondaryIcon = Color(0xB3EC709C);

  /// Verify-code masked email / phone destination (same Figma accent).
  static const Color authVerifyDestination = storyRing;
  /// Light auth primary CTA fill — muted mauve (Figma sign-in / register).
  static const Color authPrimaryButton = Color(0xFFB8869E);
  /// Reel like heart — filled state (Figma #E31055).
  static const Color feedLikeActive = Color(0xFFE31055);
  /// Frosted reel action circle fill (Figma #FFFFFF @ ~10%).
  static const Color feedInteractionCircleFill = Color(0x1AFFFFFF);
  /// Reel playback pill glass fill (Figma #242323 @ 70%).
  static const Color feedReelPlaybackControlFill = Color(0xB3242323);
  /// Reel playback pill center divider (Figma #8D8C8C).
  static const Color feedReelPlaybackControlDivider = Color(0xFF8D8C8C);
  /// Reel caption hashtags (Figma #FFB3CC).
  static const Color feedReelHashtag = Color(0xFFFFB3CC);

  /// Bottom nav chrome behind the floating pill (Figma dark strip).
  static const Color feedBottomChrome = Color(0xFF0C0C0C);

  /// Home reel progress bar track (Figma remaining segment on dark chrome).
  static const Color feedReelProgressTrack = Color(0xFF333333);
  static const Color brandPurple = Color(0xFF490038);
  static const Color brandDeepPurple = Color(0xFF21002B);
  static const Color brandNearBlack = Color(0xFF07010F);
  static const Color brandBlack = Color(0xFF020109);
  static const Color lightGold = Color(0xFFF7CA39);

  /// Bottom sheets (comments, share)
  static const Color sheetBackground = Color(0xFF2A1B2E);
  static const Color sheetBackgroundShare = Color(0xFF2A2530);

  /// Actions / semantic
  static const Color deleteRed = Color(0xFFE53935);
  static const Color whatsappGreen = Color(0xFF25D366);
  static const Color linkBlue = Color(0xFF2196F3);
  static const Color instagramPink = Color(0xFFE1306C);
  static const Color iconBackgroundDark = Color(0xFF2A2A2A);

  /// Chat — light inbox / thread surfaces (Figma).
  static const Color chatBackground = Color(0xFFFFFFFF);
  static const Color chatSearchFill = Color(0xFFF2F2F7);
  static const Color chatTextPrimary = Color(0xFF1C1C1E);
  static const Color chatTextSecondary = Color(0xFF8E8E93);
  static const Color chatIncomingBubble = Color(0xFFE6E6E6);
  static const Color chatOutgoingBubble = Color(0xFF660033);
  /// Sent text bubble body — Figma #CCC on burgundy bubble.
  static const Color chatSentBubbleText = Color(0xFFCCCCCC);
  /// Incoming text bubble body — Figma black on #E6E6E6.
  static const Color chatIncomingBubbleText = Color(0xFF000000);
  static const Color chatInputBar = Color(0xFF4D4D4D);
  /// Live comment glass field — Figma white @ 10% on blurred backdrop.
  static const Color liveCommentInputGlassFill = Color(0x1AFFFFFF);
  /// Live comment typed + placeholder text — Figma #EEEEEE.
  static const Color liveCommentInputText = Color(0xFFEEEEEE);
  /// Live feed host caption — Figma #F0F0F0.
  static const Color liveFeedHostCaption = Color(0xFFF0F0F0);
  static const Color chatInputHint = Color(0xFF999999);
  static const Color chatDivider = Color(0xFFE5E5EA);
  static const Color chatVerified = Color(0xFF34C759);
  static const Color chatNoteBubbleFill = Color(0xFFFFFFFF);
  static const Color chatNoteBubbleBorder = Color(0xFFE5E5EA);
  /// Inbox note bubble placeholder — Figma #B3B3B3.
  static const Color chatNoteBubbleText = Color(0xFFB3B3B3);
  /// Inbox notes row name label — Figma #333.
  static const Color chatNoteNameText = Color(0xFF333333);
  /// Inbox section Requests title — Figma #AA0055.
  static const Color chatRequestsTitle = Color(0xFFAA0055);
  /// Inbox chat tile unread dot — Figma #EE116C.
  static const Color chatUnreadDot = Color(0xFFEE116C);
  /// Chat thread header display name — Figma 14 / #333.
  static const Color chatThreadHeaderName = Color(0xFF333333);
  /// Chat thread header @username — Figma 12 / #7F7F7F.
  static const Color chatThreadHeaderUsername = Color(0xFF7F7F7F);
  /// Chat thread date pill label — Figma 14 / #999.
  static const Color chatThreadDateLabel = Color(0xFF999999);
  static const Color chatAppBarActionIcon = Color(0xFF808080);
  /// Call log bubble subtitle — Figma #666.
  static const Color chatCallBubbleSubtitle = Color(0xFF666666);

  /// Instagram gradient (share action)
  static const List<Color> instagramGradient = [
    Color(0xFFF77737),
    Color(0xFFE1306C),
    Color(0xFF833AB4),
  ];
}
