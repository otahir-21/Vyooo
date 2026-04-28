import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';
import 'user_service.dart';

enum AppNotificationType { follow, like, comment, share, subscribe }

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

  static AppNotification fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawType = (data['type'] as String?) ?? '';
    final type = AppNotificationType.values.firstWhere(
      (t) => t.name == rawType,
      orElse: () => AppNotificationType.comment,
    );
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
    final senderId = _uid;
    if (senderId == null || senderId.isEmpty || recipientId.isEmpty) return;
    if (recipientId == senderId) return;

    var actorUsername = '';
    var actorAvatarUrl = '';
    try {
      final actor = await UserService().getUser(senderId);
      actorUsername = (actor?.username ?? actor?.displayName ?? '').trim();
      actorAvatarUrl = (actor?.profileImage ?? '').trim();
    } catch (_) {}
    if (actorUsername.isEmpty) {
      actorUsername = AuthService().currentUser?.displayName?.trim() ?? 'Someone';
    }

    await _db.collection('notifications').add({
      'recipientId': recipientId,
      'senderId': senderId,
      'type': type.name,
      'message': message,
      'actorUsername': actorUsername,
      'actorAvatarUrl': actorAvatarUrl,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      ...extra,
    });
  }
}
