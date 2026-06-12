import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import 'feed_offline_video_cache.dart';

/// Pre-initializes [VideoPlayerController]s so reels start instantly instead
/// of showing a loading spinner while the player buffers.
///
/// Used in two places:
///  * during the splash video, for the first reel of the warmed-up feed,
///  * while a reel plays, for the next reel in the PageView.
///
/// Holds at most [_maxPreloaded] controllers (Android caps concurrent hardware
/// video decoders, and the visible reel already uses one). Controllers are
/// never played here — no audio can leak. Ownership transfers to the caller of
/// [take]; evicted or unused controllers are disposed internally.
class ReelPreloadService {
  ReelPreloadService._();
  static final ReelPreloadService instance = ReelPreloadService._();

  static const int _maxPreloaded = 2;

  final Map<String, Future<VideoPlayerController?>> _pending = {};
  final List<String> _order = [];

  static VideoPlayerOptions get _playerOptions => VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      );

  /// Starts initializing a controller for [videoUrl]; no-op if already
  /// preloaded or in flight.
  void preload(String videoUrl) {
    final url = videoUrl.trim();
    if (url.isEmpty || _pending.containsKey(url)) return;
    if (Uri.tryParse(url)?.hasScheme != true) return;
    while (_order.length >= _maxPreloaded) {
      _evict(_order.first);
    }
    _order.add(url);
    _pending[url] = _create(url);
  }

  /// Hands over the preloaded controller for [videoUrl] (awaiting init if it
  /// is still in flight), or null when nothing was preloaded / init failed.
  /// The caller becomes responsible for disposing the returned controller.
  Future<VideoPlayerController?> take(String videoUrl) async {
    final url = videoUrl.trim();
    final pending = _pending.remove(url);
    _order.remove(url);
    if (pending == null) return null;
    return pending;
  }

  /// Disposes everything that is currently preloaded (e.g. on sign-out).
  void clear() {
    for (final url in List<String>.from(_order)) {
      _evict(url);
    }
  }

  Future<VideoPlayerController?> _create(String url) async {
    try {
      final localFile =
          await FeedOfflineVideoCache.instance.localFileFor(url);
      final ctrl = localFile != null
          ? VideoPlayerController.file(
              localFile,
              videoPlayerOptions: _playerOptions,
            )
          : VideoPlayerController.networkUrl(
              Uri.parse(url),
              videoPlayerOptions: _playerOptions,
            );
      try {
        await ctrl.initialize();
      } catch (_) {
        ctrl.dispose();
        rethrow;
      }
      return ctrl;
    } catch (e) {
      debugPrint('ReelPreloadService preload failed: $e');
      return null;
    }
  }

  void _evict(String url) {
    final pending = _pending.remove(url);
    _order.remove(url);
    if (pending == null) return;
    unawaited(
      pending.then((ctrl) => ctrl?.dispose()).catchError((Object _) {}),
    );
  }
}
