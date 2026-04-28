import 'dart:io';

import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

enum VideoValidationIssue {
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

  bool get canOpenEditorFix => issue == VideoValidationIssue.tooLong;
}

class VideoUploadPolicy {
  VideoUploadPolicy._();

  static const Duration maxVideoDuration = Duration(minutes: 2);

  static Future<VideoValidationResult?> validateAsset(AssetEntity asset) async {
    final file = await asset.file;
    if (file == null) {
      return const VideoValidationResult(
        issue: VideoValidationIssue.inaccessibleFile,
        message: 'Unable to access selected video file.',
      );
    }

    final duration = await _resolveDuration(asset, file.path);
    if (duration == null) {
      return const VideoValidationResult(
        issue: VideoValidationIssue.unreadableDimensions,
        message: 'Unable to read video length. Please pick another video.',
      );
    }
    if (duration > maxVideoDuration) {
      return const VideoValidationResult(
        issue: VideoValidationIssue.tooLong,
        message: 'Video is too long. Maximum allowed length is 2 minutes.',
      );
    }
    return null;
  }

  static Future<Duration?> _resolveDuration(AssetEntity asset, String filePath) async {
    final assetDuration = asset.videoDuration;
    if (assetDuration.inMilliseconds > 0) return assetDuration;
    late final VideoPlayerController controller;
    try {
      controller = VideoPlayerController.file(File(filePath));
      await controller.initialize();
      final duration = controller.value.duration;
      if (duration.inMilliseconds > 0) return duration;
    } catch (_) {
      return null;
    } finally {
      await controller.dispose();
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
