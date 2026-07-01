import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/deep_link_config.dart';
import '../models/reel_media_item.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import '../utils/reel_engagement.dart';

/// Controller for reel interactions. No UI logic here.
///
/// **Favorites** (`users/{uid}/favoriteReels`): public on profile; updates `reels.saves`.
/// **Private saves** (`users/{uid}/privateSavedReels`): only the owner can read; never shown on others' profiles.
/// **Reposts** (`userReposts/{uid}_{sourceReelId}`): profile repost index; stub reel in `reels` with `isRepost`.
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

  static String _userRepostDocId(String uid, String sourceReelId) =>
      '${uid}_$sourceReelId';

  DocumentReference<Map<String, dynamic>> _userRepostDoc(
    String uid,
    String sourceReelId,
  ) =>
      _firestore
          .collection('userReposts')
          .doc(_userRepostDocId(uid, sourceReelId));

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
          'title': data['title'] as String? ?? '',
          'description': data['description'] as String? ?? '',
          'tags': data['tags'] is List
              ? (data['tags'] as List).map((e) => e.toString()).toList()
              : const <String>[],
          'thumbnailUrl': data['thumbnailUrl'] as String? ?? '',
          'imageUrl': data['imageUrl'] as String? ?? '',
          'mediaType': data['mediaType'] as String? ?? '',
          'mediaItems': ReelMediaItem.sanitizedRawList(data['mediaItems']),
          'mediaCount': (data['mediaCount'] as num?)?.toInt() ?? 1,
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

  /// Sets like state for a reel. Idempotent — repeated likes/unlikes are no-ops.
  Future<bool> likeReel({
    required String reelId,
    required bool like,
  }) async {
    final uid = _currentUserId;
    if (uid == null) {
      debugPrint('[Vyooo][Like] abort: no signed-in user wantLike=$like reelId=$reelId');
      return !like;
    }

    final likeRef = _firestore.collection('userLikes').doc('${uid}_$reelId');
    final reelRef = _firestore.collection('reels').doc(reelId);
    debugPrint(
      '[Vyooo][Like] start uid=$uid reelId=$reelId wantLike=$like '
      'likeDoc=${likeRef.id}',
    );

    late final bool liked;
    late final bool changed;
    try {
      (liked, changed) = await _firestore.runTransaction<(bool, bool)>(
        (tx) async {
          final likeSnap = await tx.get(likeRef);
          final isLiked = likeSnap.exists;
          debugPrint(
            '[Vyooo][Like] tx read isLiked=$isLiked wantLike=$like reelId=$reelId',
          );
          if (like == isLiked) {
            return (isLiked, false);
          }

          if (like) {
            tx.set(likeRef, {
              'userId': uid,
              'reelId': reelId,
              'likedAt': FieldValue.serverTimestamp(),
            });
          } else {
            tx.delete(likeRef);
          }

          // `reels/{id}.likes` is maintained by Cloud Function `syncReelLikeCount`.
          return (like, true);
        },
      );
      debugPrint(
        '[Vyooo][Like] tx ok liked=$liked changed=$changed reelId=$reelId',
      );
    } catch (e, st) {
      if (e is FirebaseException) {
        debugPrint(
          '[Vyooo][Like] tx FAILED reelId=$reelId code=${e.code} '
          'message=${e.message}',
        );
      } else {
        debugPrint('[Vyooo][Like] tx FAILED reelId=$reelId error=$e');
      }
      debugPrint('$st');
      try {
        final snap = await likeRef.get();
        final exists = snap.exists;
        debugPrint(
          '[Vyooo][Like] tx fallback likeDoc exists=$exists reelId=$reelId',
        );
        return exists;
      } catch (readErr) {
        debugPrint(
          '[Vyooo][Like] tx fallback read FAILED reelId=$reelId error=$readErr',
        );
        return !like;
      }
    }

    if (changed && liked) {
      unawaited(_notifyPostLike(reelRef: reelRef, reelId: reelId, uid: uid));
    }

    debugPrint('[Vyooo][Like] done return liked=$liked reelId=$reelId');
    return liked;
  }

  Future<void> _notifyPostLike({
    required DocumentReference<Map<String, dynamic>> reelRef,
    required String reelId,
    required String uid,
  }) async {
    try {
      final reelDoc = await reelRef.get();
      if (!reelDoc.exists) return;
      final ownerId = (reelDoc.data()?['userId'] as String?) ?? '';
      if (ownerId.isEmpty || ownerId == uid) return;
      final sent = await NotificationService().createOnce(
        dedupeId: 'like_${uid}_$reelId',
        recipientId: ownerId,
        type: AppNotificationType.like,
        message: 'liked your post.',
        extra: {'reelId': reelId},
      );
      debugPrint(
        '[Vyooo][Like] notify sent=$sent ownerId=$ownerId reelId=$reelId',
      );
    } catch (e, st) {
      debugPrint('[Vyooo][Like] notify FAILED reelId=$reelId error=$e');
      debugPrint('$st');
    }
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

  /// Source reel ids the current user has reposted to their profile.
  Future<Set<String>> getRepostedSourceReelIds(Set<String> sourceReelIds) async {
    final uid = _currentUserId;
    if (uid == null || sourceReelIds.isEmpty) return <String>{};
    try {
      final out = <String>{};
      for (final sourceId in sourceReelIds) {
        final snap = await _userRepostDoc(uid, sourceId).get();
        if (snap.exists) out.add(sourceId);
      }
      return out;
    } catch (_) {
      return <String>{};
    }
  }

  /// Repost a post to the signed-in user's profile. Returns new repost stub id or null.
  Future<String?> repostReel({required String sourceReelId}) async {
    final uid = _currentUserId;
    final sourceId = sourceReelId.trim();
    if (uid == null || sourceId.isEmpty) return null;

    try {
      final sourceSnap =
          await _firestore.collection('reels').doc(sourceId).get();
      if (!sourceSnap.exists) return null;
      final source = sourceSnap.data() ?? {};
      final ownerId = (source['userId'] as String?)?.trim() ?? '';
      if (ownerId.isEmpty || ownerId == uid) return null;

      final existing = await _userRepostDoc(uid, sourceId).get();
      if (existing.exists) {
        return (existing.data()?['repostReelId'] as String?)?.trim();
      }

      final user = await UserService().getUser(uid);
      final username = (user?.username ?? '').trim().isNotEmpty
          ? user!.username!.trim()
          : (AuthService().currentUser?.displayName ?? 'User');
      final profileImage = (user?.profileImage ?? '').trim();
      final handle = '@${username.replaceAll(' ', '_')}';
      final accountType = user?.accountType ?? 'private';
      final authorAccountPrivate =
          UserService.accountTypeRequiresFollowApproval(accountType);

      final ownerUsername = (source['username'] as String?)?.trim() ?? 'User';
      final ownerHandle = (source['handle'] as String?)?.trim() ?? '';

      final repostRef = _firestore.collection('reels').doc();
      final batch = _firestore.batch();

      batch.set(repostRef, {
        'isRepost': true,
        'repostOf': sourceId,
        'repostOfUserId': ownerId,
        'repostOfUsername': ownerUsername,
        'repostOfHandle': ownerHandle,
        'mediaType': source['mediaType'] ?? 'video',
        'videoUrl': source['videoUrl'] ?? '',
        'imageUrl': source['imageUrl'] ?? '',
        'thumbnailUrl': source['thumbnailUrl'] ?? source['imageUrl'] ?? '',
        if (source['mediaItems'] is List)
          'mediaItems': source['mediaItems'],
        if (source['mediaCount'] is num) 'mediaCount': source['mediaCount'],
        'caption': source['caption'] ?? '',
        'description': source['description'] ?? '',
        'title': source['title'] ?? '',
        'tags': source['tags'] is List ? source['tags'] : <String>[],
        'userId': uid,
        'username': username,
        'handle': handle,
        'avatarUrl': profileImage,
        'profileImage': profileImage,
        'likes': 0,
        'comments': 0,
        'saves': 0,
        'views': 0,
        'viewsCount': 0,
        'reposts': 0,
        'shares': 0,
        'isVR': false,
        'authorAccountPrivate': authorAccountPrivate,
        'createdAt': FieldValue.serverTimestamp(),
        'moderation': source['moderation'],
      });

      batch.set(_userRepostDoc(uid, sourceId), {
        'userId': uid,
        'sourceReelId': sourceId,
        'repostReelId': repostRef.id,
        'repostedAt': FieldValue.serverTimestamp(),
      });

      batch.update(_firestore.collection('reels').doc(sourceId), {
        'reposts': FieldValue.increment(1),
        'shares': FieldValue.increment(1),
      });

      await batch.commit();

      await NotificationService().create(
        recipientId: ownerId,
        type: AppNotificationType.repost,
        message: 'reposted your post.',
        extra: {'reelId': sourceId, 'repostReelId': repostRef.id},
      );

      return repostRef.id;
    } catch (e, st) {
      debugPrint('[Vyooo][repostReel] FAILED source=$sourceId error=$e');
      debugPrint('$st');
      return null;
    }
  }

  /// Remove a repost from the current user's profile.
  Future<bool> unrepostReel({required String sourceReelId}) async {
    final uid = _currentUserId;
    final sourceId = sourceReelId.trim();
    if (uid == null || sourceId.isEmpty) return false;

    try {
      final repostMeta = await _userRepostDoc(uid, sourceId).get();
      if (!repostMeta.exists) return false;
      final stubId =
          (repostMeta.data()?['repostReelId'] as String?)?.trim() ?? '';

      final batch = _firestore.batch();
      batch.delete(_userRepostDoc(uid, sourceId));
      if (stubId.isNotEmpty) {
        batch.delete(_firestore.collection('reels').doc(stubId));
      }
      batch.update(_firestore.collection('reels').doc(sourceId), {
        'reposts': FieldValue.increment(-1),
        'shares': FieldValue.increment(-1),
      });
      await batch.commit();
      return true;
    } catch (e, st) {
      debugPrint('[Vyooo][unrepostReel] FAILED source=$sourceId error=$e');
      debugPrint('$st');
      return false;
    }
  }

  /// Increment view count.
  Future<void> incrementView({required String reelId}) async {
    final uid = _currentUserId;
    if (uid == null) return;
    try {
      await _firestore.collection('reels').doc(reelId).update({
        'views': FieldValue.increment(1),
        // Keep viewsCount in sync so Trending (orderBy viewsCount) and the
        // report-threshold moderation use a consistent live view total.
        'viewsCount': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  /// Share a reel using native share sheet.
  Future<void> shareReel({
    required String reelId,
    String? caption,
  }) async {
    try {
      final reelDoc = await _firestore.collection('reels').doc(reelId).get();
      final data = reelDoc.data();
      final resolvedCaption = (caption ?? data?['caption'] as String?)?.trim();
      final message = DeepLinkConfig.reelShareMessage(
        reelId: reelId,
        caption: resolvedCaption,
      );
      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: 'Check out this post on Vyooo',
        ),
      );
      final ownerId = (data?['userId'] as String?) ?? '';
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
