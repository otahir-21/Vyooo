import 'package:cloud_firestore/cloud_firestore.dart';

class ChatSummaryModel {
  const ChatSummaryModel({
    required this.chatId,
    this.type = 'direct',
    this.title = '',
    this.avatarUrl = '',
    this.participantIds = const [],
    this.lastMessage = '',
    this.lastMessageAt,
    this.lastMessageSenderId = '',
    this.unreadCount = 0,
    this.muted = false,
    this.pinned = false,
    this.archived = false,
    this.clearedAt,
    this.requestStatus,
  });

  final String chatId;
  final String type;
  final String title;
  final String avatarUrl;
  final List<String> participantIds;
  final String lastMessage;
  final Timestamp? lastMessageAt;
  final String lastMessageSenderId;
  final int unreadCount;
  final bool muted;
  final bool pinned;
  final bool archived;
  final Timestamp? clearedAt;
  final String? requestStatus;

  factory ChatSummaryModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final json = doc.data() ?? {};
    return ChatSummaryModel.fromJson(json, chatId: doc.id);
  }

  factory ChatSummaryModel.fromJson(
    Map<String, dynamic> json, {
    String? chatId,
  }) {
    return ChatSummaryModel(
      chatId: chatId ?? json['chatId'] as String? ?? '',
      type: json['type'] as String? ?? 'direct',
      title: json['title'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      participantIds: _toStringList(json['participantIds']),
      lastMessage: json['lastMessage'] as String? ?? '',
      lastMessageAt: json['lastMessageAt'] as Timestamp?,
      lastMessageSenderId: json['lastMessageSenderId'] as String? ?? '',
      unreadCount: json['unreadCount'] as int? ?? 0,
      muted: json['muted'] as bool? ?? false,
      pinned: json['pinned'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      clearedAt: json['clearedAt'] as Timestamp?,
      requestStatus: json['requestStatus'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chatId': chatId,
      'type': type,
      'title': title,
      'avatarUrl': avatarUrl,
      'participantIds': participantIds,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt,
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCount': unreadCount,
      'muted': muted,
      'pinned': pinned,
      'archived': archived,
      if (clearedAt != null) 'clearedAt': clearedAt,
      if (requestStatus != null) 'requestStatus': requestStatus,
    };
  }

  ChatSummaryModel copyWith({
    String? chatId,
    String? type,
    String? title,
    String? avatarUrl,
    List<String>? participantIds,
    String? lastMessage,
    Timestamp? lastMessageAt,
    String? lastMessageSenderId,
    int? unreadCount,
    bool? muted,
    bool? pinned,
    bool? archived,
    Timestamp? clearedAt,
    String? requestStatus,
  }) {
    return ChatSummaryModel(
      chatId: chatId ?? this.chatId,
      type: type ?? this.type,
      title: title ?? this.title,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      participantIds: participantIds ?? this.participantIds,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      unreadCount: unreadCount ?? this.unreadCount,
      muted: muted ?? this.muted,
      pinned: pinned ?? this.pinned,
      archived: archived ?? this.archived,
      clearedAt: clearedAt ?? this.clearedAt,
      requestStatus: requestStatus ?? this.requestStatus,
    );
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) return value.whereType<String>().toList();
    return [];
  }
}