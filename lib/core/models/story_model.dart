import 'package:cloud_firestore/cloud_firestore.dart';

enum StoryMediaType { image, video }

/// A single story item (image or video + caption, expires in 24 h).
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
    this.mediaType = StoryMediaType.image,
    this.durationMs = 0,
    this.likes = 0,
    this.comments = 0,
    this.segmentGroupId = '',
    this.viewCount = 0,
    this.reportCount = 0,
    this.moderation,
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
  final StoryMediaType mediaType;
  /// Playback duration for video; 0 for image (viewer uses default image timing).
  final int durationMs;
  final int likes;
  final int comments;
  /// Same id across FFmpeg-split segments posted together.
  final String segmentGroupId;
  final int viewCount;
  final int reportCount;
  final Map<String, dynamic>? moderation;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool isViewedBy(String uid) => viewedBy.contains(uid);
  bool get isVideo => mediaType == StoryMediaType.video;

  factory StoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final rawType = (data['mediaType'] as String?)?.toLowerCase() ?? '';
    final mediaType = rawType == 'video'
        ? StoryMediaType.video
        : StoryMediaType.image;
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
      mediaType: mediaType,
      durationMs: (data['durationMs'] as num?)?.toInt() ?? 0,
      likes: (data['likes'] as num?)?.toInt() ?? 0,
      comments: (data['comments'] as num?)?.toInt() ?? 0,
      segmentGroupId: data['segmentGroupId'] as String? ?? '',
      viewCount: (data['viewCount'] as num?)?.toInt() ??
          ((data['viewedBy'] as List<dynamic>?)?.length ?? 0),
      reportCount: (data['reportCount'] as num?)?.toInt() ?? 0,
      moderation: data['moderation'] is Map
          ? Map<String, dynamic>.from(data['moderation'] as Map)
          : null,
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
        'mediaType': mediaType == StoryMediaType.video ? 'video' : 'image',
        'durationMs': durationMs,
        'likes': likes,
        'comments': comments,
        'segmentGroupId': segmentGroupId,
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
