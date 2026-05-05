import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.type = 'text',
    this.text = '',
    this.mediaUrl,
    this.thumbnailUrl,
    this.storagePath,
    this.durationMs,
    this.width,
    this.height,
    this.createdAt,
    this.updatedAt,
    this.deletedFor = const [],
    this.deletedForEveryone = false,
    this.seenBy = const [],
    this.deliveredTo = const [],
    this.reactions = const {},
    this.replyToMessageId,
    this.isViewOnce = false,
    this.viewedBy = const [],
    this.expiresAt,
    this.metadata = const {},
  });

  final String id;
  final String chatId;
  final String senderId;
  final String type;
  final String text;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? storagePath;
  final int? durationMs;
  final int? width;
  final int? height;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final List<String> deletedFor;
  final bool deletedForEveryone;
  final List<String> seenBy;
  final List<String> deliveredTo;
  final Map<String, dynamic> reactions;
  final String? replyToMessageId;
  final bool isViewOnce;
  final List<String> viewedBy;
  final Timestamp? expiresAt;
  final Map<String, dynamic> metadata;

  factory MessageModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String chatId,
  ) {
    final json = doc.data() ?? {};
    return MessageModel.fromJson(json, id: doc.id, chatId: chatId);
  }

  factory MessageModel.fromJson(
    Map<String, dynamic> json, {
    String? id,
    String? chatId,
  }) {
    return MessageModel(
      id: id ?? json['id'] as String? ?? '',
      chatId: chatId ?? json['chatId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      text: json['text'] as String? ?? '',
      mediaUrl: json['mediaUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      storagePath: json['storagePath'] as String?,
      durationMs: json['durationMs'] as int?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      createdAt: json['createdAt'] as Timestamp?,
      updatedAt: json['updatedAt'] as Timestamp?,
      deletedFor: _toStringList(json['deletedFor']),
      deletedForEveryone: json['deletedForEveryone'] as bool? ?? false,
      seenBy: _toStringList(json['seenBy']),
      deliveredTo: _toStringList(json['deliveredTo']),
      reactions: _toMap(json['reactions']),
      replyToMessageId: json['replyToMessageId'] as String?,
      isViewOnce: json['isViewOnce'] as bool? ?? false,
      viewedBy: _toStringList(json['viewedBy']),
      expiresAt: json['expiresAt'] as Timestamp?,
      metadata: _toMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'type': type,
      'text': text,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (storagePath != null) 'storagePath': storagePath,
      if (durationMs != null) 'durationMs': durationMs,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      if (updatedAt != null) 'updatedAt': updatedAt,
      'deletedFor': deletedFor,
      'deletedForEveryone': deletedForEveryone,
      'seenBy': seenBy,
      'deliveredTo': deliveredTo,
      'reactions': reactions,
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      'isViewOnce': isViewOnce,
      'viewedBy': viewedBy,
      if (expiresAt != null) 'expiresAt': expiresAt,
      'metadata': metadata,
    };
  }

  MessageModel copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? type,
    String? text,
    String? mediaUrl,
    String? thumbnailUrl,
    String? storagePath,
    int? durationMs,
    int? width,
    int? height,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    List<String>? deletedFor,
    bool? deletedForEveryone,
    List<String>? seenBy,
    List<String>? deliveredTo,
    Map<String, dynamic>? reactions,
    String? replyToMessageId,
    bool? isViewOnce,
    List<String>? viewedBy,
    Timestamp? expiresAt,
    Map<String, dynamic>? metadata,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      type: type ?? this.type,
      text: text ?? this.text,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      storagePath: storagePath ?? this.storagePath,
      durationMs: durationMs ?? this.durationMs,
      width: width ?? this.width,
      height: height ?? this.height,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedFor: deletedFor ?? this.deletedFor,
      deletedForEveryone: deletedForEveryone ?? this.deletedForEveryone,
      seenBy: seenBy ?? this.seenBy,
      deliveredTo: deliveredTo ?? this.deliveredTo,
      reactions: reactions ?? this.reactions,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      isViewOnce: isViewOnce ?? this.isViewOnce,
      viewedBy: viewedBy ?? this.viewedBy,
      expiresAt: expiresAt ?? this.expiresAt,
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
}