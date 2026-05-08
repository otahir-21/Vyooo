import 'dart:math' show min;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../utils/hashtag_utils.dart';
import '../utils/video_upload_policy.dart';
import 'auth_service.dart';
import 'pexels_feed_service.dart';
import 'user_service.dart';

/// Reels feed by tab. For You / Trending / VR use reels collection; Following uses users/{uid}/following.
/// When Firestore is empty and [AppConfig.usePexelsFeed] + API key are set, falls back to Pexels.
class ReelsService {
  ReelsService._();
  static final ReelsService _instance = ReelsService._();
  factory ReelsService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PexelsFeedService _pexels = PexelsFeedService();
  static const String _reelsCollection = 'reels';

  /// Reels for "For You": orderBy createdAt desc.
  Future<List<Map<String, dynamic>>> getReelsForYou({int limit = 20}) async {
    try {
      final q = await _firestore
          .collection(_reelsCollection)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      final list = q.docs
          .map((d) => _docToReelMap(d))
          .where((r) => _isVisibleToCurrentUser(r) && _isPlayableReel(r))
          .toList();
      if (list.isNotEmpty) return list;
      if (_pexels.isAvailable) return _pexels.getForYou(limit: limit);
      return [];
    } catch (_) {
      if (_pexels.isAvailable) return _pexels.getForYou(limit: limit);
      return [];
    }
  }

