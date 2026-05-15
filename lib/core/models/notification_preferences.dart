import 'package:cloud_firestore/cloud_firestore.dart';

/// User-controlled push/in-app notification categories.
/// Stored at `users/{uid}/settings/notifications`.
class NotificationPreferences {
  const NotificationPreferences({
    this.pushEnabled = true,
    this.activity = true,
    this.postsFromFollowing = true,
    this.live = true,
    this.subscriptions = false,
    this.recommended = false,
  });

  final bool pushEnabled;
  final bool activity;
  final bool postsFromFollowing;
  final bool live;
  final bool subscriptions;
  final bool recommended;

  static const String firestoreDocId = 'notifications';
  static const String collectionName = 'settings';

  static NotificationPreferences fromMap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return const NotificationPreferences();
    }
    return NotificationPreferences(
      pushEnabled: _readBool(data['pushEnabled'], fallback: true),
      activity: _readBool(data['activity'], fallback: true),
      postsFromFollowing: _readBool(data['postsFromFollowing'], fallback: true),
      live: _readBool(data['live'], fallback: true),
      subscriptions: _readBool(data['subscriptions'], fallback: false),
      recommended: _readBool(data['recommended'], fallback: false),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pushEnabled': pushEnabled,
      'activity': activity,
      'postsFromFollowing': postsFromFollowing,
      'live': live,
      'subscriptions': subscriptions,
      'recommended': recommended,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? activity,
    bool? postsFromFollowing,
    bool? live,
    bool? subscriptions,
    bool? recommended,
  }) {
    return NotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      activity: activity ?? this.activity,
      postsFromFollowing: postsFromFollowing ?? this.postsFromFollowing,
      live: live ?? this.live,
      subscriptions: subscriptions ?? this.subscriptions,
      recommended: recommended ?? this.recommended,
    );
  }

  /// Whether a Firestore notification [type] should surface as push/in-app alert.
  bool allowsCategoryForType(String rawType) {
    if (!pushEnabled) return false;
    final type = rawType.trim().toLowerCase();
    if (type.isEmpty) return activity;

    const activityTypes = {
      'like',
      'comment',
      'share',
      'follow',
      'followrequest',
      'follow_request',
      'followrequestaccepted',
      'follow_request_accepted',
    };
    if (activityTypes.contains(type)) return activity;

    if (type == 'subscribe' || type == 'subscription') return subscriptions;

    const postTypes = {'post', 'new_post', 'newpost'};
    if (postTypes.contains(type)) return postsFromFollowing;

    const liveTypes = {'live', 'live_start', 'livestream', 'live_stream'};
    if (liveTypes.contains(type)) return live;

    const recommendedTypes = {
      'recommended',
      'recommended_content',
      'marketing',
    };
    if (recommendedTypes.contains(type)) return recommended;

    return activity;
  }

  static bool _readBool(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final t = value.trim().toLowerCase();
      if (t == 'true' || t == '1') return true;
      if (t == 'false' || t == '0') return false;
    }
    return fallback;
  }
}
