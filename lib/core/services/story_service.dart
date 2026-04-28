import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/story_model.dart';

/// Handles all story Firestore + Storage operations.
/// Stories expire 24 h after upload. Filtering is done client-side to avoid
/// composite-index requirements.
class StoryService {
  StoryService._();
  static final StoryService _instance = StoryService._();
  factory StoryService() => _instance;

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;

  static const String _col = 'stories';

  String? get _uid => _auth.currentUser?.uid;

  // ── Upload ────────────────────────────────────────────────────────────────

  /// Uploads [image] to Firebase Storage, saves story doc to Firestore.
  Future<void> uploadStory({
    required File image,
    required String caption,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    final now = DateTime.now();
    final filename = '${uid}_${now.millisecondsSinceEpoch}.jpg';

    // Upload image
    // Storage rules allow writes only under users/{uid}/...
    final ref = _storage.ref().child('users/$uid/stories/$filename');
    await ref.putFile(image);
    final mediaUrl = await ref.getDownloadURL();

    // Fetch user profile for username / avatar
    final userDoc = await _db.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    final username = userData['username'] as String? ?? '';
    final avatarUrl = userData['profileImage'] as String? ?? '';

    await _db.collection(_col).add({
      'userId': uid,
      'username': username,
      'avatarUrl': avatarUrl,
      'mediaUrl': mediaUrl,
      'caption': caption,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.add(const Duration(hours: 24))),
      'viewedBy': <String>[],
    });
  }

  // ── Fetch ─────────────────────────────────────────────────────────────────

  /// Returns all active (non-expired) story groups sorted newest-first.
  /// Groups stories by userId. Single-field where clause = no composite index.
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

      // Group by userId
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

  /// Returns the current user's own active stories, sorted oldest-first.
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

  /// Uploads multiple [images] as separate story docs with a shared [caption].
  Future<void> uploadMultipleStories({
    required List<File> images,
    required String caption,
  }) async {
    for (final image in images) {
      await uploadStory(image: image, caption: caption);
    }
  }

  // ── Interactions ──────────────────────────────────────────────────────────

  /// Marks a story as viewed by the current user (arrayUnion, idempotent).
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