  /// Reels from followed users only. Uses users/{uid}/following then reels where userId in that list.
  /// Does not fall back to third-party demo feeds — empty means no reels from people you follow.
  Future<List<Map<String, dynamic>>> getReelsFollowing({int limit = 20}) async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) {
      return [];
    }
    try {
      final followingIds = await UserService().getFollowing(uid);
      if (followingIds.isEmpty) {
        return [];
      }
      // Firestore whereIn supports max 10 IDs — chunk so all followed accounts can contribute.
      final ids = followingIds.where((id) => id.trim().isNotEmpty).toList();
      final list = <Map<String, dynamic>>[];
      const chunkSize = 10;
      for (var i = 0; i < ids.length; i += chunkSize) {
        final chunk = ids.sublist(i, min(i + chunkSize, ids.length));
        final q = await _firestore
            .collection(_reelsCollection)
            .where('userId', whereIn: chunk)
            .limit(limit * 2)
            .get();
        for (final d in q.docs) {
          final r = _docToReelMap(d);
          if (_isVisibleToCurrentUser(r) && _isPlayableReel(r)) {
            list.add(r);
          }
        }
      }
      list.sort((a, b) {
        final aTs = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final bTs = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return bTs.compareTo(aTs);
      });
      if (list.length > limit) {
        return list.take(limit).toList(growable: false);
      }
      if (list.isNotEmpty) return list;
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Trending: orderBy viewsCount desc.
  Future<List<Map<String, dynamic>>> getReelsTrending({int limit = 20}) async {
    try {
      final q = await _firestore
          .collection(_reelsCollection)
          .orderBy('viewsCount', descending: true)
          .limit(limit)
          .get();
      final list = q.docs
          .map((d) => _docToReelMap(d))
          .where((r) => _isVisibleToCurrentUser(r) && _isPlayableReel(r))
          .toList();
      if (list.isNotEmpty) return list;
      if (_pexels.isAvailable) return _pexels.getTrending(limit: limit);
      return [];
    } catch (_) {
      if (_pexels.isAvailable) return _pexels.getTrending(limit: limit);
      return [];
    }
  }

  /// VR tab: where isVR == true.
  Future<List<Map<String, dynamic>>> getReelsVR({int limit = 20}) async {
    try {
      final q = await _firestore
          .collection(_reelsCollection)
          .where('isVR', isEqualTo: true)
          .limit(limit)
          .get();
      final list = q.docs
          .map((d) => _docToReelMap(d))
          .where((r) => _isVisibleToCurrentUser(r) && _isPlayableReel(r))
          .toList();
      if (list.isNotEmpty) return list;
      if (_pexels.isAvailable) return _pexels.getVR(limit: limit);
      return [];
    } catch (_) {
      if (_pexels.isAvailable) return _pexels.getVR(limit: limit);
      return [];
    }
  }

  /// Reels whose structured [tags] array or [caption] references [rawTag].
  ///
  /// Uses Firestore [array-contains] on normalized tags, then merges a bounded
  /// client scan of trending / for-you reels so older docs without [tags] still match.
  Future<List<Map<String, dynamic>>> getReelsByHashtag(
    String rawTag, {
    int limit = 60,
  }) async {
    final tag = HashtagUtils.normalizeForQuery(rawTag);
    if (tag.isEmpty) return [];

    final merged = <String, Map<String, dynamic>>{};

    void takePlayable(Map<String, dynamic> r) {
      final id = (r['id'] as String?)?.trim() ?? '';
      if (id.isEmpty || merged.containsKey(id)) return;
      if (!_isVisibleToCurrentUser(r) || !_isPlayableReel(r)) return;
      if (!HashtagUtils.reelMapMatchesHashtag(r, tag)) return;
      merged[id] = r;
    }

    try {
      final snap = await _firestore
          .collection(_reelsCollection)
          .where('tags', arrayContains: tag)
          .limit(limit)
          .get();
      for (final d in snap.docs) {
        takePlayable(_docToReelMap(d));
        if (merged.length >= limit) {
          return _sortReelsByCreatedAtDesc(
            merged.values.toList(),
          ).take(limit).toList(growable: false);
        }
      }
    } catch (e, st) {
      debugPrint('getReelsByHashtag arrayContains failed: $e');
      debugPrint('$st');
    }

    if (merged.length < limit) {
      try {
        final trending = await getReelsTrending(limit: 100);
        for (final r in trending) {
          takePlayable(r);
          if (merged.length >= limit) break;
        }
      } catch (e, st) {
        debugPrint('getReelsByHashtag trending supplement failed: $e');
        debugPrint('$st');
      }
    }

    if (merged.length < limit) {
      try {
        final fy = await getReelsForYou(limit: 100);
        for (final r in fy) {
          takePlayable(r);
          if (merged.length >= limit) break;
        }
      } catch (e, st) {
        debugPrint('getReelsByHashtag forYou supplement failed: $e');
        debugPrint('$st');
      }
    }

    return _sortReelsByCreatedAtDesc(
      merged.values.toList(),
    ).take(limit).toList(growable: false);
  }

  List<Map<String, dynamic>> _sortReelsByCreatedAtDesc(
    List<Map<String, dynamic>> list,
  ) {
    list.sort((a, b) {
      final aTs = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      final bTs = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      return bTs.compareTo(aTs);
    });
    return list;
  }

  /// Fetch a single reel by document id.
  Future<Map<String, dynamic>?> getReelById(String reelId) async {
    final id = reelId.trim();
    if (id.isEmpty) return null;
    try {
      final doc = await _firestore.collection(_reelsCollection).doc(id).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      final reel = _snapshotDataToReelMap(doc.id, data);
      if (!_isVisibleToCurrentUser(reel) || !_isPlayableReel(reel)) return null;
      return reel;
    } catch (_) {
      return null;
    }
  }

  /// Admin helper: reels that require manual moderation review.
  ///
  /// Returns newest first and does not apply feed visibility filters.
  Future<List<Map<String, dynamic>>> getReelsNeedingReview({
    int limit = 50,
  }) async {
    try {
      final q = await _firestore
          .collection(_reelsCollection)
          .where('moderation.status', isEqualTo: 'review')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return q.docs.map((d) => _docToReelMap(d)).toList();
    } catch (_) {
      // Fallback for projects without composite index on moderation.status + createdAt.
      try {
        final q = await _firestore
            .collection(_reelsCollection)
            .where('moderation.status', isEqualTo: 'review')
            .limit(limit)
            .get();
        return q.docs.map((d) => _docToReelMap(d)).toList();
      } catch (_) {
        return [];
      }
    }
  }

  /// Builds Cloudflare Stream HLS playback URL from a video ID.
  static String streamPlaybackUrl(String videoId) {
    // Use Cloudflare's stable global delivery domain so playback does not depend
    // on a potentially mismatched customer subdomain configuration.
    return 'https://videodelivery.net/$videoId/manifest/video.m3u8';
  }

  /// Seeds Firestore reels from Cloudflare Stream video IDs. Call from the "Upload Stream videos" helper.
  /// [videoIds] – list of Stream video IDs (paste from dashboard).
  /// [markAsVR] – if true, reels appear in VR tab (isVR: true).
  Future<int> seedStreamReels(
    List<String> videoIds, {
    bool markAsVR = false,
  }) async {
    if (videoIds.isEmpty) return 0;
    final uid = AuthService().currentUser?.uid ?? '';
    final username =
        AuthService().currentUser?.email?.split('@').first ?? 'Vyooo';
    int added = 0;
    for (var i = 0; i < videoIds.length; i++) {
      final id = videoIds[i].trim();
      if (id.isEmpty) continue;
      final videoUrl = streamPlaybackUrl(id);
      await _firestore.collection(_reelsCollection).add({
        'videoUrl': videoUrl,
        'streamVideoId': id,
        'username': username,
        'handle': '@${username.toLowerCase().replaceAll(' ', '_')}',
        'caption': 'Stream reel #${i + 1} · #vyooo',
        'likes': 0,
        'comments': 0,
        'saves': 0,
        'views': 0,
        'viewsCount': 0,
        'shares': 0,
        'avatarUrl': '',
        'userId': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'isVR': markAsVR,
        'moderation': {
          'provider': 'hive',
          'status': 'pending',
          'score': 0.0,
          'reasons': <String>[],
        },
      });
      added++;
    }
    return added;
  }

  static bool _isReelApproved(Map<String, dynamic> data) {
    final m = data['moderation'];
    if (m is Map<String, dynamic>) {
      final s = (m['status'] as String?)?.toLowerCase() ?? '';
      // Feed-safe default: only show content explicitly cleared by moderation.
      // Pending/review/blocked/error and empty statuses stay hidden from user feeds.
      if (s.isEmpty) return false;
      return s == 'clear' || s == 'approved';
    }
    if (m is Map) {
      final raw = m['status'];
      final s = raw == null ? '' : raw.toString().toLowerCase();
      if (s.isEmpty) return false;
      return s == 'clear' || s == 'approved';
    }
    return false;
  }

  bool _isVisibleToCurrentUser(Map<String, dynamic> data) {
    if (_isReelApproved(data)) return true;
    final currentUid = AuthService().currentUser?.uid ?? '';
    if (currentUid.isEmpty) return false;
    final ownerUid = (data['userId'] as String?) ?? '';
    return ownerUid == currentUid;
  }

  static bool _isPlayableReel(Map<String, dynamic> data) {
    final mediaType = _resolveMediaType(data);
    if (mediaType == 'image') {
      final imageUrl = ((data['imageUrl'] as String?) ?? '').trim();
      if (imageUrl.isNotEmpty)
        return Uri.tryParse(imageUrl)?.isAbsolute == true;
      final thumbnailUrl = ((data['thumbnailUrl'] as String?) ?? '').trim();
      return thumbnailUrl.isNotEmpty &&
          Uri.tryParse(thumbnailUrl)?.isAbsolute == true;
    }
    final url = (data['videoUrl'] as String?) ?? '';
    return VideoUploadPolicy.isPlayableUrl(url);
  }

  Map<String, dynamic> _docToReelMap(
    QueryDocumentSnapshot<Map<String, dynamic>> d,
  ) {
    return _snapshotDataToReelMap(d.id, d.data());
  }

  Map<String, dynamic> _snapshotDataToReelMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final mediaType = _resolveMediaType(data);
    final rawTags = data['tags'];
    final tagsList = rawTags is List
        ? rawTags.map((e) => e.toString()).toList(growable: false)
        : <String>[];

    return {
      'id': id,
      'mediaType': mediaType,
      'videoUrl': data['videoUrl'] ?? '',
      'imageUrl': data['imageUrl'] ?? '',
      'thumbnailUrl': data['thumbnailUrl'] ?? data['imageUrl'] ?? '',
      'username': data['username'] ?? '',
      'handle': data['handle'] ?? '',
      'caption': data['caption'] ?? '',
      'description': data['description'] ?? '',
      'title': data['title'] ?? '',
      'tags': tagsList,
      'isVR': data['isVR'] == true,
      'likes': (data['likes'] as num?)?.toInt() ?? 0,
      'comments': (data['comments'] as num?)?.toInt() ?? 0,
      'saves': (data['saves'] as num?)?.toInt() ?? 0,
      'views':
          (data['views'] as num?)?.toInt() ??
          (data['viewsCount'] as num?)?.toInt() ??
          0,
      'shares': (data['shares'] as num?)?.toInt() ?? 0,
      'avatarUrl': data['profileImage'] ?? data['avatarUrl'] ?? '',
      'userId': data['userId'] ?? '',
      'createdAt': data['createdAt'],
      'moderation': data['moderation'],
    };
  }

  static String _resolveMediaType(Map<String, dynamic> data) {
    final rawMediaType = ((data['mediaType'] as String?) ?? '').toLowerCase();
    if (rawMediaType == 'image' || rawMediaType == 'video') return rawMediaType;
    final imageUrl = ((data['imageUrl'] as String?) ?? '').trim();
    final videoUrl = ((data['videoUrl'] as String?) ?? '').trim();
    if (imageUrl.isNotEmpty && videoUrl.isEmpty) return 'image';
    return 'video';
  }
}
