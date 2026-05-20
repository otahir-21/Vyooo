/// Centralized deep-link/share URL builder.
///
/// Share text uses [profileAppUri] (`vyooo://profile/...`) so WhatsApp opens the
/// app directly without requiring `www.vyooo.com/open` on the server.
/// Universal-link HTTPS URLs ([profileWebUri]) are for after `/open` + `.well-known`
/// files are deployed on the domain.
class DeepLinkConfig {
  DeepLinkConfig._();

  static const String webHost = 'www.vyooo.com';
  static const String customScheme = 'vyooo';

  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.vyooo';

  /// Set when App Store listing id is known (Firestore `iosAppStoreId` or here).
  static const String? iosAppStoreUrl = null;

  /// Web bridge path — host [open/index.html] redirects into the app (see [web/www_vyooo_deep_link]).
  static const String webOpenPath = '/open';

  static Uri reelWebUri(String reelId) {
    return Uri.https(webHost, webOpenPath, {'reel': reelId});
  }

  static Uri reelAppUri(String reelId) {
    return Uri(
      scheme: customScheme,
      host: 'reel',
      pathSegments: [reelId],
    );
  }

  static Uri profileWebUri(String profileRef) {
    return Uri.https(webHost, webOpenPath, {'profile': profileRef});
  }

  static Uri profileAppUri(String profileRef) {
    return Uri(
      scheme: customScheme,
      host: 'profile',
      pathSegments: [profileRef],
    );
  }

  /// WhatsApp / SMS copy: store links + in-app deep link (no website URL).
  static String profileShareMessage({
    required String profileRef,
    String? username,
  }) {
    final handle = (username ?? '').trim().replaceAll('@', '');
    final headline = handle.isNotEmpty
        ? 'Check out @$handle on Vyooo'
        : 'Check out this profile on Vyooo';
    final appLink = profileAppUri(profileRef).toString();
    final lines = <String>[
      headline,
      '',
      'Get Vyooo:',
      'Android: $playStoreUrl',
      if (iosAppStoreUrl != null && iosAppStoreUrl!.isNotEmpty)
        'iPhone: $iosAppStoreUrl',
      '',
      'Open profile in Vyooo:',
      appLink,
    ];
    return lines.join('\n');
  }
}
