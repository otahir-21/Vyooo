import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../mock/mock_music_data.dart';

/// Fetches royalty-free music from Jamendo API.
/// Get a free client_id at https://devportal.jamendo.com
class JamendoService {
  JamendoService._();
  static final JamendoService instance = JamendoService._();

  static const String _base = 'https://api.jamendo.com/v3.0';
  static const int _limit = 30;

  String get _clientId => AppConfig.jamendoClientId;

  // ── Public methods ─────────────────────────────────────────────────────────

  /// Trending tracks (sorted by total popularity).
  Future<List<MusicTrack>> fetchTrending() => _fetchTracks(
        extraParams: {'order': 'popularity_total'},
      );

  /// "For you" — curated mix (uses week popularity).
  Future<List<MusicTrack>> fetchForYou() => _fetchTracks(
        extraParams: {'order': 'popularity_week', 'tags': 'pop+electronic'},
      );

  /// Search by title or artist name.
  Future<List<MusicTrack>> search(String query) {
    if (query.trim().isEmpty) return fetchTrending();
    return _fetchTracks(extraParams: {'search': query.trim()});
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<List<MusicTrack>> _fetchTracks({
    Map<String, String> extraParams = const {},
  }) async {
    if (_clientId == 'YOUR_JAMENDO_CLIENT_ID') {
      // Return mock data until a real key is configured
      return mockMusicTracks;
    }

    final params = {
      'client_id': _clientId,
      'format': 'json',
      'limit': '$_limit',
      'audioformat': 'mp32', // MP3 direct stream URL
      'imagesize': '200',
      ...extraParams,
    };

    final uri = Uri.parse('$_base/tracks/').replace(queryParameters: params);

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return mockMusicTracks;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final results = json['results'] as List<dynamic>? ?? [];

      return results.map((item) {
        final map = item as Map<String, dynamic>;
        final seconds = (map['duration'] as num?)?.toInt() ?? 0;
        final mins = seconds ~/ 60;
        final secs = seconds % 60;
        final duration = '$mins:${secs.toString().padLeft(2, '0')}';

        return MusicTrack(
          id: map['id']?.toString() ?? '',
          title: map['name'] as String? ?? 'Unknown',
          artist: map['artist_name'] as String? ?? 'Unknown',
          duration: duration,
          albumArtUrl: map['image'] as String? ?? '',
          audioUrl: map['audio'] as String? ?? '',
        );
      }).where((t) => t.audioUrl.isNotEmpty).toList();
    } catch (_) {
      return mockMusicTracks;
    }
  }
}
