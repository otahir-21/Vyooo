import 'package:flutter/material.dart';

/// How a video is projected when played back.
enum Video360Projection {
  flat('flat'),
  equirectangular('equirectangular');

  const Video360Projection(this.firestoreValue);
  final String firestoreValue;

  static Video360Projection parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'equirectangular':
        return Video360Projection.equirectangular;
      case 'flat':
      default:
        return Video360Projection.flat;
    }
  }
}

/// Stereoscopic layout for 360 source frames.
enum Video360StereoMode {
  mono('mono'),
  topBottom('top_bottom'),
  sideBySide('side_by_side');

  const Video360StereoMode(this.firestoreValue);
  final String firestoreValue;

  static Video360StereoMode parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'top_bottom':
      case 'top-bottom':
        return Video360StereoMode.topBottom;
      case 'side_by_side':
      case 'side-by-side':
        return Video360StereoMode.sideBySide;
      case 'mono':
      default:
        return Video360StereoMode.mono;
    }
  }
}

/// Playback + upload metadata for 360 posts.
class Video360Metadata {
  const Video360Metadata({
    this.is360Video = false,
    this.projectionType = Video360Projection.flat,
    this.stereoMode = Video360StereoMode.mono,
  });

  static const Video360Metadata flat = Video360Metadata();

  final bool is360Video;
  final Video360Projection projectionType;
  final Video360StereoMode stereoMode;

  bool get use360Player =>
      is360Video && projectionType == Video360Projection.equirectangular;

  /// UV crop for [Panorama.croppedArea] on non-VR mobile playback.
  ///
  /// TODO(VR): render separate left/right eye views when in headset mode.
  Rect get panoramaCrop {
    switch (stereoMode) {
      case Video360StereoMode.topBottom:
        return const Rect.fromLTWH(0, 0, 1, 0.5);
      case Video360StereoMode.sideBySide:
        return const Rect.fromLTWH(0, 0, 0.5, 1);
      case Video360StereoMode.mono:
        return const Rect.fromLTWH(0, 0, 1, 1);
    }
  }

  Map<String, dynamic> toFirestore() => {
        'is360Video': is360Video,
        'projectionType': projectionType.firestoreValue,
        'stereoMode': stereoMode.firestoreValue,
      };

  /// Reads post/reel maps; unknown values fall back to safe defaults.
  static Video360Metadata fromPost(Map<String, dynamic> post) {
    final is360 = post['is360Video'] == true;
    return Video360Metadata(
      is360Video: is360,
      projectionType: Video360Projection.parse(
        post['projectionType']?.toString(),
      ),
      stereoMode: Video360StereoMode.parse(post['stereoMode']?.toString()),
    );
  }

  /// Validates client-submitted values before persisting.
  static Video360Metadata sanitize({
    required bool is360Video,
    required String projectionType,
    required String stereoMode,
  }) {
    if (!is360Video) return Video360Metadata.flat;
    final projection = Video360Projection.parse(projectionType);
    if (projection != Video360Projection.equirectangular) {
      return Video360Metadata.flat;
    }
    return Video360Metadata(
      is360Video: true,
      projectionType: Video360Projection.equirectangular,
      stereoMode: Video360StereoMode.parse(stereoMode),
    );
  }

  Video360Metadata copyWith({
    bool? is360Video,
    Video360Projection? projectionType,
    Video360StereoMode? stereoMode,
  }) {
    return Video360Metadata(
      is360Video: is360Video ?? this.is360Video,
      projectionType: projectionType ?? this.projectionType,
      stereoMode: stereoMode ?? this.stereoMode,
    );
  }
}
