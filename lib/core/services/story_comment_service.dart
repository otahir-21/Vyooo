import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/comments/models/comment.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'user_service.dart';

/// Firestore: `stories/{storyId}/comments/{commentId}` (+ `likes/{userId}` per comment).
class StoryCommentService {
  StoryCommentService._();
  static final StoryCommentService _instance = StoryCommentService._();
  factory StoryCommentService() => _instance;

  static const int recentTailLimit = 80;
  static const int olderPageSize = 40;
  static const int maxCommentLength = 2000;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get _uid => AuthService().currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _comments(String storyId) =>
      _firestore.collection('stories').doc(storyId).collection('comments');

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRecentCommentsTail(
    String storyId, {
    int limit = recentTailLimit,
  }) {
    return _comments(
      storyId,
    ).orderBy('createdAt', descending: true).limit(limit).snapshots();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> fetchCommentsOlderThan(
    String storyId,
    QueryDocumentSnapshot<Map<String, dynamic>> oldestLoaded, {
    int limit = olderPageSize,
  }) {
    return _comments(storyId)
        .orderBy('createdAt', descending: true)
        .endBeforeDocument(oldestLoaded)
        .limit(limit)
        .get();
  }

  static String formatTimeAgo(Timestamp? ts) {
    if (ts == null) return 'Just now';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo';
    return '${(diff.inDays / 365).floor()}y';
  }

  Future<List<Comment>> commentsFromDocuments(
    String storyId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) => _snapshotToComments(storyId, docs);

  Future<List<Comment>> _snapshotToComments(
    String storyId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final uid = _uid ?? '';
    final byId = <String, _SNode>{};

    for (final d in docs) {
      final data = d.data();
      final parentId = (data['parentId'] as String?)?.trim() ?? '';
      byId[d.id] = _SNode(
        id: d.id,
        parentId: parentId,
        data: data,
        createdAt: data['createdAt'] as Timestamp?,
      );
    }

    final childrenOf = <String, List<_SNode>>{};
    final roots = <_SNode>[];

    for (final n in byId.values) {
      if (n.parentId.isEmpty || !byId.containsKey(n.parentId)) {
        roots.add(n);
      } else {
        childrenOf.putIfAbsent(n.parentId, () => []).add(n);
      }
    }

    int byTime(_SNode a, _SNode b) {
      final ta = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final tb = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return ta.compareTo(tb);
    }

    roots.sort(byTime);
    for (final list in childrenOf.values) {
      list.sort(byTime);
    }

    final allIds = byId.keys.toList();
    final liked = await _likedCommentIds(storyId, allIds, uid);

    Comment buildTree(_SNode n) {
      final kids = childrenOf[n.id] ?? [];
      final replyModels = kids.map(buildTree).toList();
      return _nodeToComment(n, replyModels, liked, uid);
    }

    return roots.map(buildTree).toList();
  }

  Comment _nodeToComment(
    _SNode n,
    List<Comment> replies,
    Set<String> likedIds,
    String uid,
  ) {
    final data = n.data;
    final authorId = data['userId'] as String? ?? '';
    final likeCount = (data['likeCount'] as num?)?.toInt() ?? 0;

    return Comment(
      id: n.id,
      username: data['username'] as String? ?? 'User',
      avatarUrl: data['avatarUrl'] as String? ?? '',
      isVerified: data['isVerified'] as bool? ?? false,
      timeAgo: formatTimeAgo(n.createdAt),
      text: data['text'] as String? ?? '',
      likeCount: likeCount,
      isLiked: uid.isNotEmpty && likedIds.contains(n.id),
      replyCount: replies.length,
      replies: replies,
      isOwnComment: uid.isNotEmpty && authorId == uid,
      authorUserId: authorId,
    );
  }

  Future<Set<String>> _likedCommentIds(
    String storyId,
    List<String> commentIds,
    String uid,
  ) async {
    if (uid.isEmpty || commentIds.isEmpty) return {};
    final snaps = await Future.wait(
      commentIds.map(
        (id) => _comments(storyId).doc(id).collection('likes').doc(uid).get(),
      ),
    );
    final out = <String>{};
    for (var i = 0; i < commentIds.length; i++) {
      if (snaps[i].exists) out.add(commentIds[i]);
    }
    return out;
  }

  Future<String> _effectiveParentId(String storyId, String rawParentId) async {
    final p = rawParentId.trim();
    if (p.isEmpty) return '';
    final doc = await _comments(storyId).doc(p).get();
    if (!doc.exists) return '';
    final parentOfParent = (doc.data()?['parentId'] as String?)?.trim() ?? '';
    if (parentOfParent.isNotEmpty) return parentOfParent;
    return p;
  }

  Future<void> addComment(
    String storyId,
    String text, {
    String parentId = '',
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > maxCommentLength) return;

    final effectiveParent = await _effectiveParentId(storyId, parentId);

    var username = AuthService().currentUser?.displayName ?? '';
    var avatarUrl = AuthService().currentUser?.photoURL ?? '';
    if (username.isEmpty) {
      username = AuthService().currentUser?.email?.split('@').first ?? 'User';
    }
    try {
      final u = await UserService().getUser(uid);
      if (u != null) {
        if ((u.username ?? '').isNotEmpty) username = u.username!;
        if ((u.profileImage ?? '').isNotEmpty) avatarUrl = u.profileImage!;
      }
    } catch (_) {}

    final batch = _firestore.batch();
    final commentRef = _comments(storyId).doc();
    batch.set(commentRef, {
      'userId': uid,
      'username': username,
      'avatarUrl': avatarUrl,
      'text': trimmed,
      'parentId': effectiveParent,
      'likeCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'isVerified': false,
    });

    final storySnap = await _firestore.collection('stories').doc(storyId).get();
    final storyOwnerId = (storySnap.data()?['userId'] as String?) ?? '';
    // `comments` on the story doc is maintained by Cloud Function `syncStoryCommentCountOnCreate`.

    await batch.commit();
    final displayComment = trimmed.length > 60
        ? '${trimmed.substring(0, 57)}...'
        : trimmed;

    // Notify Story Owner
    if (storyOwnerId.isNotEmpty && storyOwnerId != uid) {
      await NotificationService().create(
        recipientId: storyOwnerId,
        type: AppNotificationType.comment,
        message: 'commented on your story: "$displayComment"',
        extra: {'storyId': storyId, 'commentId': commentRef.id},
      );
    }

    // Notify Parent Comment Author (if it's a reply)
    if (effectiveParent.isNotEmpty) {
      try {
        final parentDoc = await _comments(storyId).doc(effectiveParent).get();
        final parentAuthorId = (parentDoc.data()?['userId'] as String?) ?? '';
        if (parentAuthorId.isNotEmpty && parentAuthorId != uid && parentAuthorId != storyOwnerId) {
          await NotificationService().create(
            recipientId: parentAuthorId,
            type: AppNotificationType.comment,
            message: 'replied to your comment: "$displayComment"',
            extra: {'storyId': storyId, 'commentId': commentRef.id, 'parentId': effectiveParent},
          );
        }
      } catch (_) {}
    }
  }

  Future<int> deleteComment(String storyId, String commentId) async {
    final uid = _uid;
    if (uid == null) return 0;

    final ref = _comments(storyId).doc(commentId);
    final snap = await ref.get();
    if (!snap.exists) return 0;
    final authorId = snap.data()?['userId'] as String? ?? '';
    if (authorId != uid) return 0;

    final subtreeIds = await _collectSubtreeIds(storyId, commentId);
    final batch = _firestore.batch();
    for (final id in subtreeIds) {
      batch.delete(_comments(storyId).doc(id));
    }
    // `comments` on the story doc is decremented by Cloud Function `syncStoryCommentCountOnDelete`
    // once per removed comment doc.
    await batch.commit();
    return subtreeIds.length;
  }

  Future<List<String>> _collectSubtreeIds(String storyId, String rootId) async {
    final all = await _comments(storyId).get();
    final byParent = <String, List<String>>{};
    for (final d in all.docs) {
      final p = (d.data()['parentId'] as String?)?.trim() ?? '';
      byParent.putIfAbsent(p, () => []).add(d.id);
    }
    final out = <String>[];
    void walk(String id) {
      out.add(id);
      for (final c in byParent[id] ?? []) {
        walk(c);
      }
    }

    walk(rootId);
    return out;
  }

  Future<void> toggleCommentLike(
    String storyId,
    String commentId,
    bool currentlyLiked,
  ) async {
    final uid = _uid;
    if (uid == null) return;

    final likeRef = _comments(
      storyId,
    ).doc(commentId).collection('likes').doc(uid);
    final commentRef = _comments(storyId).doc(commentId);
    final batch = _firestore.batch();

    if (currentlyLiked) {
      batch.delete(likeRef);
      batch.update(commentRef, {'likeCount': FieldValue.increment(-1)});
    } else {
      batch.set(likeRef, {
        'userId': uid,
        'likedAt': FieldValue.serverTimestamp(),
      });
      batch.update(commentRef, {'likeCount': FieldValue.increment(1)});
    }
    await batch.commit();
  }

  Future<void> reportComment({
    required String storyId,
    required String commentId,
    required String commentAuthorId,
    required String reason,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _firestore.collection('comment_reports').add({
      'storyId': storyId,
      'reelId': '',
      'commentId': commentId,
      'commentAuthorId': commentAuthorId,
      'reporterId': uid,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

class _SNode {
  _SNode({
    required this.id,
    required this.parentId,
    required this.data,
    required this.createdAt,
  });

  final String id;
  final String parentId;
  final Map<String, dynamic> data;
  final Timestamp? createdAt;
}
