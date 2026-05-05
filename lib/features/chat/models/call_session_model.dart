import 'package:cloud_firestore/cloud_firestore.dart';

abstract final class CallStatus {
  static const String ringing = 'ringing';
  static const String active = 'active';
  static const String ended = 'ended';
  static const String missed = 'missed';
  static const String declined = 'declined';
  static const String failed = 'failed';
}

abstract final class CallType {
  static const String audio = 'audio';
  static const String video = 'video';
}

class CallSessionModel {
  const CallSessionModel({
    required this.id,
    required this.chatId,
    required this.callerId,
    required this.calleeIds,
    required this.participantIds,
    required this.type,
    required this.status,
    required this.agoraChannelName,
    this.agoraUidMap = const {},
    this.startedAt,
    this.acceptedAt,
    this.endedAt,
    this.endedBy,
    this.durationSeconds,
    this.createdAt,
    this.updatedAt,
    this.metadata = const {},
  });

  final String id;
  final String chatId;
  final String callerId;
  final List<String> calleeIds;
  final List<String> participantIds;
  final String type;
  final String status;
  final String agoraChannelName;
  final Map<String, dynamic> agoraUidMap;
  final Timestamp? startedAt;
  final Timestamp? acceptedAt;
  final Timestamp? endedAt;
  final String? endedBy;
  final int? durationSeconds;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final Map<String, dynamic> metadata;

  factory CallSessionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final json = doc.data() ?? {};
    return CallSessionModel.fromJson(json, id: doc.id);
  }

  factory CallSessionModel.fromJson(
    Map<String, dynamic> json, {
    String? id,
  }) {
    return CallSessionModel(
      id: id ?? json['id'] as String? ?? '',
      chatId: json['chatId'] as String? ?? '',
      callerId: json['callerId'] as String? ?? '',
      calleeIds: _toStringList(json['calleeIds']),
      participantIds: _toStringList(json['participantIds']),
      type: json['type'] as String? ?? CallType.audio,
      status: json['status'] as String? ?? CallStatus.ringing,
      agoraChannelName: json['agoraChannelName'] as String? ?? '',
      agoraUidMap: _toMap(json['agoraUidMap']),
      startedAt: _toTimestamp(json['startedAt']),
      acceptedAt: _toTimestamp(json['acceptedAt']),
      endedAt: _toTimestamp(json['endedAt']),
      endedBy: json['endedBy'] as String?,
      durationSeconds: json['durationSeconds'] as int?,
      createdAt: _toTimestamp(json['createdAt']),
      updatedAt: _toTimestamp(json['updatedAt']),
      metadata: _toMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chatId': chatId,
      'callerId': callerId,
      'calleeIds': calleeIds,
      'participantIds': participantIds,
      'type': type,
      'status': status,
      'agoraChannelName': agoraChannelName,
      'agoraUidMap': agoraUidMap,
      if (startedAt != null) 'startedAt': startedAt,
      if (acceptedAt != null) 'acceptedAt': acceptedAt,
      if (endedAt != null) 'endedAt': endedAt,
      if (endedBy != null) 'endedBy': endedBy,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
      'metadata': metadata,
    };
  }

  CallSessionModel copyWith({
    String? id,
    String? chatId,
    String? callerId,
    List<String>? calleeIds,
    List<String>? participantIds,
    String? type,
    String? status,
    String? agoraChannelName,
    Map<String, dynamic>? agoraUidMap,
    Timestamp? startedAt,
    Timestamp? acceptedAt,
    Timestamp? endedAt,
    String? endedBy,
    int? durationSeconds,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return CallSessionModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      callerId: callerId ?? this.callerId,
      calleeIds: calleeIds ?? this.calleeIds,
      participantIds: participantIds ?? this.participantIds,
      type: type ?? this.type,
      status: status ?? this.status,
      agoraChannelName: agoraChannelName ?? this.agoraChannelName,
      agoraUidMap: agoraUidMap ?? this.agoraUidMap,
      startedAt: startedAt ?? this.startedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      endedAt: endedAt ?? this.endedAt,
      endedBy: endedBy ?? this.endedBy,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) return value.whereType<String>().toList();
    return [];
  }

  static Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  static Timestamp? _toTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    return null;
  }
}
