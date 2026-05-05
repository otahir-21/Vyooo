import 'package:cloud_firestore/cloud_firestore.dart';

import 'chat_participant.dart';

class ChatModel {
  const ChatModel({
    required this.id,
    this.type = 'direct',
    this.participantIds = const [],
    this.participantMap = const {},
    this.createdBy = '',
    this.createdAt,
    this.updatedAt,
    this.lastMessage = '',
    this.lastMessageAt,
    this.lastMessageSenderId = '',
    this.lastMessageType = 'text',
    this.mutedBy = const [],
    this.clearedAtBy = const {},
    this.deletedFor = const [],
    this.groupName,
    this.groupImageUrl,
    this.admins = const [],
    this.requestStatus = const {},
  });

  final String id;
  final String type;
  final List<String> participantIds;
  final Map<String, ChatParticipant> participantMap;
  final String createdBy;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final String lastMessage;
  final Timestamp? lastMessageAt;
  final String lastMessageSenderId;
  final String lastMessageType;
  final List<String> mutedBy;
  final Map<String, Timestamp> clearedAtBy;
  final List<String> deletedFor;
  final String? groupName;
  final String? groupImageUrl;
  final List<String> admins;
  final Map<String, String> requestStatus;

  factory ChatModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? {};
    return ChatModel.fromJson(json, id: doc.id);
  }

  factory ChatModel.fromJson(Map<String, dynamic> json, {String? id}) {
    final rawParticipantMap = json['participantMap'];
    final participantMap = <String, ChatParticipant>{};
    if (rawParticipantMap is Map) {
      for (final entry in rawParticipantMap.entries) {
        final key = entry.key.toString();
        if (entry.value is Map) {
          participantMap[key] =
              ChatParticipant.fromJson(Map<String, dynamic>.from(entry.value as Map));
        }
      }
    }

    final rawClearedAt = json['clearedAtBy'];
    final clearedAtBy = <String, Timestamp>{};
    if (rawClearedAt is Map) {
      for (final entry in rawClearedAt.entries) {
        if (entry.value is Timestamp) {
          clearedAtBy[entry.key.toString()] = entry.value as Timestamp;
        }
      }
    }

    final rawRequest = json['requestStatus'];
    final requestStatus = <String, String>{};
    if (rawRequest is Map) {
      for (final entry in rawRequest.entries) {
        requestStatus[entry.key.toString()] = entry.value.toString();
      }
    }

    return ChatModel(
      id: id ?? json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'direct',
      participantIds: _toStringList(json['participantIds']),
      participantMap: participantMap,
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: json['createdAt'] as Timestamp?,
      updatedAt: json['updatedAt'] as Timestamp?,
      lastMessage: json['lastMessage'] as String? ?? '',
      lastMessageAt: json['lastMessageAt'] as Timestamp?,
      lastMessageSenderId: json['lastMessageSenderId'] as String? ?? '',
      lastMessageType: json['lastMessageType'] as String? ?? 'text',
      mutedBy: _toStringList(json['mutedBy']),
      clearedAtBy: clearedAtBy,
      deletedFor: _toStringList(json['deletedFor']),
      groupName: json['groupName'] as String?,
      groupImageUrl: json['groupImageUrl'] as String?,
      admins: _toStringList(json['admins']),
      requestStatus: requestStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'participantIds': participantIds,
      'participantMap':
          participantMap.map((k, v) => MapEntry(k, v.toJson())),
      'createdBy': createdBy,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageType': lastMessageType,
      'mutedBy': mutedBy,
      'clearedAtBy': clearedAtBy,
      'deletedFor': deletedFor,
      if (groupName != null) 'groupName': groupName,
      if (groupImageUrl != null) 'groupImageUrl': groupImageUrl,
      'admins': admins,
      'requestStatus': requestStatus,
    };
  }

  ChatModel copyWith({
    String? id,
    String? type,
    List<String>? participantIds,
    Map<String, ChatParticipant>? participantMap,
    String? createdBy,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    String? lastMessage,
    Timestamp? lastMessageAt,
    String? lastMessageSenderId,
    String? lastMessageType,
    List<String>? mutedBy,
    Map<String, Timestamp>? clearedAtBy,
    List<String>? deletedFor,
    String? groupName,
    String? groupImageUrl,
    List<String>? admins,
    Map<String, String>? requestStatus,
  }) {
    return ChatModel(
      id: id ?? this.id,
      type: type ?? this.type,
      participantIds: participantIds ?? this.participantIds,
      participantMap: participantMap ?? this.participantMap,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      mutedBy: mutedBy ?? this.mutedBy,
      clearedAtBy: clearedAtBy ?? this.clearedAtBy,
      deletedFor: deletedFor ?? this.deletedFor,
      groupName: groupName ?? this.groupName,
      groupImageUrl: groupImageUrl ?? this.groupImageUrl,
      admins: admins ?? this.admins,
      requestStatus: requestStatus ?? this.requestStatus,
    );
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) return value.whereType<String>().toList();
    return [];
  }
}