import 'package:purchases_flutter/purchases_flutter.dart';

/// Maps RevenueCat [Offering] packages to Standard / Subscriber / Creator.
///
/// Uses App Store Connect product IDs first (store truth), then falls back to
/// RevenueCat package identifiers (e.g. `standard`, `subscriber`, `creator`).
class SubscriptionPackageMapper {
  SubscriptionPackageMapper._();

  /// [Offerings.current], or the `default` offering, or the first entry in [Offerings.all].
  ///
  /// Use this when [Offerings.current] is null but packages exist under `default` in RevenueCat.
  static Offering? resolveCurrentOffering(Offerings? offerings) {
    if (offerings == null) return null;
    if (offerings.current != null) return offerings.current;
    final def = offerings.getOffering('default');
    if (def != null) return def;
    if (offerings.all.isEmpty) return null;
    return offerings.all.values.first;
  }

  /// App Store subscription product IDs (App Store Connect → Subscriptions).
  static const String storeProductStandard = 'vyooo_standard_monthly';
  static const String storeProductSubscriber = 'subscriber_plan_month';
  static const String storeProductCreator = 'creator_plan_month';

  static SubscriptionPackages fromOffering(Offering? offering) {
    if (offering == null) {
      return const SubscriptionPackages();
    }
    return fromPackages(offering.availablePackages);
  }

  static SubscriptionPackages fromPackages(List<Package> packages) {
    Package? standard;
    Package? subscriber;
    Package? creator;

    for (final p in packages) {
      final storeId = p.storeProduct.identifier.toLowerCase();
      final pkgId = p.identifier.toLowerCase();

      if (_isStandard(storeId, pkgId)) {
        standard ??= p;
      } else if (_isSubscriber(storeId, pkgId)) {
        subscriber ??= p;
      } else if (_isCreator(storeId, pkgId)) {
        creator ??= p;
      }
    }

    return SubscriptionPackages(
      standard: standard,
      subscriber: subscriber,
      creator: creator,
    );
  }

  static bool _isStandard(String storeId, String pkgId) {
    return storeId == storeProductStandard ||
        pkgId.contains('standard') ||
        storeId.contains('standard');
  }

  static bool _isSubscriber(String storeId, String pkgId) {
    return storeId == storeProductSubscriber ||
        pkgId.contains('subscriber') ||
        storeId.contains('subscriber');
  }

  static bool _isCreator(String storeId, String pkgId) {
    return storeId == storeProductCreator ||
        pkgId.contains('creator') ||
        storeId.contains('creator');
  }
}

class SubscriptionPackages {
  const SubscriptionPackages({
    this.standard,
    this.subscriber,
    this.creator,
  });

  final Package? standard;
  final Package? subscriber;
  final Package? creator;
}
