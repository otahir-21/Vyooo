import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'membership_tier.dart';

/// Wraps RevenueCat SDK: configure, offerings, purchase, restore, entitlement → tier.
class SubscriptionService {
  /// Returns false if [Purchases.configure] failed. App can still run at tier [none].
  Future<bool> init(String publicKey) async {
    await Purchases.setLogLevel(kDebugMode ? LogLevel.warn : LogLevel.error);
    try {
      await Purchases.configure(
        PurchasesConfiguration(publicKey),
      );
      return true;
    } catch (e, st) {
      debugPrint('RevenueCat configure failed: $e');
      if (kDebugMode) debugPrint('$st');
      return false;
    }
  }

  /// Safe fetch: never throws. Returns null if offerings unavailable.
  Future<Offerings?> fetchOfferings() async {
    try {
      if (!await Purchases.isConfigured) return null;
      final offerings = await Purchases.getOfferings();
      return offerings;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RevenueCat offerings unavailable: $e');
      }
      return null;
    }
  }

  @Deprecated('Use fetchOfferings() for safe null return')
  Future<Offerings> getOfferings() async {
    return await Purchases.getOfferings();
  }

  Future<CustomerInfo?> getCustomerInfoSafe() async {
    try {
      if (!await Purchases.isConfigured) return null;
      return await Purchases.getCustomerInfo();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RevenueCat getCustomerInfo failed: $e');
      }
      return null;
    }
  }

  Future<void> purchase(Package package) async {
    await Purchases.purchasePackage(package);
  }

  Future<void> restore() async {
    if (!await Purchases.isConfigured) return;
    await Purchases.restorePurchases();
  }

  /// Binds RevenueCat customer to Firebase [uid] (restore purchases across devices, webhooks).
  /// Call with `null` after sign-out.
  Future<void> syncFirebaseUser(String? firebaseUid) async {
    if (!await Purchases.isConfigured) return;
    try {
      if (firebaseUid == null || firebaseUid.isEmpty) {
        await Purchases.logOut();
      } else {
        await Purchases.logIn(firebaseUid);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RevenueCat syncFirebaseUser failed: $e');
      }
    }
  }

  MembershipTier getTier(CustomerInfo info) {
    final entitlementIds = info.entitlements.active.keys
        .map((e) => e.trim().toLowerCase())
        .toSet();
    final activeProductIds = info.activeSubscriptions
        .map((e) => e.trim().toLowerCase())
        .toSet();

    bool hasAny(Iterable<String> values, List<String> candidates) {
      for (final c in candidates) {
        if (values.contains(c)) return true;
      }
      return false;
    }

    if (hasAny(entitlementIds, const ['creator_access']) ||
        entitlementIds.any((id) => id.contains('creator')) ||
        activeProductIds.any((id) => id.contains('creator'))) {
      return MembershipTier.creator;
    }
    if (hasAny(entitlementIds, const ['subscriber_access']) ||
        entitlementIds.any((id) => id.contains('subscriber')) ||
        activeProductIds.any((id) => id.contains('subscriber'))) {
      return MembershipTier.subscriber;
    }
    if (hasAny(entitlementIds, const ['standard_access']) ||
        entitlementIds.any((id) => id.contains('standard')) ||
        activeProductIds.any((id) => id.contains('standard'))) {
      return MembershipTier.standard;
    }
    return MembershipTier.none;
  }
}
