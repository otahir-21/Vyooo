import '../../utils/video_upload_policy.dart';

/// Profile Posts tab: image and video reels with playable media only.
abstract final class ProfileGridPosts {
  ProfileGridPosts._();

  static String mediaType(Map<String, dynamic> reel) {
    final raw = ((reel['mediaType'] as String?) ?? '').toLowerCase();
    if (raw == 'image' || raw == 'video') return raw;
    final imageUrl = ((reel['imageUrl'] as String?) ?? '').trim();
    final videoUrl = ((reel['videoUrl'] as String?) ?? '').trim();
    if (imageUrl.isNotEmpty && videoUrl.isEmpty) return 'image';
    return 'video';
  }

  static bool hasPlayableMedia(Map<String, dynamic> reel) {
    if (mediaType(reel) == 'image') {
      final imageUrl = ((reel['imageUrl'] as String?) ?? '').trim();
      if (imageUrl.isNotEmpty) {
        return Uri.tryParse(imageUrl)?.hasAbsolutePath == true;
      }
      final thumb = ((reel['thumbnailUrl'] as String?) ?? '').trim();
      return thumb.isNotEmpty && Uri.tryParse(thumb)?.hasAbsolutePath == true;
    }
    final videoUrl = (reel['videoUrl'] as String?) ?? '';
    return VideoUploadPolicy.isPlayableUrl(videoUrl);
  }

  /// Keeps image and video posts that can render a thumbnail in the grid.
  static List<Map<String, dynamic>> filterImageAndVideo(
    List<Map<String, dynamic>> reels,
  ) {
    return reels
        .where((r) => hasPlayableMedia(r))
        .toList(growable: false);
  }
}
