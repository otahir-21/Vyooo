import 'package:flutter/material.dart';

/// Shared color constants for Vyooo. Use these instead of hardcoded hex.
class AppColors {
  AppColors._();

  /// Branding Colors (New Gradient Theme)
  static const Color brandPink = Color(0xFFF81945);
  static const Color brandMagenta = Color(0xFFE11066);
  static const Color brandDeepMagenta = Color(0xFFDE106B);
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

  /// Instagram gradient (share action)
  static const List<Color> instagramGradient = [
    Color(0xFFF77737),
    Color(0xFFE1306C),
    Color(0xFF833AB4),
  ];
}
