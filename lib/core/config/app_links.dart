/// Legal URLs used in-app (subscription screen, onboarding) and should match
/// App Store Connect: Privacy Policy field + Terms link in the App Description
/// (or a custom EULA in App Information).
class AppLinks {
  AppLinks._();

  static const String termsOfUse = 'https://www.vyooo.com/terms';
  static const String privacyPolicy = 'https://www.vyooo.com/privacy';

  /// Apple’s standard Licensed Application EULA. If you rely on it, Apple expects
  /// a functional link in App Store metadata (often in the App Description).
  /// See: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
  static const String appleStandardLicensedApplicationEula =
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
}
