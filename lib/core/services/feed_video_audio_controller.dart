import 'package:flutter/foundation.dart';

/// Session-wide mute for reel/feed video playback.
///
/// Toggling mute on one post applies to every post until the user unmutes.
class FeedVideoAudioController {
  FeedVideoAudioController._();

  static final FeedVideoAudioController instance = FeedVideoAudioController._();

  final ValueNotifier<bool> isMuted = ValueNotifier<bool>(false);

  double get volume => isMuted.value ? 0 : 1.0;

  void toggle() => isMuted.value = !isMuted.value;
}
