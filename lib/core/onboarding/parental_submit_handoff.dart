import 'package:flutter/foundation.dart';

/// After [ParentalConsentService.createPendingRequest] succeeds, the user doc
/// updates atomically in Firestore but the client `snapshots()` stream can lag.
/// This stores the new consent id so [OnboardingGate] can show [ParentalPendingScreen]
/// immediately; it is cleared once the user stream matches or the user leaves the flow.
class ParentalSubmitHandoff extends ChangeNotifier {
  ParentalSubmitHandoff._();
  static final ParentalSubmitHandoff instance = ParentalSubmitHandoff._();

  String? _minorUid;
  String? _consentId;
  DateTime? _expiresAt;

  /// Server-confirmed consent id for [minorUid], or null if none / expired.
  String? activeConsentIdForMinor(String minorUid) {
    if (_minorUid != minorUid || _consentId == null || _expiresAt == null) {
      return null;
    }
    if (DateTime.now().isAfter(_expiresAt!)) {
      disarm(minorUid: minorUid);
      return null;
    }
    return _consentId;
  }

  void arm({
    required String minorUid,
    required String consentId,
    Duration ttl = const Duration(minutes: 5),
  }) {
    _minorUid = minorUid;
    _consentId = consentId;
    _expiresAt = DateTime.now().add(ttl);
    notifyListeners();
  }

  /// Clears handoff for [minorUid], or everything if [minorUid] is null.
  void disarm({String? minorUid}) {
    final had = _consentId != null;
    if (minorUid != null && _minorUid != minorUid) return;
    _minorUid = null;
    _consentId = null;
    _expiresAt = null;
    if (had) notifyListeners();
  }
}
