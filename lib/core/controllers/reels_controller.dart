import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../config/deep_link_config.dart';
import '../services/auth_service.dart';

/// Controller for reel interactions. No UI logic here.
/// UI calls these methods for like, save, share, comment.
class ReelsController {
  ReelsController._();
  static final ReelsController _instance = ReelsController._();
  factory ReelsController() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? get _currentUserId => AuthService().currentUser?.uid;

  Future<Set<String>> getLikedReelIds(Set<String> reelIds) async {
    final uid = _currentUserId;
    if (uid == null || reelIds.isEmpty) return <String>{};
    try {
      final q = await _firestore
          .collection('userLikes')
          .where('userId', isEqualTo: uid)
          .get();
      final liked = <String>{};
      for (final d in q.docs) {
        final reelId = (d.data()['reelId'] as String?) ?? '';
        if (reelId.isNotEmpty && reelIds.contains(reelId)) liked.add(reelId);
      }
      return liked;
    } catch (_) {
      return <String>{};
    }
  }

  Future<Set<String>> getSavedReelIds(Set<String> reelIds) async {
    final uid = _currentUserId;
    if (uid == null || reelIds.isEmpty) return <String>{};
    try {
      final q = await _firestore
          .collection('userSaves')
          .where('userId', isEqualTo: uid)
          .get();
      final saved = <String>{};
      for (final d in q.docs) {
        final reelId = (d.data()['reelId'] as String?) ?? '';
        if (reelId.isNotEmpty && reelIds.contains(reelId)) saved.add(reelId);
      }
      return saved;
    } catch (_) {
      return <String>{};
    }
  }

  /// Aggregate saved counts for the provided reels from `userSaves`.
  Future<Map<String, int>> getSaveCountsByReelIds(Set<String> reelIds) async {
    if (reelIds.isEmpty) return <String, int>{};
    final counts = <String, int>{};
    try {
      final ids = reelIds.toList();
      for (var i = 0; i < ids.length; i += 10) {
        final chunk = ids.sublist(
          i,
          (i + 10) > ids.length ? ids.length : (i + 10),
        );
        final q = await _firestore
            .collection('userSaves')
            .where('reelId', whereIn: chunk)
            .get();
        for (final d in q.docs) {
          final reelId = (d.data()['reelId'] as String?) ?? '';
          if (reelId.isEmpty) continue;
          counts[reelId] = (counts[reelId] ?? 0) + 1;
        }
      }
    } catch (_) {
      return <String, int>{};
    }
    return counts;
  }

  /// Like a reel. Toggles like state and updates Firestore.
  /// Optimistic UI: return new liked state immediately.
  Future<bool> likeReel({
    required String reelId,
    required bool currentlyLiked,
  }) async {
    final uid = _currentUserId;
    if (uid == null) return currentlyLiked;

    final newLikedState = !currentlyLiked;
    try {
      // Keep per-user like source of truth even if the reel is from fallback feeds.
      if (newLikedState) {
        await _firestore.collection('userLikes').doc('${uid}_$reelId').set({
          'userId': uid,
          'reelId': reelId,
          'likedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _firestore.collection('userLikes').doc('${uid}_$reelId').delete();
      }

      // Best effort aggregate counter update for Firestore-backed reels.
      final reelRef = _firestore.collection('reels').doc(reelId);
      final reelDoc = await reelRef.get();
      if (reelDoc.exists) {
        await reelRef.update({
          'likes': newLikedState
              ? FieldValue.increment(1)
              : FieldValue.increment(-1),
        });
      }
    } catch (_) {
      return currentlyLiked;
    }
    return newLikedState;
  }

  /// Save a reel. Toggles save state and updates Firestore.
  Future<bool> saveReel({
    required String reelId,
    required bool currentlySaved,
  }) async {
    final uid = _currentUserId;
    if (uid == null) return currentlySaved;

    final newSavedState = !currentlySaved;
    try {
      if (newSavedState) {
        await _firestore
            .collection('userSaves')
            .doc('${uid}_$reelId')
            .set({'userId': uid, 'reelId': reelId, 'savedAt': FieldValue.serverTimestamp()});
      } else {
        await _firestore.collection('userSaves').doc('${uid}_$reelId').delete();
      }

      // Best effort aggregate counter update for Firestore-backed reels.
      final reelRef = _firestore.collection('reels').doc(reelId);
      final reelDoc = await reelRef.get();
      if (reelDoc.exists) {
        await reelRef.update({
          'saves': newSavedState
              ? FieldValue.increment(1)
              : FieldValue.increment(-1),
        });
      }
    } catch (_) {}
    return newSavedState;
  }

  /// Increment view count. Call when reel becomes visible.
  /// Do NOT increment on client directly; use Cloud Function or backend trigger.
  /// For now, writes to Firestore; in production use a Cloud Function.
  Future<void> incrementView({required String reelId}) async {
    final uid = _currentUserId;
    if (uid == null) return;
    try {
      await _firestore.collection('reels').doc(reelId).update({
        'views': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  /// Share a reel using native share sheet.
  Future<void> shareReel({
    required String reelId,
    String? reelUrl,
  }) async {
    try {
      final url = reelUrl ?? DeepLinkConfig.reelWebUri(reelId).toString();
      await Share.share(url, subject: 'Check out this reel on Vyooo!');
    } on PlatformException catch (_) {
      // Share cancelled or unavailable
    } catch (_) {}
  }

  /// Open comment bottom sheet. Implementation in UI.
  /// This method is a placeholder; the actual UI calls the comment sheet.
  void openComments({required String reelId}) {
    // UI handles opening the comment bottom sheet
  }
}
