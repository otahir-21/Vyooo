import 'dart:math';

/// Full-screen background image paths (see [pubspec.yaml] `assets/bgImages/`).
class AppBackgroundAssets {
  AppBackgroundAssets._();

  static final Random _random = Random();

  /// Help center (Contact Support).
  static const String contactSupport = 'assets/bgImages/2.png';

  /// Auth, registration, OTP, password recovery, and post-sign-up onboarding.
  static const List<String> authFlowBackgrounds = [
    contactSupport,
    'assets/bgImages/3.png',
    'assets/bgImages/OTPScreenBG.png',
    'assets/bgImages/usernameBG.png',
  ];

  /// Main shell bottom nav (Home, Search, Create, Chat, Profile).
  static const String mainNavBar = 'assets/bgImages/Nav bar.png';

  /// Home feed — Following tab behind stories + reels.
  static const String followingFeed = 'assets/bgImages/usernameBG.png';

  /// Comments bottom sheet (gradient card).
  static const String commentsSection = 'assets/bgImages/Comment_section.png';

  /// OTP verify, username onboarding, and search tab.
  static const String otpScreen = 'assets/bgImages/OTPScreenBG.png';

  /// Search tab (Live, Posts, VR, Users).
  static const String search = otpScreen;

  /// Own profile and other-user profile full-screen background.
  static const String profile = commentsSection;

  static String randomAuthFlowBackground() {
    return authFlowBackgrounds[_random.nextInt(authFlowBackgrounds.length)];
  }
}
