import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';
import 'user_service.dart';

enum AppNotificationType {
  follow,
  followRequest,
  followRequestAccepted,
  like,
  comment,
  mention,
  share,
  repost,
  subscribe,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.senderId,
    required this.type,
    required this.message,
    required this.createdAt,
    required this.isRead,
    this.actorUsername = '',
    this.actorAvatarUrl = '',
    this.reelId = '',
    this.storyId = '',
    this.commentId = '',
    this.targetUserId = '',
  });

  final String id;
  final String recipientId;
  final String senderId;
  final AppNotificationType type;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String actorUsername;
  final String actorAvatarUrl;
  final String reelId;
  final String storyId;
  final String commentId;
  final String targetUserId;

  static AppNotification fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawType = (data['type'] as String?) ?? '';
    AppNotificationType type = AppNotificationType.comment;
    for (final t in AppNotificationType.values) {
      if (t.name == rawType) {
        type = t;
        break;
      }
    }
    return AppNotification(
      id: doc.id,
      recipientId: (data['recipientId'] as String?) ?? '',
      senderId: (data['senderId'] as String?) ?? '',
      type: type,
      message: (data['message'] as String?) ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: (data['isRead'] as bool?) ?? false,
      actorUsername: (data['actorUsername'] as String?) ?? '',
      actorAvatarUrl: (data['actorAvatarUrl'] as String?) ?? '',
      reelId: (data['reelId'] as String?) ?? '',
      storyId: (data['storyId'] as String?) ?? '',
      commentId: (data['commentId'] as String?) ?? '',
      targetUserId: (data['targetUserId'] as String?) ?? '',
    );
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? get _uid => AuthService().currentUser?.uid;

  Stream<List<AppNotification>> watchMyNotifications() {
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      final uid = user?.uid ?? '';
      if (uid.isEmpty) return Stream.value(const <AppNotification>[]);
      return _db
          .collection('notifications')
          .where('recipientId', isEqualTo: uid)
          .limit(200)
          .snapshots()
          .map((q) {
            final items = q.docs.map(AppNotification.fromDoc).toList();
            items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return items;
          });
    });
  }

  Stream<int> watchUnreadCount() {
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      final uid = user?.uid ?? '';
      if (uid.isEmpty) return Stream.value(0);
      return _db
          .collection('notifications')
          .where('recipientId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .map((q) => q.docs.length);
    });
  }

  Future<void> markAsRead(String notificationId) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty || notificationId.isEmpty) return;
    await _db.collection('notifications').doc(notificationId).set({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markAsReadBulk(List<String> notificationIds) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    final ids = notificationIds.where((e) => e.trim().isNotEmpty).toList();
    if (ids.isEmpty) return;

    final batch = _db.batch();
    for (final id in ids) {
      final ref = _db.collection('notifications').doc(id);
      batch.set(ref, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> create({
    required String recipientId,
    required AppNotificationType type,
    required String message,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) async {
    await createOnce(
      dedupeId: '',
      recipientId: recipientId,
      type: type,
      message: message,
      extra: extra,
      allowDuplicate: true,
    );
  }

  /// Creates a notification once per [dedupeId]. When [allowDuplicate] is true
  /// (default for [create]), a random document id is used instead.
  ///
  /// Like notifications use a stable id so unlike → re-like does not notify
  /// the owner again.
  Future<bool> createOnce({
    required String dedupeId,
    required String recipientId,
    required AppNotificationType type,
    required String message,
    Map<String, dynamic> extra = const <String, dynamic>{},
    bool allowDuplicate = false,
  }) async {
    final senderId = _uid;
    if (senderId == null || senderId.isEmpty || recipientId.isEmpty) {
      return false;
    }
    if (recipientId == senderId) return false;

    var actorUsername = '';
    var actorAvatarUrl = '';
    try {
      final actor = await UserService().getUser(senderId);
      actorUsername = (actor?.username ?? actor?.displayName ?? '').trim();
      actorAvatarUrl = (actor?.profileImage ?? '').trim();
    } catch (_) {}
    if (actorUsername.isEmpty) {
      actorUsername =
          AuthService().currentUser?.displayName?.trim() ?? 'Someone';
    }

    final payload = <String, dynamic>{
      'recipientId': recipientId,
      'senderId': senderId,
      'type': type.name,
      'message': message,
      'actorUsername': actorUsername,
      'actorAvatarUrl': actorAvatarUrl,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      ...extra,
    };

    if (allowDuplicate || dedupeId.trim().isEmpty) {
      await _db.collection('notifications').add(payload);
      return true;
    }

    final ref = _db.collection('notifications').doc(dedupeId.trim());
    try {
      // Create-only: full set on a missing doc. If the dedupe doc already exists,
      // rules allow only the recipient to update it — we treat that as success.
      await ref.set(payload);
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return false;
      rethrow;
    }
  }
}
