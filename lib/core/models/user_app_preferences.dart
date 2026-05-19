import 'package:cloud_firestore/cloud_firestore.dart';

/// Privacy & app behaviour stored at `users/{uid}/settings/app`.
class UserAppPreferences {
  const UserAppPreferences({
    this.autoArchiveStories = true,
    this.saveStoryToArchive = false,
    this.showActivityStatus = true,
    this.allowSharingLikesToFeed = false,
    this.saveSearchHistory = true,
    this.messageRequests = AudienceOption.everyone,
    this.storyReplies = AudienceOption.followers,
    this.allowTagsFrom = AudienceOption.everyone,
    this.allowCommentsFrom = AudienceOption.everyone,
    this.filterOffensiveComments = true,
    this.allowStoryReshare = true,
    this.allowReelsRemix = true,
    this.closeFriendIds = const [],
  });

  static const String firestoreDocId = 'app';
  static const String collectionName = 'settings';

  final bool autoArchiveStories;
  final bool saveStoryToArchive;
  final bool showActivityStatus;
  final bool allowSharingLikesToFeed;
  final bool saveSearchHistory;
  final String messageRequests;
  final String storyReplies;
  final String allowTagsFrom;
  final String allowCommentsFrom;
  final bool filterOffensiveComments;
  final bool allowStoryReshare;
  final bool allowReelsRemix;
  final List<String> closeFriendIds;

  static UserAppPreferences fromMap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return const UserAppPreferences();
    }
    return UserAppPreferences(
      autoArchiveStories: _bool(data['autoArchiveStories'], true),
      saveStoryToArchive: _bool(data['saveStoryToArchive'], false),
      showActivityStatus: _bool(data['showActivityStatus'], true),
      allowSharingLikesToFeed: _bool(data['allowSharingLikesToFeed'], false),
      saveSearchHistory: _bool(data['saveSearchHistory'], true),
      messageRequests: AudienceOption.sanitize(data['messageRequests']),
      storyReplies: AudienceOption.sanitize(data['storyReplies']),
      allowTagsFrom: AudienceOption.sanitize(data['allowTagsFrom']),
      allowCommentsFrom: AudienceOption.sanitize(data['allowCommentsFrom']),
      filterOffensiveComments: _bool(data['filterOffensiveComments'], true),
      allowStoryReshare: _bool(data['allowStoryReshare'], true),
      allowReelsRemix: _bool(data['allowReelsRemix'], true),
      closeFriendIds: _stringList(data['closeFriendIds']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'autoArchiveStories': autoArchiveStories,
      'saveStoryToArchive': saveStoryToArchive,
      'showActivityStatus': showActivityStatus,
      'allowSharingLikesToFeed': allowSharingLikesToFeed,
      'saveSearchHistory': saveSearchHistory,
      'messageRequests': messageRequests,
      'storyReplies': storyReplies,
      'allowTagsFrom': allowTagsFrom,
      'allowCommentsFrom': allowCommentsFrom,
      'filterOffensiveComments': filterOffensiveComments,
      'allowStoryReshare': allowStoryReshare,
      'allowReelsRemix': allowReelsRemix,
      'closeFriendIds': closeFriendIds,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserAppPreferences copyWith({
    bool? autoArchiveStories,
    bool? saveStoryToArchive,
    bool? showActivityStatus,
    bool? allowSharingLikesToFeed,
    bool? saveSearchHistory,
    String? messageRequests,
    String? storyReplies,
    String? allowTagsFrom,
    String? allowCommentsFrom,
    bool? filterOffensiveComments,
    bool? allowStoryReshare,
    bool? allowReelsRemix,
    List<String>? closeFriendIds,
  }) {
    return UserAppPreferences(
      autoArchiveStories: autoArchiveStories ?? this.autoArchiveStories,
      saveStoryToArchive: saveStoryToArchive ?? this.saveStoryToArchive,
      showActivityStatus: showActivityStatus ?? this.showActivityStatus,
      allowSharingLikesToFeed:
          allowSharingLikesToFeed ?? this.allowSharingLikesToFeed,
      saveSearchHistory: saveSearchHistory ?? this.saveSearchHistory,
      messageRequests: messageRequests ?? this.messageRequests,
      storyReplies: storyReplies ?? this.storyReplies,
      allowTagsFrom: allowTagsFrom ?? this.allowTagsFrom,
      allowCommentsFrom: allowCommentsFrom ?? this.allowCommentsFrom,
      filterOffensiveComments:
          filterOffensiveComments ?? this.filterOffensiveComments,
      allowStoryReshare: allowStoryReshare ?? this.allowStoryReshare,
      allowReelsRemix: allowReelsRemix ?? this.allowReelsRemix,
      closeFriendIds: closeFriendIds ?? this.closeFriendIds,
    );
  }

  static bool _bool(dynamic value, bool fallback) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final t = value.trim().toLowerCase();
      if (t == 'true' || t == '1') return true;
      if (t == 'false' || t == '0') return false;
    }
    return fallback;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .take(50)
        .toList();
  }
}

/// `everyone` | `followers` | `nobody`
abstract final class AudienceOption {
  AudienceOption._();

  static const everyone = 'everyone';
  static const followers = 'followers';
  static const nobody = 'nobody';

  static const labels = <String, String>{
    everyone: 'Everyone',
    followers: 'People you follow',
    nobody: 'No one',
  };

  static const values = [everyone, followers, nobody];

  static String sanitize(dynamic raw, {String fallback = everyone}) {
    final v = raw?.toString().trim().toLowerCase() ?? '';
    if (values.contains(v)) return v;
    return fallback;
  }
}
