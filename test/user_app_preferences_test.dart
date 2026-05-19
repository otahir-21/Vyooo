import 'package:flutter_test/flutter_test.dart';
import 'package:vyooo/core/models/user_app_preferences.dart';

void main() {
  test('fromMap uses defaults for empty doc', () {
    const prefs = UserAppPreferences();
    expect(UserAppPreferences.fromMap(null), prefs);
  });

  test('round-trip map preserves audience fields', () {
    const prefs = UserAppPreferences(
      messageRequests: AudienceOption.followers,
      allowCommentsFrom: AudienceOption.nobody,
      closeFriendIds: ['uid_a', 'uid_b'],
    );
    final restored = UserAppPreferences.fromMap({
      'messageRequests': prefs.messageRequests,
      'allowCommentsFrom': prefs.allowCommentsFrom,
      'closeFriendIds': prefs.closeFriendIds,
    });
    expect(restored.messageRequests, AudienceOption.followers);
    expect(restored.allowCommentsFrom, AudienceOption.nobody);
    expect(restored.closeFriendIds, ['uid_a', 'uid_b']);
  });
}
