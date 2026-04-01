import 'package:cloud_firestore/cloud_firestore.dart';

/// A single story item (image + caption, expires in 24 h).
class StoryModel {
  const StoryModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.mediaUrl,
    required this.caption,
    required this.createdAt,
    required this.expiresAt,
    required this.viewedBy,
  });

  final String id;
  final String userId;
  final String username;
  final String avatarUrl;
  final String mediaUrl;
  final String caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> viewedBy;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool isViewedBy(String uid) => viewedBy.contains(uid);

  factory StoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return StoryModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      username: data['username'] as String? ?? '',
      avatarUrl: data['avatarUrl'] as String? ?? '',
      mediaUrl: data['mediaUrl'] as String? ?? '',
      caption: data['caption'] as String? ?? '',
      createdAt: createdAt,
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ??
          createdAt.add(const Duration(hours: 24)),
      viewedBy:
          List<String>.from(data['viewedBy'] as List<dynamic>? ?? <dynamic>[]),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'username': username,
        'avatarUrl': avatarUrl,
        'mediaUrl': mediaUrl,
        'caption': caption,
        'createdAt': Timestamp.fromDate(createdAt),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'viewedBy': viewedBy,
      };
}

/// All active stories for a single user.
class StoryGroup {
  const StoryGroup({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.stories,
  });

  final String userId;
  final String username;
  final String avatarUrl;
  final List<StoryModel> stories;

  bool hasUnviewedFor(String viewerUid) =>
      stories.any((s) => !s.isViewedBy(viewerUid));
}
