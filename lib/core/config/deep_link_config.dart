/// Centralized deep-link/share URL builder.
///
/// We intentionally use the website root with a query parameter to avoid
/// 404s on hosts that do not have server-side routing for `/reel/:id`.
class DeepLinkConfig {
  DeepLinkConfig._();

  static const String webHost = 'www.vyooo.com';
  static const String customScheme = 'vyooo';

  static Uri reelWebUri(String reelId) {
    return Uri.https(webHost, '/', {'reel': reelId});
  }

  static Uri reelAppUri(String reelId) {
    return Uri(
      scheme: customScheme,
      host: 'reel',
      pathSegments: [reelId],
    );
  }
}
