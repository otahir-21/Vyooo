import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/deep_link_config.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

/// Controller for reel interactions. No UI logic here.
///
/// **Favorites** (`users/{uid}/favoriteReels`): public on profile; updates `reels.saves`.
/// **Private saves** (`users/{uid}/privateSavedReels`): only the owner can read; never shown on others' profiles.
class ReelsController {
  ReelsController._();
  static final ReelsController _instance = ReelsController._();
  factory ReelsController() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? get _currentUserId => AuthService().currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _favoriteCol(String uid) =>
      _userDoc(uid).collection('favoriteReels');

  CollectionReference<Map<String, dynamic>> _privateSavedCol(String uid) =>
      _userDoc(uid).collection('privateSavedReels');

  /// One-time: moves legacy `userSaves` into [privateSavedReels] and deletes legacy docs.
  Future<void> migrateLegacyUserSavesIfNeeded() async {
    final uid = _currentUserId;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('legacy_user_saves_migrated_v1') == true) return;
    try {
      final legacy = await _firestore
          .collection('userSaves')
          .where('userId', isEqualTo: uid)
          .get();
      const chunk = 400;
      for (var i = 0; i < legacy.docs.length; i += chunk) {
        final slice = legacy.docs.sublist(
          i,
          (i + chunk) > legacy.docs.length ? legacy.docs.length : (i + chunk),
        );
        final batch = _firestore.batch();
        for (final d in slice) {
          final reelId = (d.data()['reelId'] as String?)?.trim() ?? '';
          if (reelId.isEmpty) continue;
          batch.set(
            _privateSavedCol(uid).doc(reelId),
            {
              'reelId': reelId,
              'savedAt': d.data()['savedAt'] ?? FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
          batch.delete(d.reference);
        }
        await batch.commit();
      }
      await prefs.setBool('legacy_user_saves_migrated_v1', true);
    } catch (_) {
      // Leave flag unset so a later app launch can retry.
    }
  }

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

  Future<Set<String>> getFavoriteReelIds(Set<String> reelIds) async {
    final uid = _currentUserId;
    if (uid == null || reelIds.isEmpty) return <String>{};
    try {
      final snap = await _favoriteCol(uid).get();
      final out = <String>{};
      for (final d in snap.docs) {
        if (reelIds.contains(d.id)) out.add(d.id);
      }
      return out;
    } catch (e, st) {
      if (e is FirebaseException) {
        debugPrint(
          '[Vyooo][getFavoriteReelIds] FirebaseException code=${e.code} '
          'message=${e.message}',
        );
      }
      debugPrint('[Vyooo][getFavoriteReelIds] FAILED uid=$uid error=$e');
      debugPrint('$st');
      return <String>{};
    }
  }

  Future<Set<String>> getPrivateSavedReelIds(Set<String> reelIds) async {
    final uid = _currentUserId;
    if (uid == null || reelIds.isEmpty) return <String>{};
    try {
      final snap = await _privateSavedCol(uid).get();
      final out = <String>{};
      for (final d in snap.docs) {
        if (reelIds.contains(d.id)) out.add(d.id);
      }
      return out;
    } catch (e, st) {
      if (e is FirebaseException) {
        debugPrint(
          '[Vyooo][getPrivateSavedReelIds] FirebaseException code=${e.code} '
          'message=${e.message}',
        );
      }
      debugPrint('[Vyooo][getPrivateSavedReelIds] FAILED uid=$uid error=$e');
      debugPrint('$st');
      return <String>{};
    }
  }

  /// Favorites for profile grid (any [userId] the rules allow the viewer to read).
  Future<List<Map<String, dynamic>>> fetchFavoriteReelsForProfile(
    String userId,
  ) async {
    final uid = userId.trim();
    if (uid.isEmpty) return <Map<String, dynamic>>[];
    try {
      final snap = await _favoriteCol(uid).get();
      final docs = snap.docs.toList()
        ..sort((a, b) {
          int epoch(QueryDocumentSnapshot<Map<String, dynamic>> d) {
            final ts = d.data()['favoritedAt'];
            return ts is Timestamp ? ts.millisecondsSinceEpoch : 0;
          }

          return epoch(b).compareTo(epoch(a));
        });
      return _hydrateReelGridMapsFromDocs(docs);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  /// Private saves — only call for the signed-in user's own library.
  Future<List<Map<String, dynamic>>> fetchPrivateSavedReelsForCurrentUser() async {
    final uid = _currentUserId;
    if (uid == null) return <Map<String, dynamic>>[];
    try {
      final snap = await _privateSavedCol(uid).get();
      final docs = snap.docs.toList()
        ..sort((a, b) {
          int epoch(QueryDocumentSnapshot<Map<String, dynamic>> d) {
            final ts = d.data()['savedAt'];
            return ts is Timestamp ? ts.millisecondsSinceEpoch : 0;
          }

          return epoch(b).compareTo(epoch(a));
        });
      return _hydrateReelGridMapsFromDocs(docs);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> _hydrateReelGridMapsFromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> orderedDocs,
  ) async {
    if (orderedDocs.isEmpty) return <Map<String, dynamic>>[];
    final reelIdsOrdered = orderedDocs.map((d) => d.id).toList();
    final saveMeta = <String, int>{};
    for (final d in orderedDocs) {
      final ts = d.data()['favoritedAt'] ?? d.data()['savedAt'];
      final epoch = ts is Timestamp ? ts.millisecondsSinceEpoch : 0;
      saveMeta[d.id] = epoch;
    }

    final reelsById = <String, Map<String, dynamic>>{};
    for (var i = 0; i < reelIdsOrdered.length; i += 10) {
      final chunk = reelIdsOrdered.sublist(
        i,
        (i + 10) > reelIdsOrdered.length ? reelIdsOrdered.length : (i + 10),
      );
      final q = await _firestore
          .collection('reels')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in q.docs) {
        final data = doc.data();
        reelsById[doc.id] = {
          'id': doc.id,
          'userId': data['userId'] as String? ?? '',
          'videoUrl': data['videoUrl'] as String? ?? '',
          'caption': data['caption'] as String? ?? '',
          'thumbnailUrl': data['thumbnailUrl'] as String? ?? '',
          'imageUrl': data['imageUrl'] as String? ?? '',
          'mediaType': data['mediaType'] as String? ?? '',
          'username': data['username'] as String? ?? '',
          'avatarUrl': data['profileImage'] as String? ??
              data['avatarUrl'] as String? ??
              '',
          'isVerified': data['isVerified'] == true,
          'createdAt': data['createdAt'],
        };
      }
    }

    final out = <Map<String, dynamic>>[];
    for (final id in reelIdsOrdered) {
      final reel = reelsById[id];
      if (reel != null) out.add(reel);
    }
    out.sort((a, b) {
      final aTs = saveMeta[a['id']] ?? 0;
      final bTs = saveMeta[b['id']] ?? 0;
      return bTs.compareTo(aTs);
    });
    return out;
  }

  /// Like a reel. Toggles like state and updates Firestore.
  Future<bool> likeReel({
    required String reelId,
    required bool currentlyLiked,
  }) async {
    final uid = _currentUserId;
    if (uid == null) return currentlyLiked;

    final newLikedState = !currentlyLiked;
    try {
      if (newLikedState) {
        await _firestore.collection('userLikes').doc('${uid}_$reelId').set({
          'userId': uid,
          'reelId': reelId,
          'likedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _firestore.collection('userLikes').doc('${uid}_$reelId').delete();
      }

      final reelRef = _firestore.collection('reels').doc(reelId);
      final reelDoc = await reelRef.get();
      if (reelDoc.exists) {
        await reelRef.update({
          'likes': newLikedState
              ? FieldValue.increment(1)
              : FieldValue.increment(-1),
        });
        if (newLikedState) {
          final ownerId = (reelDoc.data()?['userId'] as String?) ?? '';
          await NotificationService().create(
            recipientId: ownerId,
            type: AppNotificationType.like,
            message: 'liked your post.',
            extra: {'reelId': reelId},
          );
        }
      }
    } catch (_) {
      return currentlyLiked;
    }
    return newLikedState;
  }

  /// Public favorite (profile star tab, visible to others per account privacy rules).
  Future<bool> toggleFavoriteReel({
    required String reelId,
    required bool currentlyFavorite,
  }) async {
    final uid = _currentUserId;
    if (uid == null) {
      debugPrint('[Vyooo][toggleFavoriteReel] aborted: no signed-in user');
      return currentlyFavorite;
    }

    final next = !currentlyFavorite;
    try {
      final favRef = _favoriteCol(uid).doc(reelId);
      if (next) {
        await favRef.set({
          'reelId': reelId,
          'favoritedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await favRef.delete();
      }

      final reelRef = _firestore.collection('reels').doc(reelId);
      final reelDoc = await reelRef.get();
      if (reelDoc.exists) {
        await reelRef.update({
          'saves': next
              ? FieldValue.increment(1)
              : FieldValue.increment(-1),
        });
      }
    } catch (e, st) {
      if (e is FirebaseException) {
        debugPrint(
          '[Vyooo][toggleFavoriteReel] FirebaseException code=${e.code} '
          'message=${e.message}',
        );
      }
      debugPrint(
        '[Vyooo][toggleFavoriteReel] FAILED reelId=$reelId uid=$uid '
        'currentlyFavorite=$currentlyFavorite next=$next error=$e',
      );
      debugPrint('$st');
      developer.log(
        'toggleFavoriteReel',
        name: 'Vyooo.ReelsController',
        error: e,
        stackTrace: st,
      );
      return currentlyFavorite;
    }
    return next;
  }

  /// Private bookmark — never increments public counters; never shown on other profiles.
  Future<bool> togglePrivateSavedReel({
    required String reelId,
    required bool currentlySaved,
  }) async {
    final uid = _currentUserId;
    if (uid == null) {
      debugPrint('[Vyooo][togglePrivateSavedReel] aborted: no signed-in user');
      return currentlySaved;
    }

    final next = !currentlySaved;
    try {
      final ref = _privateSavedCol(uid).doc(reelId);
      if (next) {
        await ref.set({
          'reelId': reelId,
          'savedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await ref.delete();
      }
    } catch (e, st) {
      if (e is FirebaseException) {
        debugPrint(
          '[Vyooo][togglePrivateSavedReel] FirebaseException code=${e.code} '
          'message=${e.message}',
        );
      }
      debugPrint(
        '[Vyooo][togglePrivateSavedReel] FAILED reelId=$reelId next=$next error=$e',
      );
      debugPrint('$st');
      developer.log(
        'togglePrivateSavedReel',
        name: 'Vyooo.ReelsController',
        error: e,
        stackTrace: st,
      );
      return currentlySaved;
    }
    return next;
  }

  /// Increment view count.
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
      await SharePlus.instance.share(
        ShareParams(
          text: url,
          subject: 'Check out this reel on Vyooo!',
        ),
      );
      final reelDoc = await _firestore.collection('reels').doc(reelId).get();
      final ownerId = (reelDoc.data()?['userId'] as String?) ?? '';
      await NotificationService().create(
        recipientId: ownerId,
        type: AppNotificationType.share,
        message: 'shared your post.',
        extra: {'reelId': reelId},
      );
    } on PlatformException catch (_) {
      // Share cancelled or unavailable
    } catch (_) {}
  }

  void openComments({required String reelId}) {}
}
