import 'video_upload_policy.dart';

/// Resolves HLS / MP4 fallback URLs for Cloudflare Stream playback.
class StreamPlaybackUrls {
  StreamPlaybackUrls._();

  static List<String> candidates(String raw) {
    final url = raw.trim();
    if (!VideoUploadPolicy.isPlayableUrl(url)) return const [];
    final out = <String>[url];
    final m = RegExp(
      r'^(https?:\/\/[^/]+)\/([^/]+)\/manifest\/video\.m3u8$',
      caseSensitive: false,
    ).firstMatch(url);
    if (m != null) {
      final hostBase = m.group(1)!;
      final videoId = m.group(2)!;
      final mp4 = '$hostBase/$videoId/downloads/default.mp4';
      if (VideoUploadPolicy.isPlayableUrl(mp4)) out.add(mp4);
      final hlsFallback =
          'https://videodelivery.net/$videoId/manifest/video.m3u8';
      final mp4Fallback =
          'https://videodelivery.net/$videoId/downloads/default.mp4';
      if (VideoUploadPolicy.isPlayableUrl(hlsFallback)) out.add(hlsFallback);
      if (VideoUploadPolicy.isPlayableUrl(mp4Fallback)) out.add(mp4Fallback);
    }
    return out.toSet().toList();
  }
}
