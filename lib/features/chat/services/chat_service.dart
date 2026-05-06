import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/app_user_model.dart';
import '../models/chat_model.dart';
import '../models/chat_participant.dart';
import '../models/chat_summary_model.dart';
import '../models/message_model.dart';
import '../utils/chat_constants.dart';
import '../utils/chat_helpers.dart';

class ChatService {
  ChatService._();
  static final ChatService _instance = ChatService._();
  factory ChatService() => _instance;

  FirebaseFirestore get _fs => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _chatsCol() =>
      _fs.collection(ChatCollections.chats);

  CollectionReference<Map<String, dynamic>> _messagesCol(String chatId) =>
      _chatsCol().doc(chatId).collection(ChatCollections.messages);

  DocumentReference<Map<String, dynamic>> _summaryDoc(
    String uid,
    String chatId,
  ) => _fs
      .collection(ChatCollections.users)
      .doc(uid)
      .collection(ChatCollections.chatSummaries)
      .doc(chatId);

  Stream<List<ChatSummaryModel>> watchInbox(String uid) {
    if (uid.isEmpty) return Stream.value([]);
    return _fs
        .collection(ChatCollections.users)
        .doc(uid)
        .collection(ChatCollections.chatSummaries)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((d) => ChatSummaryModel.fromFirestore(d))
              .where((s) => !s.archived)
              .toList();
        });
  }

  Stream<int> watchTotalUnread(String uid) {
    if (uid.isEmpty) return Stream.value(0);
    return _fs
        .collection(ChatCollections.users)
        .doc(uid)
        .collection(ChatCollections.chatSummaries)
        .snapshots()
        .map((snap) {
          int total = 0;
          for (final doc in snap.docs) {
            final data = doc.data();
            final archived = data['archived'] as bool? ?? false;
            if (archived) continue;
            final count = data['unreadCount'] as int? ?? 0;
            if (count > 0) total += count;
          }
          return total;
        });
  }

  Stream<List<MessageModel>> watchMessages(
    String chatId,
    String uid, {
    Timestamp? clearedAt,
  }) {
    if (chatId.isEmpty || uid.isEmpty) return Stream.value([]);
    return _messagesCol(chatId)
        .orderBy('createdAt', descending: false)
        .limit(ChatLimits.initialMessagePageSize)
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((d) => MessageModel.fromFirestore(d, chatId))
              .where(
                (m) => !m.deletedForEveryone && !m.deletedFor.contains(uid),
              )
              .where((m) {
                if (clearedAt == null) return true;
                if (m.createdAt == null) return true;
                return m.createdAt!.compareTo(clearedAt) > 0;
              })
              .toList();
        });
  }

  Stream<ChatModel?> watchChat(String chatId) {
    if (chatId.isEmpty) return Stream.value(null);
    return _chatsCol().doc(chatId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return ChatModel.fromFirestore(snap);
    });
  }

  Future<ChatModel?> getChat(String chatId) async {
    if (chatId.isEmpty) return null;
    final snap = await _chatsCol().doc(chatId).get();
    if (!snap.exists) return null;
    return ChatModel.fromFirestore(snap);
  }

  Future<String> getOrCreateDirectChat({
    required AppUserModel currentUser,
    required AppUserModel otherUser,
  }) async {
    try {
      final chatId = ChatHelpers.directChatId(currentUser.uid, otherUser.uid);
      final chatRef = _chatsCol().doc(chatId);

      final currentParticipant = ChatParticipant(
        uid: currentUser.uid,
        displayName: currentUser.displayName ?? '',
        username: currentUser.username ?? '',
        avatarUrl: currentUser.profileImage ?? '',
      );
      final otherParticipant = ChatParticipant(
        uid: otherUser.uid,
        displayName: otherUser.displayName ?? '',
        username: otherUser.username ?? '',
        avatarUrl: otherUser.profileImage ?? '',
      );

      final chatModel = ChatModel(
        id: chatId,
        type: ChatTypes.direct,
        participantIds: [currentUser.uid, otherUser.uid],
        participantMap: {
          currentUser.uid: currentParticipant,
          otherUser.uid: otherParticipant,
        },
        createdBy: currentUser.uid,
      );

      // Avoid unconditional set() on an existing chat because that becomes an
      // update and can violate chat update rules.
      final existing = await chatRef.get();
      if (existing.exists) {
        final data = existing.data() ?? const <String, dynamic>{};
        final ids = (data['participantIds'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList();
        if (!ids.contains(currentUser.uid)) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'You are not a participant in this chat.',
          );
        }
        return chatId;
      }

      debugPrint('[ChatService] getOrCreateDirectChat: create chats/$chatId');
      await chatRef.set(chatModel.toJson());
      return chatId;
    } catch (e, st) {
      dev.log(
        'ChatService.getOrCreateDirectChat failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<String> createGroupChat({
    required AppUserModel creator,
    required List<AppUserModel> members,
    required String groupName,
  }) async {
    try {
      final allUsers = [creator, ...members];
      final participantIds = allUsers.map((u) => u.uid).toList();
      final participantMap = <String, ChatParticipant>{};
      for (final u in allUsers) {
        participantMap[u.uid] = ChatParticipant(
          uid: u.uid,
          displayName: u.displayName ?? '',
          username: u.username ?? '',
          avatarUrl: u.profileImage ?? '',
          role: u.uid == creator.uid ? 'admin' : 'member',
        );
      }

      final chatModel = ChatModel(
        id: '',
        type: ChatTypes.group,
        participantIds: participantIds,
        participantMap: participantMap,
        createdBy: creator.uid,
        groupName: groupName.trim(),
        admins: [creator.uid],
      );

      final docRef = await _chatsCol().add(chatModel.toJson());
      return docRef.id;
    } catch (e, st) {
      dev.log('ChatService.createGroupChat failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> sendTextMessage({
    required String chatId,
    required String senderId,
    required List<String> participantIds,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (chatId.isEmpty || senderId.isEmpty) return;
    if (!participantIds.contains(senderId)) return;

    try {
      debugPrint(
        '[ChatService] sendTextMessage: chatId=$chatId senderId=$senderId type=text textLen=${trimmed.length}',
      );
      await _messagesCol(chatId).add({
        'senderId': senderId,
        'type': ChatMessageTypes.text,
        'text': trimmed,
        'createdAt': FieldValue.serverTimestamp(),
        'deletedFor': <String>[],
        'deletedForEveryone': false,
        'seenBy': <String>[senderId],
        'deliveredTo': <String, dynamic>{},
        'reactions': <String, dynamic>{},
        'isViewOnce': false,
        'viewedBy': <String>[],
      });
      debugPrint('[ChatService] sendTextMessage: OK');
    } catch (e, st) {
      debugPrint('[ChatService] sendTextMessage FAILED: $e');
      dev.log('ChatService.sendTextMessage failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> sendMediaMessage({
    required String chatId,
    required String senderId,
    required List<String> participantIds,
    required String type,
    required String mediaUrl,
    required String storagePath,
    String? thumbnailUrl,
    int? width,
    int? height,
    int? durationMs,
  }) async {
    if (chatId.isEmpty || senderId.isEmpty) return;
    if (!participantIds.contains(senderId)) return;
    if (type != ChatMessageTypes.image &&
        type != ChatMessageTypes.video &&
        type != ChatMessageTypes.audio &&
        type != ChatMessageTypes.gif) {
      debugPrint('[ChatService] sendMediaMessage: rejected type=$type');
      return;
    }
    if (mediaUrl.isEmpty) return;
    if (type != ChatMessageTypes.gif && storagePath.isEmpty) return;

    try {
      debugPrint(
        '[ChatService] sendMediaMessage: chatId=$chatId senderId=$senderId type=$type hasMediaUrl=${mediaUrl.isNotEmpty} hasStoragePath=${storagePath.isNotEmpty} durationMs=$durationMs isViewOnce=false',
      );
      await _messagesCol(chatId).add({
        'senderId': senderId,
        'type': type,
        'text': '',
        'mediaUrl': mediaUrl,
        'thumbnailUrl': thumbnailUrl ?? '',
        'storagePath': storagePath,
        'width': ?width,
        'height': ?height,
        'durationMs': ?durationMs,
        'createdAt': FieldValue.serverTimestamp(),
        'deletedFor': <String>[],
        'deletedForEveryone': false,
        'seenBy': <String>[senderId],
        'deliveredTo': <String, dynamic>{},
        'reactions': <String, dynamic>{},
        'isViewOnce': false,
        'viewedBy': <String>[],
        'metadata': <String, dynamic>{},
      });
      debugPrint('[ChatService] sendMediaMessage: OK');
    } catch (e, st) {
      debugPrint('[ChatService] sendMediaMessage FAILED: $e');
      dev.log('ChatService.sendMediaMessage failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> markChatRead({
    required String uid,
    required String chatId,
  }) async {
    if (uid.isEmpty || chatId.isEmpty) return;
    try {
      await _summaryDoc(
        uid,
        chatId,
      ).set({'unreadCount': 0}, SetOptions(merge: true));
    } catch (e, st) {
      dev.log('ChatService.markChatRead failed', error: e, stackTrace: st);
    }
  }

  Future<void> deleteMessageForUser({
    required String uid,
    required String chatId,
    required String messageId,
  }) async {
    if (uid.isEmpty || chatId.isEmpty || messageId.isEmpty) return;
    try {
      await _messagesCol(chatId).doc(messageId).update({
        'deletedFor': FieldValue.arrayUnion([uid]),
      });
    } catch (e, st) {
      dev.log(
        'ChatService.deleteMessageForUser failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> deleteMessageForEveryone({
    required String uid,
    required String chatId,
    required String messageId,
    required Timestamp? messageCreatedAt,
  }) async {
    if (uid.isEmpty || chatId.isEmpty || messageId.isEmpty) return;
    if (messageCreatedAt == null) return;

    final msgTime = messageCreatedAt.toDate();
    final now = DateTime.now();
    final diff = now.difference(msgTime);
    if (diff.inMinutes > ChatLimits.deleteForEveryoneWindowMinutes) return;

    try {
      await _messagesCol(
        chatId,
      ).doc(messageId).update({'deletedForEveryone': true});
    } catch (e, st) {
      dev.log(
        'ChatService.deleteMessageForEveryone failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> muteChat({required String uid, required String chatId}) async {
    if (uid.isEmpty || chatId.isEmpty) return;
    try {
      debugPrint('[ChatService] muteChat: path=chats/$chatId fields=[mutedBy]');
      await _chatsCol().doc(chatId).update({
        'mutedBy': FieldValue.arrayUnion([uid]),
      });
      await _summaryDoc(
        uid,
        chatId,
      ).set({'muted': true}, SetOptions(merge: true));
    } catch (e, st) {
      debugPrint('[ChatService] muteChat FAILED: $e');
      dev.log('ChatService.muteChat failed', error: e, stackTrace: st);
    }
  }

  Future<void> unmuteChat({required String uid, required String chatId}) async {
    if (uid.isEmpty || chatId.isEmpty) return;
    try {
      debugPrint(
        '[ChatService] unmuteChat: path=chats/$chatId fields=[mutedBy]',
      );
      await _chatsCol().doc(chatId).update({
        'mutedBy': FieldValue.arrayRemove([uid]),
      });
      await _summaryDoc(
        uid,
        chatId,
      ).set({'muted': false}, SetOptions(merge: true));
    } catch (e, st) {
      debugPrint('[ChatService] unmuteChat FAILED: $e');
      dev.log('ChatService.unmuteChat failed', error: e, stackTrace: st);
    }
  }

  Future<void> clearChat({required String uid, required String chatId}) async {
    if (uid.isEmpty || chatId.isEmpty) return;
    try {
      final now = FieldValue.serverTimestamp();
      debugPrint(
        '[ChatService] clearChat: path=chats/$chatId fields=[clearedAtBy.$uid, updatedAt]',
      );
      await _chatsCol().doc(chatId).update({
        'clearedAtBy.$uid': now,
        'updatedAt': now,
      });
      await _summaryDoc(
        uid,
        chatId,
      ).set({'clearedAt': now, 'unreadCount': 0}, SetOptions(merge: true));
    } catch (e, st) {
      debugPrint('[ChatService] clearChat FAILED: $e');
      dev.log('ChatService.clearChat failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> acceptMessageRequest({
    required String uid,
    required String chatId,
  }) async {
    if (uid.isEmpty || chatId.isEmpty) return;
    try {
      await _summaryDoc(
        uid,
        chatId,
      ).set({'requestStatus': RequestStatus.accepted}, SetOptions(merge: true));
    } catch (e, st) {
      dev.log(
        'ChatService.acceptMessageRequest failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> declineMessageRequest({
    required String uid,
    required String chatId,
  }) async {
    if (uid.isEmpty || chatId.isEmpty) return;
    try {
      await _summaryDoc(uid, chatId).set({
        'requestStatus': RequestStatus.declined,
        'archived': true,
      }, SetOptions(merge: true));
    } catch (e, st) {
      dev.log(
        'ChatService.declineMessageRequest failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> updateGroupName({
    required String chatId,
    required String groupName,
  }) async {
    if (chatId.isEmpty || groupName.trim().isEmpty) return;
    try {
      await _chatsCol().doc(chatId).update({
        'groupName': groupName.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      dev.log('ChatService.updateGroupName failed', error: e, stackTrace: st);
    }
  }

  Future<void> leaveGroup({required String uid, required String chatId}) async {
    if (uid.isEmpty || chatId.isEmpty) return;
    try {
      final chat = await getChat(chatId);
      if (chat == null) return;
      if (chat.admins.contains(uid) &&
          chat.admins.length == 1 &&
          chat.participantIds.length > 1) {
        throw Exception('last-admin');
      }
      await _chatsCol().doc(chatId).update({
        'participantIds': FieldValue.arrayRemove([uid]),
        'participantMap.$uid': FieldValue.delete(),
        'admins': FieldValue.arrayRemove([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _summaryDoc(
        uid,
        chatId,
      ).set({'archived': true}, SetOptions(merge: true));
    } catch (e, st) {
      dev.log('ChatService.leaveGroup failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> removeMember({
    required String chatId,
    required String memberUid,
  }) async {
    if (chatId.isEmpty || memberUid.isEmpty) return;
    try {
      await _chatsCol().doc(chatId).update({
        'participantIds': FieldValue.arrayRemove([memberUid]),
        'participantMap.$memberUid': FieldValue.delete(),
        'admins': FieldValue.arrayRemove([memberUid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _summaryDoc(
        memberUid,
        chatId,
      ).set({'archived': true}, SetOptions(merge: true));
    } catch (e, st) {
      dev.log('ChatService.removeMember failed', error: e, stackTrace: st);
    }
  }

  Future<void> addMembers({
    required String chatId,
    required List<AppUserModel> newMembers,
  }) async {
    if (chatId.isEmpty || newMembers.isEmpty) return;
    try {
      final updates = <String, dynamic>{
        'participantIds': FieldValue.arrayUnion(
          newMembers.map((u) => u.uid).toList(),
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      for (final u in newMembers) {
        updates['participantMap.${u.uid}'] = ChatParticipant(
          uid: u.uid,
          displayName: u.displayName ?? '',
          username: u.username ?? '',
          avatarUrl: u.profileImage ?? '',
        ).toJson();
      }
      await _chatsCol().doc(chatId).update(updates);
    } catch (e, st) {
      dev.log('ChatService.addMembers failed', error: e, stackTrace: st);
    }
  }

  Future<void> makeAdmin({
    required String chatId,
    required String memberUid,
  }) async {
    if (chatId.isEmpty || memberUid.isEmpty) return;
    try {
      await _chatsCol().doc(chatId).update({
        'admins': FieldValue.arrayUnion([memberUid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      dev.log('ChatService.makeAdmin failed', error: e, stackTrace: st);
    }
  }

  Future<void> markMessagesSeen({
    required String chatId,
    required String uid,
    required List<MessageModel> messages,
  }) async {
    if (chatId.isEmpty || uid.isEmpty || messages.isEmpty) return;
    try {
      final unseen = messages
          .where((m) => m.senderId != uid && !m.seenBy.contains(uid))
          .toList();
      if (unseen.isEmpty) return;
      final batch = _fs.batch();
      for (final m in unseen) {
        batch.update(_messagesCol(chatId).doc(m.id), {
          'seenBy': FieldValue.arrayUnion([uid]),
        });
      }
      await batch.commit();
    } catch (e, st) {
      dev.log('ChatService.markMessagesSeen failed', error: e, stackTrace: st);
    }
  }

  Future<void> sendViewOnceMediaMessage({
    required String chatId,
    required String senderId,
    required List<String> participantIds,
    required String type,
    required String mediaUrl,
    required String storagePath,
    String? thumbnailUrl,
    int? width,
    int? height,
    int? durationMs,
  }) async {
    if (chatId.isEmpty || senderId.isEmpty) return;
    if (!participantIds.contains(senderId)) return;
    if (type != ChatMessageTypes.image && type != ChatMessageTypes.video)
      return;
    if (mediaUrl.isEmpty || storagePath.isEmpty) return;

    try {
      await _messagesCol(chatId).add({
        'senderId': senderId,
        'type': type,
        'text': '',
        'mediaUrl': mediaUrl,
        'thumbnailUrl': thumbnailUrl ?? '',
        'storagePath': storagePath,
        'width': ?width,
        'height': ?height,
        'durationMs': ?durationMs,
        'createdAt': FieldValue.serverTimestamp(),
        'deletedFor': <String>[],
        'deletedForEveryone': false,
        'seenBy': <String>[senderId],
        'deliveredTo': <String, dynamic>{},
        'reactions': <String, dynamic>{},
        'isViewOnce': true,
        'viewedBy': <String>[],
        'metadata': <String, dynamic>{},
      });
    } catch (e, st) {
      dev.log(
        'ChatService.sendViewOnceMediaMessage failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> markViewOnceViewed({
    required String chatId,
    required String messageId,
    required String uid,
  }) async {
    if (chatId.isEmpty || messageId.isEmpty || uid.isEmpty) return;
    try {
      final docRef = _messagesCol(chatId).doc(messageId);
      final snap = await docRef.get();
      if (!snap.exists) return;
      final data = snap.data();
      if (data == null) return;
      final senderId = data['senderId'] as String? ?? '';
      if (uid == senderId) return;
      final isViewOnce = data['isViewOnce'] as bool? ?? false;
      if (!isViewOnce) return;
      final viewedBy =
          (data['viewedBy'] as List?)?.whereType<String>().toList() ?? [];
      if (viewedBy.contains(uid)) return;
      await docRef.update({
        'viewedBy': FieldValue.arrayUnion([uid]),
      });
    } catch (e, st) {
      dev.log(
        'ChatService.markViewOnceViewed failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> sendCallSystemMessage({
    required String chatId,
    required String senderId,
    required String callId,
    required String callType,
    required String callStatus,
    int? durationSeconds,
  }) async {
    if (chatId.isEmpty || senderId.isEmpty || callId.isEmpty) return;
    try {
      String preview;
      switch (callStatus) {
        case 'ended':
          preview = callType == 'video' ? 'Video call' : 'Audio call';
          if (durationSeconds != null && durationSeconds > 0) {
            final m = (durationSeconds ~/ 60).toString().padLeft(2, '0');
            final s = (durationSeconds % 60).toString().padLeft(2, '0');
            preview += ' ($m:$s)';
          }
        case 'missed':
          preview = 'Missed ${callType == 'video' ? 'video' : 'audio'} call';
        case 'declined':
          preview = 'Declined ${callType == 'video' ? 'video' : 'audio'} call';
        default:
          preview = callType == 'video' ? 'Video call' : 'Audio call';
      }
      debugPrint(
        '[ChatService] sendCallSystemMessage: chatId=$chatId senderId=$senderId type=call callId=$callId callType=$callType callStatus=$callStatus',
      );
      await _messagesCol(chatId).add({
        'senderId': senderId,
        'type': ChatMessageTypes.call,
        'text': preview,
        'createdAt': FieldValue.serverTimestamp(),
        'deletedFor': <String>[],
        'deletedForEveryone': false,
        'seenBy': <String>[senderId],
        'deliveredTo': <String, dynamic>{},
        'reactions': <String, dynamic>{},
        'isViewOnce': false,
        'viewedBy': <String>[],
        'metadata': {
          'callId': callId,
          'callType': callType,
          'callStatus': callStatus,
          if (durationSeconds != null) 'durationSeconds': durationSeconds,
        },
      });
      debugPrint('[ChatService] sendCallSystemMessage: OK');
    } catch (e, st) {
      debugPrint('[ChatService] sendCallSystemMessage FAILED: $e');
      dev.log(
        'ChatService.sendCallSystemMessage failed',
        error: e,
        stackTrace: st,
      );
    }
  }
}
