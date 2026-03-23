import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatMessageType { text, join, like, system }

/// A single chat message in a live stream.
/// Subcollection: streams/{streamId}/messages/{msgId}
class LiveChatMessageModel {
  const LiveChatMessageModel({
    required this.id,
    required this.userId,
    required this.username,
    this.profileImage,
    required this.message,
    required this.type,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String username;
  final String? profileImage;
  final String message;
  final ChatMessageType type;
  final Timestamp createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'username': username,
        'profileImage': profileImage ?? '',
        'message': message,
        'type': type.name,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory LiveChatMessageModel.fromJson(String id, Map<String, dynamic> json) {
    return LiveChatMessageModel(
      id: id,
      userId: json['userId'] as String? ?? '',
      username: json['username'] as String? ?? 'User',
      profileImage: json['profileImage'] as String?,
      message: json['message'] as String? ?? '',
      type: ChatMessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ChatMessageType.text,
      ),
      createdAt: json['createdAt'] is Timestamp ? json['createdAt'] as Timestamp : Timestamp.now(),
    );
  }
}
