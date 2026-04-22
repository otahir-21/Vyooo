import 'package:photo_manager/photo_manager.dart';

enum VideoValidationIssue {
  tooShort,
  tooLong,
  invalidAspectRatio,
  tooLarge,
  unreadableDimensions,
  inaccessibleFile,
}

class VideoValidationResult {
  const VideoValidationResult({
    required this.issue,
    required this.message,
  });

  final VideoValidationIssue issue;
  final String message;

  bool get canOpenEditorFix =>
      issue == VideoValidationIssue.tooLong ||
      issue == VideoValidationIssue.invalidAspectRatio;
}

class VideoUploadPolicy {
  VideoUploadPolicy._();

  static const Duration minDuration = Duration(seconds: 3);
  static const Duration maxDuration = Duration(seconds: 60);
  static const int maxBytes = 100 * 1024 * 1024; // 100 MB
  static const double minAspectRatio = 0.55; // around 9:16
  static const double maxAspectRatio = 0.60;

  static Future<VideoValidationResult?> validateAsset(AssetEntity asset) async {
    final duration = asset.videoDuration;
    if (duration < minDuration) {
      return VideoValidationResult(
        issue: VideoValidationIssue.tooShort,
        message: 'Video is too short. Minimum is ${minDuration.inSeconds}s.',
      );
    }
    if (duration > maxDuration) {
      return VideoValidationResult(
        issue: VideoValidationIssue.tooLong,
        message: 'Video is too long. Maximum is ${maxDuration.inSeconds}s.',
      );
    }

    final width = asset.width;
    final height = asset.height;
    if (width <= 0 || height <= 0) {
      return const VideoValidationResult(
        issue: VideoValidationIssue.unreadableDimensions,
        message: 'Unable to read video dimensions. Please pick another video.',
      );
    }
    final ratio = width / height;
    if (ratio < minAspectRatio || ratio > maxAspectRatio) {
      return const VideoValidationResult(
        issue: VideoValidationIssue.invalidAspectRatio,
        message: 'Use vertical 9:16 video (for example 1080x1920).',
      );
    }

    final file = await asset.file;
    if (file == null) {
      return const VideoValidationResult(
        issue: VideoValidationIssue.inaccessibleFile,
        message: 'Unable to access selected video file.',
      );
    }
    final bytes = await file.length();
    if (bytes > maxBytes) {
      return const VideoValidationResult(
        issue: VideoValidationIssue.tooLarge,
        message: 'Video is too large. Maximum allowed size is 100 MB.',
      );
    }
    return null;
  }

  static bool isPlayableUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return false;
    return uri.scheme == 'https' || uri.scheme == 'http';
  }
}
