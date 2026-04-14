import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the current signed-in password user must complete
/// login OTP before accessing the app.
class OtpSessionService {
  OtpSessionService._();
  static final OtpSessionService _instance = OtpSessionService._();
  factory OtpSessionService() => _instance;

  static const String _keyOtpPending = 'login_otp_pending';
  static const String _keyOtpPendingUid = 'login_otp_pending_uid';

  /// Bumps after prefs change so [AuthWrapper] re-runs the OTP gate (avoids a race with login).
  static final ValueNotifier<int> sessionRevision = ValueNotifier(0);

  /// True while email login is in progress (after submit until session OTP prefs are written).
  /// Stops [AuthWrapper] from building [MainNavWrapper] underneath the sign-in sheet.
  bool emailLoginHandshakeActive = false;

  static void _bumpRevision() {
    sessionRevision.value = sessionRevision.value + 1;
  }

  /// Call when user taps Login (email path) before awaiting sign-in.
  void startEmailLoginHandshake() {
    emailLoginHandshakeActive = true;
    _bumpRevision();
  }

  /// Call when email/password sign-in or OTP send fails.
  void abortEmailLoginHandshake() {
    emailLoginHandshakeActive = false;
    _bumpRevision();
  }

  Future<void> requireOtpForUid(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOtpPending, true);
    await prefs.setString(_keyOtpPendingUid, uid);
    emailLoginHandshakeActive = false;
    _bumpRevision();
  }

  Future<bool> isOtpRequiredForUid(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool(_keyOtpPending) ?? false;
    final pendingUid = prefs.getString(_keyOtpPendingUid) ?? '';
    return pending && pendingUid == uid;
  }

  Future<void> clearOtpRequirement() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOtpPending);
    await prefs.remove(_keyOtpPendingUid);
    emailLoginHandshakeActive = false;
    _bumpRevision();
  }
}
