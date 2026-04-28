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
  static const String _keyTrustedLoginUids = 'trusted_login_uids';
  static const String _keySignupOtpChannel = 'signup_otp_channel';
  static const String _keySignupOtpDestination = 'signup_otp_destination';

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

  Future<bool> isTrustedDeviceForUid(String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final trusted = prefs.getStringList(_keyTrustedLoginUids) ?? const <String>[];
    return trusted.contains(normalizedUid);
  }

  Future<void> markTrustedDeviceForUid(String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final trusted = prefs.getStringList(_keyTrustedLoginUids) ?? const <String>[];
    if (trusted.contains(normalizedUid)) return;
    final updated = List<String>.from(trusted)..add(normalizedUid);
    await prefs.setStringList(_keyTrustedLoginUids, updated);
    _bumpRevision();
  }

  Future<void> setSignupOtpPreference({
    required String channel,
    required String destination,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySignupOtpChannel, channel.trim().toLowerCase());
    await prefs.setString(_keySignupOtpDestination, destination.trim());
    _bumpRevision();
  }

  Future<(String channel, String destination)> getSignupOtpPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final channel = (prefs.getString(_keySignupOtpChannel) ?? 'email')
        .trim()
        .toLowerCase();
    final destination = (prefs.getString(_keySignupOtpDestination) ?? '').trim();
    return (channel, destination);
  }

  Future<void> clearSignupOtpPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySignupOtpChannel);
    await prefs.remove(_keySignupOtpDestination);
    _bumpRevision();
  }
}
