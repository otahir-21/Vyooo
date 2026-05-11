import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/story_highlight_model.dart';
import '../models/story_model.dart';
import 'notification_service.dart';
import 'user_service.dart';

/// Handles story Firestore + Storage, likes, highlights.
/// Stories expire 24 h after upload. Filtering avoids composite-index requirements.
class StoryService {
  StoryService._();
  static final StoryService _instance = StoryService._();
  factory StoryService() => _instance;

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;

  static const String _col = 'stories';
  static const String _likesCol = 'storyLikes';

  String? get _uid => _auth.currentUser?.uid;

  // ── Upload ────────────────────────────────────────────────────────────────

  /// Uploads [image] (JPEG/PNG…) to Storage, saves story doc.
  Future<void> uploadStory({
    required File image,
    required String caption,
    String segmentGroupId = '',
  }) async {
    return uploadStoryMedia(
      file: image,
      mediaType: StoryMediaType.image,
      caption: caption,
      durationMs: 0,
      segmentGroupId: segmentGroupId,
    );
  }

  /// Uploads image or video story segment.
  Future<void> uploadStoryMedia({
    required File file,
    required StoryMediaType mediaType,
    required String caption,
    int durationMs = 0,
    String segmentGroupId = '',
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    final now = DateTime.now();
    final ext = mediaType == StoryMediaType.video ? 'mp4' : 'jpg';
    final filename =
        '${uid}_${now.millisecondsSinceEpoch}_${Random().nextInt(1 << 30)}.$ext';

    final ref = _storage.ref().child('users/$uid/stories/$filename');
    await ref.putFile(file);
    final mediaUrl = await ref.getDownloadURL();

    final userDoc = await _db.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    final username = userData['username'] as String? ?? '';
    final avatarUrl = userData['profileImage'] as String? ?? '';
    final accountType = (userData['accountType'] as String?) ?? 'private';
    final authorAccountPrivate =
        UserService.accountTypeRequiresFollowApproval(accountType);

    await _db.collection(_col).add({
      'userId': uid,
      'username': username,
      'avatarUrl': avatarUrl,
      'mediaUrl': mediaUrl,
      'caption': caption,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.add(const Duration(hours: 24))),
      'viewedBy': <String>[],
      'mediaType': mediaType == StoryMediaType.video ? 'video' : 'image',
      'durationMs': durationMs,
      'likes': 0,
      'comments': 0,
      'segmentGroupId': segmentGroupId,
      'authorAccountPrivate': authorAccountPrivate,
    });
  }

  /// Multiple image stories (legacy) with shared [caption].
  Future<void> uploadMultipleStories({
    required List<File> images,
    required String caption,
  }) async {
    final group = DateTime.now().microsecondsSinceEpoch.toString();
    for (final image in images) {
      await uploadStory(
        image: image,
        caption: caption,
        segmentGroupId: images.length > 1 ? group : '',
      );
    }
  }

  /// Uploads several media files (e.g. FFmpeg-split video segments) with one [segmentGroupId].
  Future<void> uploadStoryMediaBatch({
    required List<File> files,
    required StoryMediaType mediaType,
    required String caption,
    required List<int> durationMsPerFile,
    required String segmentGroupId,
  }) async {
    if (files.length != durationMsPerFile.length) {
      throw ArgumentError('files and durationMsPerFile length mismatch');
    }
    for (var i = 0; i < files.length; i++) {
      await uploadStoryMedia(
        file: files[i],
        mediaType: mediaType,
        caption: caption,
        durationMs: durationMsPerFile[i],
        segmentGroupId: segmentGroupId,
      );
    }
  }

  // ── Fetch ─────────────────────────────────────────────────────────────────

  Future<List<StoryGroup>> getActiveStoryGroups() async {
    try {
      final now = Timestamp.now();
      final snap = await _db
          .collection(_col)
          .where('expiresAt', isGreaterThan: now)
          .get();

      final stories = snap.docs
          .map((d) => StoryModel.fromFirestore(d))
          .where((s) => !s.isExpired)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final Map<String, List<StoryModel>> map = {};
      for (final s in stories) {
        map.putIfAbsent(s.userId, () => []).add(s);
      }

      final groups = map.entries
          .map((e) => StoryGroup(
                userId: e.key,
                username: e.value.last.username,
                avatarUrl: e.value.last.avatarUrl,
                stories: e.value,
              ))
          .toList()
        ..sort((a, b) => b.stories.last.createdAt
            .compareTo(a.stories.last.createdAt));

      return groups;
    } catch (e) {
      debugPrint('StoryService.getActiveStoryGroups: $e');
      return [];
    }
  }

