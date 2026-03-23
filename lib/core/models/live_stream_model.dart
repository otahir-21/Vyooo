import 'package:cloud_firestore/cloud_firestore.dart';

enum LiveStreamStatus { live, ended }

/// Firestore document model for a live stream.
/// Collection: streams/{streamId}
class LiveStreamModel {
  const LiveStreamModel({
    required this.id,
    required this.hostId,
    required this.hostUsername,
    this.hostProfileImage,
    required this.title,
    this.description = '',
    this.category = '',
    this.tags = const [],
    this.pricePerMinute = 0,
    required this.status,
    this.viewerCount = 0,
    this.likeCount = 0,
    required this.agoraChannelName,
    this.hostAgoraUid = 0,
    required this.createdAt,
    this.endedAt,
    this.savedToProfile = false,
  });

  final String id;
  final String hostId;
  final String hostUsername;
  final String? hostProfileImage;
  final String title;
  final String description;
  final String category;
  final List<String> tags;
  final int pricePerMinute;
  final LiveStreamStatus status;
  final int viewerCount;
  final int likeCount;

  /// Agora channel name — equals the Firestore document ID.
  final String agoraChannelName;

  /// Agora UID assigned to the host after joining the channel.
  final int hostAgoraUid;

  final Timestamp createdAt;
  final Timestamp? endedAt;
  final bool savedToProfile;

  bool get isLive => status == LiveStreamStatus.live;

  Map<String, dynamic> toJson() => {
        'id': id,
        'hostId': hostId,
        'hostUsername': hostUsername,
        'hostProfileImage': hostProfileImage ?? '',
        'title': title,
        'description': description,
        'category': category,
        'tags': tags,
        'pricePerMinute': pricePerMinute,
        'status': status.name,
        'viewerCount': viewerCount,
        'likeCount': likeCount,
        'agoraChannelName': agoraChannelName,
        'hostAgoraUid': hostAgoraUid,
        'createdAt': createdAt,
        'endedAt': endedAt,
        'savedToProfile': savedToProfile,
      };

  factory LiveStreamModel.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    final tagsList = rawTags is List ? rawTags.map((e) => e.toString()).toList() : <String>[];
    return LiveStreamModel(
      id: json['id'] as String? ?? '',
      hostId: json['hostId'] as String? ?? '',
      hostUsername: json['hostUsername'] as String? ?? 'Unknown',
      hostProfileImage: json['hostProfileImage'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      tags: tagsList,
      pricePerMinute: (json['pricePerMinute'] as num?)?.toInt() ?? 0,
      status: LiveStreamStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => LiveStreamStatus.ended,
      ),
      viewerCount: (json['viewerCount'] as num?)?.toInt() ?? 0,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      agoraChannelName: json['agoraChannelName'] as String? ?? '',
      hostAgoraUid: (json['hostAgoraUid'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] is Timestamp ? json['createdAt'] as Timestamp : Timestamp.now(),
      endedAt: json['endedAt'] is Timestamp ? json['endedAt'] as Timestamp : null,
      savedToProfile: json['savedToProfile'] as bool? ?? false,
    );
  }

  LiveStreamModel copyWith({
    int? viewerCount,
    int? likeCount,
    int? hostAgoraUid,
    LiveStreamStatus? status,
    Timestamp? endedAt,
    bool? savedToProfile,
  }) {
    return LiveStreamModel(
      id: id,
      hostId: hostId,
      hostUsername: hostUsername,
      hostProfileImage: hostProfileImage,
      title: title,
      description: description,
      category: category,
      tags: tags,
      pricePerMinute: pricePerMinute,
      status: status ?? this.status,
      viewerCount: viewerCount ?? this.viewerCount,
      likeCount: likeCount ?? this.likeCount,
      agoraChannelName: agoraChannelName,
      hostAgoraUid: hostAgoraUid ?? this.hostAgoraUid,
      createdAt: createdAt,
      endedAt: endedAt ?? this.endedAt,
      savedToProfile: savedToProfile ?? this.savedToProfile,
    );
  }
}
