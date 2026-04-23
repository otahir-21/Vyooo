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
  static const String _keyCachedTierPrefix = 'cached_subscription_tier_';
  static const String _keyCachedPaidPrefix = 'cached_subscription_paid_';
  static const String _keyCachedSyncedAtPrefix = 'cached_subscription_synced_at_';

  MembershipTier currentTier = MembershipTier.none;
  MembershipTier? _testTierOverride;
  bool _hasAnyStoreSubscription = false;
  bool _hasResolvedStatusOnce = false;
  String? _activeFirebaseUid;
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

  Future<void> _loadCachedStatusForUid(String uid) async {
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final tierName = prefs.getString('$_keyCachedTierPrefix$uid');
    final cachedPaid = prefs.getBool('$_keyCachedPaidPrefix$uid');
    final syncedAtMs = prefs.getInt('$_keyCachedSyncedAtPrefix$uid');
    final tier = tierName == null ? null : _tierFromString(tierName);
    if (tier == null && cachedPaid == null) return;
    currentTier = tier ?? MembershipTier.none;
    _hasAnyStoreSubscription = cachedPaid ?? (currentTier != MembershipTier.none);
    _hasResolvedStatusOnce = true;
    if (kDebugMode && syncedAtMs != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final diffMs = (now - syncedAtMs).clamp(0, 1 << 31);
      final mins = diffMs ~/ 60000;
      debugPrint(
        'Subscription cache hit for $uid: tier=${currentTier.name}, paid=$_hasAnyStoreSubscription, last synced ${mins}m ago',
      );
    }
  }

  Future<void> _persistCurrentStatusForActiveUid() async {
    final uid = _activeFirebaseUid;
    if (uid == null || uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyCachedTierPrefix$uid', currentTier.name);
    await prefs.setBool('$_keyCachedPaidPrefix$uid', _hasAnyStoreSubscription);
    await prefs.setInt(
      '$_keyCachedSyncedAtPrefix$uid',
      DateTime.now().millisecondsSinceEpoch,
    );
    if (kDebugMode) {
      debugPrint(
        'Subscription cache updated for $uid: tier=${currentTier.name}, paid=$_hasAnyStoreSubscription',
      );
    }
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
      _hasAnyStoreSubscription = currentTier != MembershipTier.none;
      notifyListeners();
      return;
    }
    final info = await _service.getCustomerInfoSafe();
    if (info == null) {
      // Do not downgrade on transient SDK/network failures after we already
      // resolved a real status once in this session.
      if (!_hasResolvedStatusOnce) {
        currentTier = MembershipTier.none;
        _hasAnyStoreSubscription = false;
      }
    } else {
      currentTier = _service.getTier(info);
      _hasAnyStoreSubscription =
          info.entitlements.active.isNotEmpty || info.activeSubscriptions.isNotEmpty;
      _hasResolvedStatusOnce = true;
      await _persistCurrentStatusForActiveUid();
    }
    notifyListeners();
  }

  /// Strong status reconciliation for cases where sandbox entitlement sync lags.
  /// Returns true when an active paid subscription is detected after recovery.
  Future<bool> reconcilePaidStatus({String? firebaseUid}) async {
    // Ensure RevenueCat identity matches Firebase before checking status.
    if (firebaseUid != null && firebaseUid.isNotEmpty) {
      await _service.syncFirebaseUser(firebaseUid);
    }
    await refreshStatus();
    if (isPaid) return true;

    // Recovery path: restore, then refresh again.
    await restorePurchases();
    await refreshStatus();
    return isPaid;
  }

  /// After Firebase Auth sign-in / sign-out, keep RevenueCat `appUserID` aligned.
  Future<void> syncPurchasesIdentity(String? firebaseUid) async {
    // On account changes, show last known status immediately for this user.
    if (firebaseUid != _activeFirebaseUid) {
      _activeFirebaseUid = firebaseUid;
      if (firebaseUid == null || firebaseUid.isEmpty) {
        currentTier = MembershipTier.none;
        _hasAnyStoreSubscription = false;
        _hasResolvedStatusOnce = false;
      } else {
        await _loadCachedStatusForUid(firebaseUid);
      }
      notifyListeners();
    }
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
      if (code == PurchasesErrorCode.productAlreadyPurchasedError) {
        // Common on sandbox/test devices when the subscription is already active.
        await refreshStatus();
        return true;
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
  bool get isPaid => currentTier != MembershipTier.none || _hasAnyStoreSubscription;

  /// True if user can monetize content (Creator only in typical setup).
  bool get canMonetize => isCreator;

  /// True if user can offer subscriptions to their audience (Creator only).
  bool get canOfferSubscriptions => isCreator;

  /// True if user can upload content (Subscriber & Creator).
  ///
  /// Business update: any active paid plan should unlock upload access.
  bool get canUploadContent => isPaid;

  /// True if user has verification badge (Subscriber & Creator).
  bool get hasVerification => isSubscriber || isCreator;

  /// Standard → locked; Subscriber & Creator → unlocked.
  /// When [AppConfig.devBypassVRAccess] is true, always unlocked for testing.
  bool get hasVRAccess =>
      AppConfig.devBypassVRAccess || isSubscriber || isCreator;
}
