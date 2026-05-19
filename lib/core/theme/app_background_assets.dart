import 'dart:math';

/// Full-screen background image paths (see [pubspec.yaml] `assets/bgImages/`).
class AppBackgroundAssets {
  AppBackgroundAssets._();

  static final Random _random = Random();

  /// Auth, registration, OTP, password recovery, and post-sign-up onboarding.
  static const List<String> authFlowBackgrounds = [
    'assets/bgImages/2.png',
    'assets/bgImages/3.png',
    'assets/bgImages/OTPScreenBG.png',
    'assets/bgImages/usernameBG.png',
  ];

  /// Main shell bottom nav (Home, Search, Create, Chat, Profile).
  static const String mainNavBar = 'assets/bgImages/Nav bar.png';

  /// Home feed — Following tab behind stories + reels.
  static const String followingFeed = 'assets/bgImages/usernameBG.png';

  static String randomAuthFlowBackground() {
    return authFlowBackgrounds[_random.nextInt(authFlowBackgrounds.length)];
  }
}
