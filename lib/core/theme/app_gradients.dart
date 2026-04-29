import 'package:flutter/material.dart';

/// 🔴 Do NOT define gradients inside screens.
/// Always use AppGradients.
/// This ensures brand consistency across the entire app.

class AppGradients {
  AppGradients._();

  /// Main background gradient (Dark to Bright)
  static final LinearGradient mainBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      const Color(0xFFF81945),
      const Color(0xFFE11066),
      const Color(0xFFDE106B).withValues(alpha: .9),
      const Color(0xFF6A0443).withValues(alpha: .97),
      const Color(0xFF490038),
      const Color(0xFF21002B),
      const Color(0xFF07010F),
      const Color(0xFF020109),
    ],
    stops: const [0.0, 0.15, 0.25, 0.45, 0.65, 0.80, 0.90, 1.0],
  );

  /// Auth (maps to main background for consistency)
  static final LinearGradient authGradient = mainBackgroundGradient;

  static const LinearGradient onboardingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF020109),
      Color(0xFF07010F),
      Color(0xFF21002B),
      Color(0xFF490038),
      Color(0xFFDE106B),
      Color(0xFFE11066),
      Color(0xFFF81945),
    ],
  );

  static const LinearGradient profileCardBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF000000), Color(0xFF352037), Color(0xFFD22C6C)],
  );

  static const LinearGradient dobGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF020109),
      Color(0xFF07010F),
      Color(0xFF21002B),
      Color(0xFF490038),
      Color(0xFFDE106B),
    ],
  );

  static const LinearGradient profileGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF020109),
      Color(0xFF21002B),
      Color(0xFFDE106B),
      Color(0xFFF81945),
    ],
  );

  /// Subscription plan cards (dark purple to pink).
  static const LinearGradient subscriptionCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF21002B), Color(0xFF490038), Color(0xFFDE106B)],
  );

  static const LinearGradient feedGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF020109),
      Color(0xFF07010F),
      Color(0xFF21002B),
      Color(0xFF490038),
    ],
  );

  /// VR locked view bottom card (dark translucent).
  static const LinearGradient vrPaymentCardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xE614001F), Color(0xF021002B), Color(0xF0490038)],
  );

  /// Story avatar ring (pink gradient border).
  static const LinearGradient storyRingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD10057), Color(0xFFFF6B9D)],
  );

  /// Pink primary button (e.g. Get started).
  static const LinearGradient vrGetStartedButtonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFDE106B), Color(0xFFF81945)],
  );

  /// Download prompt "Subscribe Now" button (gold to orange-brown).
  static const LinearGradient subscribeNowButtonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFE8C547), Color(0xFFD4A84B), Color(0xFFB8862E)],
  );

  /// Premium dark pink-to-purple background (used in Settings, Search, Notifications)
  static const LinearGradient premiumDarkGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [Color(0xFFE81E57), Color(0xFF380D2D), Color(0xFF130412)],
    stops: [0.0, 0.3, 1.0],
  );
}
