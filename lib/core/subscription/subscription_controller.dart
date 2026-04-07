import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'membership_tier.dart';
import 'subscription_service.dart';

/// Central subscription state. Use [currentTier] or the boolean getters to differentiate UI/features.
///
/// **How to differentiate by tier:**
/// - [currentTier] → MembershipTier.none | standard | subscriber | creator
/// - [planDisplayName] → "Free" | "Standard" | "Subscriber" | "Creator" (for labels)
/// - [hasAccess] → any paid plan (≠ none)
/// - [isStandard] / [isSubscriber] / [isCreator] → exact tier
/// - [hasVRAccess] → VR unlocked (Subscriber/Creator, or dev bypass)
/// - [canMonetize] / [canOfferSubscriptions] → Creator only
/// - [canUploadContent] / [hasVerification] → Subscriber or Creator
///
/// In widgets: `context.watch<SubscriptionController>()` or `context.read<SubscriptionController>()`.
class SubscriptionController extends ChangeNotifier {
  final SubscriptionService _service = SubscriptionService();

  static const String _keyDebugTier = 'debug_subscription_tier';

  MembershipTier currentTier = MembershipTier.none;
  MembershipTier? _testTierOverride;
  bool isLoading = false;
  String? purchaseError; // non-null if last purchase failed (not cancelled)

  /// In debug mode (or when [AppConfig.enableSubscriptionTierTesting]), load saved test tier and apply. Call after [init] in main().
  Future<void> loadTestTierOverride() async {
    if (!kDebugMode && !AppConfig.enableSubscriptionTierTesting) return;
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_keyDebugTier);
    if (name == null) return;
    final tier = _tierFromString(name);
    if (tier != null) {
      _testTierOverride = tier;
      currentTier = tier;
      notifyListeners();
    }
  }

  /// Set tier for testing (debug or when [AppConfig.enableSubscriptionTierTesting]). Persists so it survives app restart.
  Future<void> setTestTier(MembershipTier? tier) async {
    if (!kDebugMode && !AppConfig.enableSubscriptionTierTesting) return;
    _testTierOverride = tier;
    if (tier != null) {
      currentTier = tier;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDebugTier, tier.name);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyDebugTier);
      final info = await _service.getCustomerInfoSafe();
      currentTier = info != null ? _service.getTier(info) : MembershipTier.none;
    }
    notifyListeners();
  }

  static MembershipTier? _tierFromString(String name) {
    for (final t in MembershipTier.values) {
      if (t.name == name) return t;
    }
    return null;
  }

  Future<void> init(String publicKey) async {
    final ok = await _service.init(publicKey);
    if (!ok) {
      currentTier = MembershipTier.none;
      notifyListeners();
      return;
    }
    await refreshStatus();
  }

  /// Safe fetch for paywall; never throws.
  Future<Offerings?> fetchOfferings() async {
    return await _service.fetchOfferings();
  }

  Future<void> refreshStatus() async {
    if ((kDebugMode || AppConfig.enableSubscriptionTierTesting) &&
        _testTierOverride != null) {
      currentTier = _testTierOverride!;
      notifyListeners();
      return;
    }
    final info = await _service.getCustomerInfoSafe();
    currentTier = info != null ? _service.getTier(info) : MembershipTier.none;
    notifyListeners();
  }

  /// After Firebase Auth sign-in / sign-out, keep RevenueCat `appUserID` aligned.
  Future<void> syncPurchasesIdentity(String? firebaseUid) async {
    await _service.syncFirebaseUser(firebaseUid);
    await refreshStatus();
  }

  /// Returns true if purchase succeeded, false if user cancelled, throws on real error.
  Future<bool> purchase(Package package) async {
    purchaseError = null;
    isLoading = true;
    notifyListeners();
    try {
      await _service.purchase(package);
      await refreshStatus();
      return true;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return false; // user cancelled — silent
      }
      purchaseError = e.message ?? e.code;
      notifyListeners();
      rethrow;
    } catch (e) {
      purchaseError = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Keep these for backwards compatibility
  Future<void> purchaseStandard(Package package) async => purchase(package);
  Future<void> purchaseSubscriber(Package package) async => purchase(package);
  Future<void> purchaseCreator(Package package) async => purchase(package);

  Future<void> restorePurchases() async {
    try {
      await _service.restore();
      await refreshStatus();
    } catch (e) {
      if (kDebugMode) debugPrint('RevenueCat restore failed: $e');
    }
  }

  bool get hasAccess => currentTier != MembershipTier.none;
  bool get isStandard => currentTier == MembershipTier.standard;
  bool get isSubscriber => currentTier == MembershipTier.subscriber;
  bool get isCreator => currentTier == MembershipTier.creator;

  /// Human-readable plan name for UI (e.g. Account screen, settings).
  String get planDisplayName {
    switch (currentTier) {
      case MembershipTier.none:
        return 'Free';
      case MembershipTier.standard:
        return 'Standard';
      case MembershipTier.subscriber:
        return 'Subscriber';
      case MembershipTier.creator:
        return 'Creator';
    }
  }

  /// True if user has any paid plan (Standard, Subscriber, or Creator).
  bool get isPaid => currentTier != MembershipTier.none;

  /// True if user can monetize content (Creator only in typical setup).
  bool get canMonetize => isCreator;

  /// True if user can offer subscriptions to their audience (Creator only).
  bool get canOfferSubscriptions => isCreator;

  /// True if user can upload content (Subscriber & Creator).
  bool get canUploadContent => isSubscriber || isCreator;

  /// True if user has verification badge (Subscriber & Creator).
  bool get hasVerification => isSubscriber || isCreator;

  /// Standard → locked; Subscriber & Creator → unlocked.
  /// When [AppConfig.devBypassVRAccess] is true, always unlocked for testing.
  bool get hasVRAccess =>
      AppConfig.devBypassVRAccess || isSubscriber || isCreator;
}