  Future<List<StoryModel>> getMyStories() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final snap =
          await _db.collection(_col).where('userId', isEqualTo: uid).get();
      final now = DateTime.now();
      return snap.docs
          .map((d) => StoryModel.fromFirestore(d))
          .where((s) => s.expiresAt.isAfter(now))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } catch (e) {
      debugPrint('StoryService.getMyStories: $e');
      return [];
    }
  }

  // ── Likes ─────────────────────────────────────────────────────────────────

  Future<Set<String>> getLikedStoryIds(Set<String> storyIds) async {
    final uid = _uid;
    if (uid == null || storyIds.isEmpty) return <String>{};
    try {
      final q = await _db
          .collection(_likesCol)
          .where('userId', isEqualTo: uid)
          .get();
      final liked = <String>{};
      for (final d in q.docs) {
        final sid = (d.data()['storyId'] as String?) ?? '';
        if (sid.isNotEmpty && storyIds.contains(sid)) liked.add(sid);
      }
      return liked;
    } catch (_) {
      return <String>{};
    }
  }

  /// Toggles like; returns new liked state.
  Future<bool> toggleStoryLike({
    required String storyId,
    required bool currentlyLiked,
  }) async {
    final uid = _uid;
    if (uid == null) return currentlyLiked;

    final newState = !currentlyLiked;
    try {
      final likeDoc = _db.collection(_likesCol).doc('${uid}_$storyId');
      final storyRef = _db.collection(_col).doc(storyId);

      if (newState) {
        await likeDoc.set({
          'userId': uid,
          'storyId': storyId,
          'likedAt': FieldValue.serverTimestamp(),
        });
        // `likes` on the story doc is maintained by Cloud Function `syncStoryLikeCount`.

        final storySnap = await storyRef.get();
        final ownerId = (storySnap.data()?['userId'] as String?) ?? '';
        if (ownerId.isNotEmpty && ownerId != uid) {
          await NotificationService().create(
            recipientId: ownerId,
            type: AppNotificationType.like,
            message: 'liked your story.',
            extra: {'storyId': storyId},
          );
        }
      } else {
        await likeDoc.delete();
      }
    } catch (_) {
      return currentlyLiked;
    }
    return newState;
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteStory(String storyId) async {
    final uid = _uid;
    if (uid == null) return;
    final ref = _db.collection(_col).doc(storyId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data() ?? {};
    if (data['userId'] != uid) return;

    final mediaUrl = data['mediaUrl'] as String? ?? '';
    if (mediaUrl.isNotEmpty) {
      try {
        await _storage.refFromURL(mediaUrl).delete();
      } catch (_) {}
    }

    await ref.delete();
    try {
      final likes = await _db
          .collection(_likesCol)
          .where('storyId', isEqualTo: storyId)
          .get();
      for (final d in likes.docs) {
        await d.reference.delete();
      }
    } catch (_) {}
  }

  // ── Highlights (persist on profile) ───────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _highlightsCol(String userId) =>
      _db.collection('users').doc(userId).collection('storyHighlights');

  CollectionReference<Map<String, dynamic>> _highlightItemsCol(
    String userId,
    String highlightId,
  ) =>
      _highlightsCol(userId).doc(highlightId).collection('items');

  Future<List<StoryHighlightModel>> getHighlightsForUser(String userId) async {
    try {
      final snap = await _highlightsCol(userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      return snap.docs.map(StoryHighlightModel.fromDoc).toList();
    } catch (e) {
      debugPrint('StoryService.getHighlightsForUser: $e');
      return [];
    }
  }

  /// Live updates when highlights are added/removed (e.g. after returning from story viewer).
  Stream<List<StoryHighlightModel>> watchHighlightsForUser(String userId) {
    if (userId.isEmpty) {
      return Stream<List<StoryHighlightModel>>.value(const []);
    }
    return _highlightsCol(userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(StoryHighlightModel.fromDoc).toList());
  }

  Future<String> createHighlight(String title) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw Exception('Title required');
    final ref = await _highlightsCol(uid).add({
      'userId': uid,
      'title': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
      'coverMediaUrl': '',
    });
    return ref.id;
  }

  Future<void> addStoryToHighlight({
    required String highlightId,
    required StoryModel story,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');
    if (story.userId != uid) throw Exception('Not your story');

    final items = _highlightItemsCol(uid, highlightId);
    final existing = await items.orderBy('order', descending: true).limit(1).get();
    final nextOrder = existing.docs.isEmpty
        ? 0
        : ((existing.docs.first.data()['order'] as num?)?.toInt() ?? 0) + 1;

    final itemRef = items.doc();
    await itemRef.set({
      'mediaUrl': story.mediaUrl,
      'isVideo': story.isVideo,
      'caption': story.caption,
      'order': nextOrder,
      'sourceStoryId': story.id,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _highlightsCol(uid).doc(highlightId).set({
      'coverMediaUrl': story.mediaUrl,
    }, SetOptions(merge: true));
  }

  Future<List<StoryHighlightItem>> getHighlightItems({
    required String userId,
    required String highlightId,
  }) async {
    final snap = await _highlightItemsCol(userId, highlightId)
        .orderBy('order')
        .get();
    return snap.docs
        .map((d) => StoryHighlightItem.fromMap(d.id, d.data()))
        .toList();
  }

  // ── Views ─────────────────────────────────────────────────────────────────

  Future<void> markViewed(String storyId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.collection(_col).doc(storyId).update({
        'viewedBy': FieldValue.arrayUnion([uid]),
      });
    } catch (_) {}
  }
}
