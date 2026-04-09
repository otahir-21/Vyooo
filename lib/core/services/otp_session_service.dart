import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the current signed-in password user must complete
/// login OTP before accessing the app.
class OtpSessionService {
  OtpSessionService._();
  static final OtpSessionService _instance = OtpSessionService._();
  factory OtpSessionService() => _instance;

  static const String _keyOtpPending = 'login_otp_pending';
  static const String _keyOtpPendingUid = 'login_otp_pending_uid';

  Future<void> requireOtpForUid(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOtpPending, true);
    await prefs.setString(_keyOtpPendingUid, uid);
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
  }
}
