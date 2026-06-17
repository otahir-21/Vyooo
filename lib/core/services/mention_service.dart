import 'package:flutter/foundation.dart';

import '../models/user_app_preferences.dart';
import '../utils/mention_utils.dart';
import 'comment_diagnostics.dart';
import 'notification_service.dart';
import 'user_service.dart';

/// Resolves `@username` tokens and sends mention notifications.
class MentionService {
  MentionService._();
  static final MentionService _instance = MentionService._();
  factory MentionService() => _instance;

  final UserService _users = UserService();

  /// Resolves handles in [text] to user ids the [taggerUid] is allowed to tag.
  Future<List<String>> resolveMentionedUserIds({
    required String text,
    required String taggerUid,
  }) async {
    if (taggerUid.isEmpty) return const [];
    final handles = MentionUtils.extractMentionUsernames(text);
    if (handles.isEmpty) return const [];

    final ids = <String>[];
    final seen = <String>{};
    for (final handle in handles) {
      final user = await _users.getUserByUsername(handle);
      final uid = user?.uid.trim() ?? '';
      if (uid.isEmpty) {
        if (kDebugMode) {
          CommentDiagnostics.log('Mention @$handle not resolved to a user');
        }
        continue;
      }
      if (uid == taggerUid || seen.contains(uid)) continue;
      if (!await _canTagUser(taggerUid: taggerUid, targetUid: uid)) {
        if (kDebugMode) {
          CommentDiagnostics.log('Mention @$handle blocked by tag privacy');
        }
        continue;
      }
      seen.add(uid);
      ids.add(uid);
    }
    return ids;
  }

  Future<bool> _canTagUser({
    required String taggerUid,
    required String targetUid,
  }) async {
    if (taggerUid.isEmpty || targetUid.isEmpty) return false;
    final target = await _users.getUser(targetUid);
    if (target == null) return false;
    switch (target.allowTagsFrom) {
      case AudienceOption.nobody:
        return false;
      case AudienceOption.everyone:
        return true;
      case AudienceOption.followers:
        final targetFollowing = await _users.getFollowing(targetUid);
        return targetFollowing.contains(taggerUid);
      default:
        return true;
    }
  }

  /// Notifies mentioned users, skipping ids in [skipRecipientIds].
  Future<void> notifyMentionedUsers({
    required String text,
    required String taggerUid,
    required String displayComment,
    required Map<String, dynamic> extra,
    Set<String> skipRecipientIds = const {},
  }) async {
    if (taggerUid.isEmpty) return;
    final mentioned = await resolveMentionedUserIds(
      text: text,
      taggerUid: taggerUid,
    );
    if (mentioned.isEmpty) return;

    for (final recipientId in mentioned) {
      if (skipRecipientIds.contains(recipientId)) continue;
      await NotificationService().create(
        recipientId: recipientId,
        type: AppNotificationType.mention,
        message: 'mentioned you in a comment: "$displayComment"',
        extra: extra,
      );
    }
  }
}
