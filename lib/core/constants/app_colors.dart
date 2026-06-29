import 'package:flutter/material.dart';

/// Shared color constants for Vyooo. Use these instead of hardcoded hex.
class AppColors {
  AppColors._();

  /// Branding Colors (New Gradient Theme)
  static const Color brandPink = Color(0xFFF81945);
  static const Color brandMagenta = Color(0xFFE11066);
  static const Color brandDeepMagenta = Color(0xFFDE106B);
  /// Reel overlay "+ Follow" pill (Figma #660033).
  static const Color feedFollowButton = Color(0xFF660033);
  /// Light auth surfaces — wordmark, primary CTA, accent links (Figma #600030).
  static const Color authBrandBurgundy = Color(0xFF600030);
  /// Reel like heart — filled state (Figma #9F0E56).
  static const Color feedLikeActive = Color(0xFF9F0E56);
  /// Reel caption hashtags (Figma #FFB3CC).
  static const Color feedReelHashtag = Color(0xFFFFB3CC);

  /// Bottom nav chrome behind the floating pill (Figma dark strip).
  static const Color feedBottomChrome = Color(0xFF0C0C0C);
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
  static const Color chatIncomingBubble = Color(0xFFF2F2F7);
  static const Color chatOutgoingBubble = authBrandBurgundy;
  static const Color chatInputBar = Color(0xFF2C2C2E);
  static const Color chatInputHint = Color(0xFFAEAEB2);
  static const Color chatDivider = Color(0xFFE5E5EA);
  static const Color chatVerified = Color(0xFF34C759);
  static const Color chatNoteBubbleFill = Color(0xFFFFFFFF);
  static const Color chatNoteBubbleBorder = Color(0xFFE5E5EA);
  static const Color chatAppBarActionIcon = Color(0xFF808080);

  /// Instagram gradient (share action)
  static const List<Color> instagramGradient = [
    Color(0xFFF77737),
    Color(0xFFE1306C),
    Color(0xFF833AB4),
  ];
}
