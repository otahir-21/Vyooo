import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Third-party feed from Pexels (free API). Maps to app reel format.
/// Use when Firestore is empty or for demos. Get key: https://www.pexels.com/api/
class PexelsFeedService {
  PexelsFeedService._();
  static final PexelsFeedService _instance = PexelsFeedService._();
  factory PexelsFeedService() => _instance;

  static const String _base = 'https://api.pexels.com/videos';

  String? get _apiKey => AppConfig.pexelsApiKey;

  bool get isAvailable =>
      AppConfig.usePexelsFeed && _apiKey != null && _apiKey!.isNotEmpty;

  Future<List<Map<String, dynamic>>> getTrending({int limit = 20}) async {
    if (!isAvailable) return [];
    try {
      final res = await http.get(
        Uri.parse('$_base/popular?per_page=${limit.clamp(1, 80)}'),
        headers: {'Authorization': _apiKey!},
      );
      if (res.statusCode != 200) return [];
      return _parseVideos(res.body);
    } catch (_) {
      return [];
    }
  }

  /// For You: curated / explore-style search.
  Future<List<Map<String, dynamic>>> getForYou({int limit = 20}) async {
    if (!isAvailable) return [];
    try {
      final res = await http.get(
        Uri.parse(
          '$_base/search?query=short+clips&per_page=${limit.clamp(1, 80)}',
        ),
        headers: {'Authorization': _apiKey!},
      );
      if (res.statusCode != 200) return [];
      return _parseVideos(res.body);
    } catch (_) {
      return [];
    }
  }

  /// VR: search for 360 / immersive-style videos (Pexels has some).
  Future<List<Map<String, dynamic>>> getVR({int limit = 20}) async {
    if (!isAvailable) return [];
    try {
      final res = await http.get(
        Uri.parse('$_base/search?query=360+vr&per_page=${limit.clamp(1, 80)}'),
        headers: {'Authorization': _apiKey!},
      );
      if (res.statusCode != 200) return [];
      final list = _parseVideos(res.body);
      if (list.isEmpty) {
        // Fallback: popular so VR tab still has content
        return getTrending(limit: limit);
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Following has no third-party equivalent; return same as For You for demo.
  Future<List<Map<String, dynamic>>> getFollowing({int limit = 20}) async {
    return getForYou(limit: limit);
  }

  List<Map<String, dynamic>> _parseVideos(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final videos = json['videos'] as List<dynamic>? ?? [];
      final list = <Map<String, dynamic>>[];
      for (var i = 0; i < videos.length; i++) {
        final v = videos[i] as Map<String, dynamic>;
        final videoUrl = _pickVideoUrl(v);
        if (videoUrl == null) continue;
        final user = v['user'] as Map<String, dynamic>?;
        final name = user?['name'] as String? ?? 'Creator';
        final id = v['id']?.toString() ?? 'pexels_$i';
        list.add({
          'id': 'pexels_$id',
          'videoUrl': videoUrl,
          'username': name,
          'handle': '@${name.toLowerCase().replaceAll(' ', '_')}',
          'caption': (v['url'] as String? ?? '').isNotEmpty
              ? 'Via Pexels · #vyooo'
              : 'Short clip #vyooo',
          'likes': 0,
          'comments': 0,
          'saves': 0,
          'views': (v['width'] as num?)?.toInt() ?? 0,
          'shares': 0,
          'avatarUrl': user?['url'] as String? ?? '',
          'userId': '',
        });
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Prefer HD MP4, then first MP4 link.
  String? _pickVideoUrl(Map<String, dynamic> video) {
    final files = video['video_files'] as List<dynamic>? ?? [];
    if (files.isEmpty) return null;
    String? hd;
    String? any;
    for (final f in files) {
      final m = f as Map<String, dynamic>?;
      if (m == null) continue;
      final link = m['link'] as String?;
      final quality = (m['quality'] as String?)?.toLowerCase();
      final type = (m['file_type'] as String?)?.toLowerCase();
      if (link == null || link.isEmpty) continue;
      if (type == 'mp4' || link.endsWith('.mp4')) {
        any ??= link;
        if (quality == 'hd' ||
            quality == '1080p' ||
            (m['width'] as num?) == 1920) {
          hd = link;
          break;
        }
      }
    }
    return hd ?? any;
  }
}
