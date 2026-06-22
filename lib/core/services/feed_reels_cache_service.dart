import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reel_media_item.dart';

/// Persists the last successful home feeds for instant paint on next launch.
class FeedReelsCacheService {
  FeedReelsCacheService._();
  static final FeedReelsCacheService instance = FeedReelsCacheService._();

  static const String _prefKeyForYou = 'vyooo_feed_for_you_cache_v1';
  static const String _prefKeyTrending = 'vyooo_feed_trending_cache_v1';
  static const int _maxItems = 12;

  static const Set<String> _persistedKeys = {
    'id',
    'mediaType',
    'videoUrl',
    'imageUrl',
    'thumbnailUrl',
    'mediaItems',
    'mediaCount',
    'username',
    'handle',
    'caption',
    'description',
    'title',
    'tags',
    'isVR',
    'is360Video',
    'projectionType',
    'stereoMode',
    'likes',
    'comments',
    'saves',
    'views',
    'shares',
    'reposts',
    'avatarUrl',
    'profileImage',
    'userId',
    'isRepost',
    'repostOf',
    'repostOfUserId',
    'repostOfUsername',
    'repostOfHandle',
    'hideLikeCount',
    'hideViewCount',
    'hideShareCount',
    'hideCommentCount',
    'hideSaveCount',
  };

  Future<List<Map<String, dynamic>>> loadTrending() =>
      _load(_prefKeyTrending, 'loadTrending');

  Future<List<Map<String, dynamic>>> loadForYou() =>
      _load(_prefKeyForYou, 'loadForYou');

  Future<void> saveTrending(List<Map<String, dynamic>> reels) =>
      _save(_prefKeyTrending, reels, 'saveTrending');

  Future<void> saveForYou(List<Map<String, dynamic>> reels) =>
      _save(_prefKeyForYou, reels, 'saveForYou');

  Future<List<Map<String, dynamic>>> _load(
    String prefKey,
    String debugLabel,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final out = <Map<String, dynamic>>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(
          item.map((k, v) => MapEntry(k.toString(), v)),
        );
        final sanitized = _sanitize(map);
        if (_isPlayableCachedReel(sanitized)) {
          out.add(sanitized);
        }
        if (out.length >= _maxItems) break;
      }
      return out;
    } catch (e, st) {
      debugPrint('FeedReelsCacheService.$debugLabel failed: $e');
      debugPrint(st.toString());
      return const [];
    }
  }

  Future<void> _save(
    String prefKey,
    List<Map<String, dynamic>> reels,
    String debugLabel,
  ) async {
    if (reels.isEmpty) return;
    try {
      final payload = reels
          .take(_maxItems)
          .map(_sanitize)
          .where(_isPlayableCachedReel)
          .toList(growable: false);
      if (payload.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKey, jsonEncode(payload));
    } catch (e, st) {
      debugPrint('FeedReelsCacheService.$debugLabel failed: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyForYou);
      await prefs.remove(_prefKeyTrending);
    } catch (_) {}
  }

  static bool _isPlayableCachedReel(Map<String, dynamic> reel) {
    final id = (reel['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) return false;
    final mediaType = ((reel['mediaType'] as String?) ?? 'video').toLowerCase();
    if (mediaType == 'image') {
      final imageUrl = ((reel['imageUrl'] as String?) ?? '').trim();
      if (imageUrl.isNotEmpty) return true;
      final thumb = ((reel['thumbnailUrl'] as String?) ?? '').trim();
      return thumb.isNotEmpty;
    }
    final videoUrl = ((reel['videoUrl'] as String?) ?? '').trim();
    return videoUrl.isNotEmpty;
  }

  static Map<String, dynamic> _sanitize(Map<String, dynamic> reel) {
    final out = <String, dynamic>{};
    for (final key in _persistedKeys) {
      if (!reel.containsKey(key)) continue;
      final value = reel[key];
      if (value == null) continue;
      if (value is String || value is num || value is bool) {
        out[key] = value;
      } else if (key == 'mediaItems' && value is List) {
        out[key] = ReelMediaItem.sanitizedRawList(value);
      } else if (value is List) {
        out[key] = value.map((e) => e.toString()).toList(growable: false);
      }
    }
    if (!out.containsKey('thumbnailUrl') || (out['thumbnailUrl'] as String).isEmpty) {
      final image = (out['imageUrl'] as String?) ?? '';
      if (image.isNotEmpty) out['thumbnailUrl'] = image;
    }
    if (!out.containsKey('avatarUrl') || (out['avatarUrl'] as String).isEmpty) {
      final profile = (out['profileImage'] as String?) ?? '';
      if (profile.isNotEmpty) out['avatarUrl'] = profile;
    }
    return out;
  }
}
