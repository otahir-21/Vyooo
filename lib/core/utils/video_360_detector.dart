import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:flutter/foundation.dart';

import '../models/video_360_metadata.dart';

enum Video360DetectionConfidence { high, medium, low, none }

class Video360DetectionResult {
  const Video360DetectionResult({
    required this.confidence,
    this.suggested,
    this.message,
  });

  final Video360DetectionConfidence confidence;
  final Video360Metadata? suggested;
  final String? message;
}

/// Probes a local video file for 360 metadata and common equirectangular layouts.
class Video360Detector {
  Video360Detector._();

  static Future<Video360DetectionResult> detect(File file) async {
    if (!await file.exists()) {
      return const Video360DetectionResult(
        confidence: Video360DetectionConfidence.none,
        message: 'Video file not found.',
      );
    }

    try {
      final session = await FFprobeKit.getMediaInformation(file.path);
      final info = session.getMediaInformation();
      if (info == null) {
        return _aspectRatioOnly(await _probeDimensionsFallback(file));
      }

      final tags = _flattenTags(info.getTags());
      final streams = info.getStreams();
      int? width;
      int? height;
      for (final stream in streams) {
        if (stream.getType() == 'video') {
          width = stream.getWidth();
          height = stream.getHeight();
          break;
        }
      }

      final tagHit = _fromSphericalTags(tags);
      if (tagHit != null) {
        return Video360DetectionResult(
          confidence: Video360DetectionConfidence.high,
          suggested: tagHit,
          message: '360 metadata found in file.',
        );
      }

      if (width != null && height != null && height > 0) {
        final aspect = width / height;
        final guessed = _fromAspectRatio(aspect);
        if (guessed != null) {
          return Video360DetectionResult(
            confidence: Video360DetectionConfidence.medium,
            suggested: guessed,
            message: 'Resolution looks like a 360 layout (${width}x$height).',
          );
        }
      }

      return const Video360DetectionResult(
        confidence: Video360DetectionConfidence.none,
        message: 'No 360 signals detected. You can still mark it manually.',
      );
    } catch (e, st) {
      debugPrint('Video360Detector: probe failed: $e\n$st');
      return const Video360DetectionResult(
        confidence: Video360DetectionConfidence.none,
        message: 'Could not analyze video. Mark 360 manually if needed.',
      );
    }
  }

  static Future<Video360DetectionResult> _aspectRatioOnly(
    (int, int)? dimensions,
  ) async {
    if (dimensions == null) {
      return const Video360DetectionResult(
        confidence: Video360DetectionConfidence.none,
      );
    }
    final (width, height) = dimensions;
    final guessed = _fromAspectRatio(width / height);
    if (guessed == null) {
      return const Video360DetectionResult(
        confidence: Video360DetectionConfidence.none,
      );
    }
    return Video360DetectionResult(
      confidence: Video360DetectionConfidence.medium,
      suggested: guessed,
      message: 'Resolution looks like a 360 layout (${width}x$height).',
    );
  }

  static Future<(int, int)?> _probeDimensionsFallback(File file) async {
    final session = await FFprobeKit.execute(
      '-v error -select_streams v:0 -show_entries stream=width,height -of json "${file.path}"',
    );
    final output = await session.getOutput();
    if (output == null || output.trim().isEmpty) return null;
    try {
      final json = jsonDecode(output) as Map<String, dynamic>;
      final streams = json['streams'];
      if (streams is! List || streams.isEmpty) return null;
      final first = streams.first;
      if (first is! Map) return null;
      final w = (first['width'] as num?)?.toInt();
      final h = (first['height'] as num?)?.toInt();
      if (w == null || h == null || h <= 0) return null;
      return (w, h);
    } catch (_) {
      return null;
    }
  }

  static Map<String, String> _flattenTags(Map<dynamic, dynamic>? tags) {
    if (tags == null) return const {};
    final out = <String, String>{};
    tags.forEach((key, value) {
      if (key == null || value == null) return;
      out[key.toString().toLowerCase()] = value.toString();
    });
    return out;
  }

  static Video360Metadata? _fromSphericalTags(Map<String, String> tags) {
    final blob = tags.values.join('\n').toLowerCase();
    final has360 = blob.contains('spherical') ||
        blob.contains('equirectangular') ||
        blob.contains('projection=equirectangular') ||
        blob.contains('gspherical');
    if (!has360) return null;

    var stereo = Video360StereoMode.mono;
    if (blob.contains('top-bottom') ||
        blob.contains('top_bottom') ||
        blob.contains('stereo_mode=top-bottom')) {
      stereo = Video360StereoMode.topBottom;
    } else if (blob.contains('left-right') ||
        blob.contains('side-by-side') ||
        blob.contains('side_by_side') ||
        blob.contains('stereo_mode=left-right')) {
      stereo = Video360StereoMode.sideBySide;
    }

    return Video360Metadata(
      is360Video: true,
      projectionType: Video360Projection.equirectangular,
      stereoMode: stereo,
    );
  }

  static Video360Metadata? _fromAspectRatio(double aspect) {
    if (aspect >= 1.85 && aspect <= 2.15) {
      return const Video360Metadata(
        is360Video: true,
        projectionType: Video360Projection.equirectangular,
        stereoMode: Video360StereoMode.mono,
      );
    }
    if (aspect >= 0.95 && aspect <= 1.05) {
      return const Video360Metadata(
        is360Video: true,
        projectionType: Video360Projection.equirectangular,
        stereoMode: Video360StereoMode.topBottom,
      );
    }
    if (aspect >= 3.8 && aspect <= 4.2) {
      return const Video360Metadata(
        is360Video: true,
        projectionType: Video360Projection.equirectangular,
        stereoMode: Video360StereoMode.sideBySide,
      );
    }
    return null;
  }
}
