import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/comments/models/comment.dart';
import 'auth_service.dart';
import 'user_service.dart';

/// Firestore: `reels/{reelId}/comments/{commentId}` (+ `likes/{userId}` per comment).
/// Reports: top-level `comment_reports`.
class CommentService {
  CommentService._();
  static final CommentService _instance = CommentService._();
  factory CommentService() => _instance;

  /// Tail query: latest N comments (desc), merged client-side with older pages.
  static const int recentTailLimit = 80;

  /// Each "Load earlier" page (chronologically before the oldest loaded comment).
  static const int olderPageSize = 40;

  /// Max body length (keep in sync with UI counter).
  static const int maxCommentLength = 2000;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get _uid => AuthService().currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _comments(String reelId) =>
      _firestore.collection('reels').doc(reelId).collection('comments');

  /// Latest-window stream (newest-first in snapshot). Merge with [fetchCommentsOlderThan] in UI.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchRecentCommentsTail(
    String reelId, {
    int limit = recentTailLimit,
  }) {
    return _comments(reelId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Comments strictly older than [oldestLoaded] (used to paginate upward in the thread).
  Future<QuerySnapshot<Map<String, dynamic>>> fetchCommentsOlderThan(
    String reelId,
    QueryDocumentSnapshot<Map<String, dynamic>> oldestLoaded, {
    int limit = olderPageSize,
  }) {
    return _comments(reelId)
        .orderBy('createdAt', descending: true)
        .endBeforeDocument(oldestLoaded)
        .limit(limit)
        .get();
  }

  /// Relative label for UI (e.g. "Just now", "5m", "2d").
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

  /// Build nested [Comment] list from merged doc snapshots (any order).
  Future<List<Comment>> commentsFromDocuments(
    String reelId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) =>
      _snapshotToComments(reelId, docs);

  Future<List<Comment>> _snapshotToComments(
    String reelId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final uid = _uid ?? '';
    final byId = <String, _Node>{};

    for (final d in docs) {
      final data = d.data();
      final parentId = (data['parentId'] as String?)?.trim() ?? '';
      byId[d.id] = _Node(
        id: d.id,
        parentId: parentId,
        data: data,
        createdAt: data['createdAt'] as Timestamp?,
      );
    }

    final childrenOf = <String, List<_Node>>{};
    final roots = <_Node>[];

    for (final n in byId.values) {
      if (n.parentId.isEmpty || !byId.containsKey(n.parentId)) {
        roots.add(n);
      } else {
        childrenOf.putIfAbsent(n.parentId, () => []).add(n);
      }
    }

    int byTime(_Node a, _Node b) {
      final ta = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final tb = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return ta.compareTo(tb);
    }

    roots.sort(byTime);
    for (final list in childrenOf.values) {
      list.sort(byTime);
    }

    final allIds = byId.keys.toList();
    final liked = await _likedCommentIds(reelId, allIds, uid);

    Comment buildTree(_Node n) {
      final kids = childrenOf[n.id] ?? [];
      final replyModels = kids.map(buildTree).toList();
      return _nodeToComment(n, replyModels, liked, uid);
    }

    return roots.map(buildTree).toList();
  }

  Comment _nodeToComment(
    _Node n,
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
    String reelId,
    List<String> commentIds,
    String uid,
  ) async {
    if (uid.isEmpty || commentIds.isEmpty) return {};
    final snaps = await Future.wait(
      commentIds.map(
        (id) => _comments(reelId).doc(id).collection('likes').doc(uid).get(),
      ),
    );
    final out = <String>{};
    for (var i = 0; i < commentIds.length; i++) {
      if (snaps[i].exists) out.add(commentIds[i]);
    }
    return out;
  }

  /// Threading: at most one level under a root — replying to a reply attaches under the root.
  Future<String> _effectiveParentId(String reelId, String rawParentId) async {
    final p = rawParentId.trim();
    if (p.isEmpty) return '';
    final doc = await _comments(reelId).doc(p).get();
    if (!doc.exists) return '';
    final parentOfParent =
        (doc.data()?['parentId'] as String?)?.trim() ?? '';
    if (parentOfParent.isNotEmpty) return parentOfParent;
    return p;
  }

  Future<void> addComment(
    String reelId,
    String text, {
    String parentId = '',
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > maxCommentLength) return;

    final effectiveParent = await _effectiveParentId(reelId, parentId);

    var username = AuthService().currentUser?.displayName ?? '';
    var avatarUrl = AuthService().currentUser?.photoURL ?? '';
    if (username.isEmpty) {
      username =
          AuthService().currentUser?.email?.split('@').first ?? 'User';
    }
    try {
      final u = await UserService().getUser(uid);
      if (u != null) {
        if ((u.username ?? '').isNotEmpty) username = u.username!;
        if ((u.profileImage ?? '').isNotEmpty) avatarUrl = u.profileImage!;
      }
    } catch (_) {}

    final batch = _firestore.batch();
    final commentRef = _comments(reelId).doc();
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

    final reelRef = _firestore.collection('reels').doc(reelId);
    batch.set(
      reelRef,
      {'comments': FieldValue.increment(1)},
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  /// Deletes subtree; returns number of comment documents removed (for feed count).
  Future<int> deleteComment(String reelId, String commentId) async {
    final uid = _uid;
    if (uid == null) return 0;

    final ref = _comments(reelId).doc(commentId);
    final snap = await ref.get();
    if (!snap.exists) return 0;
    final authorId = snap.data()?['userId'] as String? ?? '';
    if (authorId != uid) return 0;

    final subtreeIds = await _collectSubtreeIds(reelId, commentId);
    final batch = _firestore.batch();
    for (final id in subtreeIds) {
      batch.delete(_comments(reelId).doc(id));
    }
    final reelRef = _firestore.collection('reels').doc(reelId);
    batch.set(
      reelRef,
      {'comments': FieldValue.increment(-subtreeIds.length)},
      SetOptions(merge: true),
    );
    await batch.commit();
    return subtreeIds.length;
  }

  Future<List<String>> _collectSubtreeIds(String reelId, String rootId) async {
    final all = await _comments(reelId).get();
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
    String reelId,
    String commentId,
    bool currentlyLiked,
  ) async {
    final uid = _uid;
    if (uid == null) return;

    final likeRef =
        _comments(reelId).doc(commentId).collection('likes').doc(uid);
    final commentRef = _comments(reelId).doc(commentId);
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
    required String reelId,
    required String commentId,
    required String commentAuthorId,
    required String reason,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _firestore.collection('comment_reports').add({
      'reelId': reelId,
      'commentId': commentId,
      'commentAuthorId': commentAuthorId,
      'reporterId': uid,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

class _Node {
  _Node({
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
