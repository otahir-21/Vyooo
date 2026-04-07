import 'package:cloud_firestore/cloud_firestore.dart';

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
          .where((r) => !_isReelBlocked(r))
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
  Future<List<Map<String, dynamic>>> getReelsFollowing({int limit = 20}) async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) {
      if (_pexels.isAvailable) return _pexels.getFollowing(limit: limit);
      return [];
    }
    try {
      final followingIds = await UserService().getFollowing(uid);
      if (followingIds.isEmpty) {
        if (_pexels.isAvailable) return _pexels.getFollowing(limit: limit);
        return [];
      }
      final q = await _firestore
          .collection(_reelsCollection)
          .where('userId', whereIn: followingIds.take(10).toList())
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      final list = q.docs
          .map((d) => _docToReelMap(d))
          .where((r) => !_isReelBlocked(r))
          .toList();
      if (list.isNotEmpty) return list;
      if (_pexels.isAvailable) return _pexels.getFollowing(limit: limit);
      return [];
    } catch (_) {
      if (_pexels.isAvailable) return _pexels.getFollowing(limit: limit);
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
          .where((r) => !_isReelBlocked(r))
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
          .where((r) => !_isReelBlocked(r))
          .toList();
      if (list.isNotEmpty) return list;
      if (_pexels.isAvailable) return _pexels.getVR(limit: limit);
      return [];
    } catch (_) {
      if (_pexels.isAvailable) return _pexels.getVR(limit: limit);
      return [];
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
    final username = AuthService().currentUser?.email?.split('@').first ?? 'Vyooo';
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

  static bool _isReelBlocked(Map<String, dynamic> data) {
    final m = data['moderation'];
    if (m is Map<String, dynamic>) {
      final s = (m['status'] as String?)?.toLowerCase() ?? '';
      return s == 'blocked';
    }
    if (m is Map) {
      final raw = m['status'];
      final s = raw == null ? '' : raw.toString().toLowerCase();
      return s == 'blocked';
    }
    return false;
  }

  Map<String, dynamic> _docToReelMap(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    return {
      'id': d.id,
      'videoUrl': data['videoUrl'] ?? '',
      'username': data['username'] ?? '',
      'handle': data['handle'] ?? '',
      'caption': data['caption'] ?? '',
      'likes': (data['likes'] as num?)?.toInt() ?? 0,
      'comments': (data['comments'] as num?)?.toInt() ?? 0,
      'saves': (data['saves'] as num?)?.toInt() ?? 0,
      'views': (data['views'] as num?)?.toInt() ?? (data['viewsCount'] as num?)?.toInt() ?? 0,
      'shares': (data['shares'] as num?)?.toInt() ?? 0,
      'avatarUrl': data['profileImage'] ?? data['avatarUrl'] ?? '',
      'userId': data['userId'] ?? '',
      'moderation': data['moderation'],
    };
  }
}
