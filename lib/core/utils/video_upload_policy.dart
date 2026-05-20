/// Playback URL checks for reel/video posts. Upload has no client-side size or length limits.
class VideoUploadPolicy {
  VideoUploadPolicy._();

  static bool isPlayableUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return false;
    return uri.scheme == 'https' || uri.scheme == 'http';
  }
}
