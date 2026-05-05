import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/local_notification_service.dart';

class ChatNotificationService {
  ChatNotificationService._();
  static final ChatNotificationService instance = ChatNotificationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  String? _uid;
  bool _primed = false;
  final Map<String, int> _lastUnreadCounts = <String, int>{};
  String? _activeChatId;

  void setActiveChatId(String? chatId) {
    _activeChatId = chatId;
  }

  void startForUser(String uid) {
    if (uid.isEmpty) return;
    if (_uid == uid && _sub != null) return;
    stop();
    _uid = uid;
    _sub = _db
        .collection('users')
        .doc(uid)
        .collection('chatSummaries')
        .orderBy('lastMessageAt', descending: true)
        .limit(50)
        .snapshots()
        .listen(_onSnapshot, onError: (_) {});
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _uid = null;
    _primed = false;
    _lastUnreadCounts.clear();
    _activeChatId = null;
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    if (!_primed) {
      _primed = true;
      for (final doc in snap.docs) {
        final data = doc.data();
        _lastUnreadCounts[doc.id] = (data['unreadCount'] as int?) ?? 0;
      }
      return;
    }

    for (final change in snap.docChanges) {
      if (change.type == DocumentChangeType.removed) continue;
      final doc = change.doc;
      final data = doc.data() ?? const <String, dynamic>{};
      final chatId = doc.id;
      final newUnread = (data['unreadCount'] as int?) ?? 0;
      final prevUnread = _lastUnreadCounts[chatId] ?? 0;
      _lastUnreadCounts[chatId] = newUnread;

      if (newUnread <= prevUnread) continue;
      if (chatId == _activeChatId) continue;

      final muted = data['muted'] as bool? ?? false;
      if (muted) continue;

      final senderId = (data['lastMessageSenderId'] as String?) ?? '';
      if (senderId == _uid) continue;

      final title = (data['title'] as String?)?.trim() ?? 'New message';
      final body = (data['lastMessage'] as String?)?.trim() ?? '';
      if (body.isEmpty) continue;

      LocalNotificationService.instance.show(title: title, body: body);
    }
  }
}
