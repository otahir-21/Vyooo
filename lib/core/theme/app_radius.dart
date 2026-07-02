import 'package:flutter/widgets.dart';

/// Border radius standards: 12 → Inputs/cards, 20 → Pills, 30 → Full-width buttons.
abstract final class AppRadius {
  static const double input = 12;
  static const double pill = 20;

  /// Onboarding DOB picker selection band corner radius (Figma rx 7).
  static const double onboardingDobPickerSelection = 7;

  /// Auth Phone/Email segmented control outer track (Figma rx 27).
  static const double authToggle = 27;

  /// Verify-code OTP digit box (Figma rx 9.67742 on 50px width).
  static const double authOtpBox = 9.67742;
  static const double button = 30;
  static const double card = 8;

  /// Home feed nav chips — rounded rect (Figma rx 9 on 29px height).
  static const double feedTab = 9;

  /// Reel overlay "+ Follow" pill — stadium cap (Figma rx 12 on 24px height).
  static const double feedReelFollowButton = 12;

  /// Reel playback control pill — pause + speaker (Figma rx 25 on 50px height).
  static const double feedReelPlaybackControlPill = 25;

  /// Bottom nav outer chrome — bottom corners only (Figma).
  static const double feedBottomChrome = 24;

  static BorderRadius get feedBottomChromeRadius => const BorderRadius.only(
        bottomLeft: Radius.circular(feedBottomChrome),
        bottomRight: Radius.circular(feedBottomChrome),
      );

  /// Reel post bottom edge — rounded before the nav chrome (bottom only).
  static BorderRadius get feedPostBottomRadius => feedBottomChromeRadius;

  static BorderRadius get inputRadius => BorderRadius.circular(input);
  static BorderRadius get pillRadius => BorderRadius.circular(pill);
  static BorderRadius get buttonRadius => BorderRadius.circular(button);
  static BorderRadius get feedTabRadius => BorderRadius.circular(feedTab);
  static BorderRadius get feedReelFollowButtonRadius =>
      BorderRadius.circular(feedReelFollowButton);
  static BorderRadius get feedReelPlaybackControlPillRadius =>
      BorderRadius.circular(feedReelPlaybackControlPill);
  static BorderRadius get authOtpBoxRadius =>
      BorderRadius.circular(authOtpBox);

  /// Outgoing chat bubble — Figma sent bubble (133×41, fill #660033).
  static const double chatOutgoingBubbleRadiusTopLeft = 20.4103;
  static const double chatOutgoingBubbleRadiusTopRight = 22.5846;
  static const double chatOutgoingBubbleRadiusBottomRight = 11.2923;
  static const double chatOutgoingBubbleRadiusBottomLeft = 20.4103;

  static BorderRadius get chatOutgoingBubbleRadius => const BorderRadius.only(
        topLeft: Radius.circular(chatOutgoingBubbleRadiusTopLeft),
        topRight: Radius.circular(chatOutgoingBubbleRadiusTopRight),
        bottomRight: Radius.circular(chatOutgoingBubbleRadiusBottomRight),
        bottomLeft: Radius.circular(chatOutgoingBubbleRadiusBottomLeft),
      );
}
