import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/navigation/app_route_observer.dart';
import '../core/services/feed_offline_video_cache.dart';
import '../core/services/reel_preload_service.dart';
import '../core/utils/video_upload_policy.dart';
import '../core/theme/app_spacing.dart';

/// Single reel item for PageView. Handles video playback, auto-play, pause, preload.
///
/// Self-contained lifecycle: pauses the underlying [VideoPlayerController] when
/// any of these become false, regardless of what the parent passes for
/// [isVisible]:
///   * the host route is no longer the topmost route (e.g. Settings/Notifications
///     is pushed over it) — observed via [appRouteObserver],
///   * the app moves to background — observed via [WidgetsBindingObserver],
///   * the surrounding subtree is in an inactive [TickerMode] (e.g. inactive
///     bottom-nav tab kept alive by [AutomaticKeepAliveClientMixin]).
///
/// This guarantees that no audio leaks while the user is on another screen,
/// even if a caller (incorrectly) hardcodes `isVisible: true`.
class ReelItemWidget extends StatefulWidget {
  const ReelItemWidget({
    super.key,
    required this.videoUrl,
    required this.isVisible,
    this.thumbnailUrl,
    this.onVisibilityChanged,
    this.onVideoCompleted,
    this.onVideoPlaybackStarted,
    this.onDoubleTap,
  });

  final String videoUrl;
  final bool isVisible;
  final String? thumbnailUrl;
  final VoidCallback? onVisibilityChanged;
  final VoidCallback? onVideoCompleted;

  /// Fired once per controller attach when playback actually begins. Lets the
  /// feed distinguish a playing video from one stuck loading/retrying.
  final VoidCallback? onVideoPlaybackStarted;
  final VoidCallback? onDoubleTap;

  @override
  State<ReelItemWidget> createState() => _ReelItemWidgetState();
}

class _ReelItemWidgetState extends State<ReelItemWidget>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver, RouteAware {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _showError = false;
  int _retryCount = 0;
  int _urlIndex = 0;
  bool _showControls = false;
  bool _isMuted = false;
  Timer? _hideTimer;
  Timer? _retryTimer;
  bool _lastIsPlaying = false;
  bool _hasNotifiedCompletion = false;
  bool _hasNotifiedPlaybackStart = false;
  bool _localPlaybackFailed = false;
  static const int _maxRetries = 24; // ~2m wait for Cloudflare processing

  // Effective-visibility flags. Combined with [widget.isVisible] in
  // [_shouldPlay] to decide whether the controller may play right now.
  bool _isRouteOnTop = true;
  bool _isAppForeground = true;
  bool _isTickerActive = true;
  bool _isRouteObserverSubscribed = false;

  @override
  bool get wantKeepAlive => true;

  bool get _shouldPlay =>
      widget.isVisible && _isRouteOnTop && _isAppForeground && _isTickerActive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_shouldPlay) {
      _initializePlayer();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isRouteObserverSubscribed) {
      final route = ModalRoute.of(context);
      if (route is PageRoute<void>) {
        appRouteObserver.subscribe(this, route);
        _isRouteObserverSubscribed = true;
      }
    }
    final tickerActive = TickerMode.of(context);
    if (tickerActive != _isTickerActive) {
      _isTickerActive = tickerActive;
      _syncPlayback();
    }
  }

  @override
  void didUpdateWidget(ReelItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _hasNotifiedCompletion = false;
      _hasNotifiedPlaybackStart = false;
      _localPlaybackFailed = false;
      _disposePlayer();
      if (_shouldPlay) {
        _initializePlayer();
      }
      return;
    }
    if (oldWidget.isVisible != widget.isVisible) {
      _syncPlayback();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Treat anything other than `resumed` as "not in foreground" so that audio
    // is paused on incoming calls, control center, app switcher, lock screen.
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _isAppForeground) return;
    _isAppForeground = foreground;
    _syncPlayback();
  }

  @override
  void didPushNext() {
    if (!_isRouteOnTop) return;
    _isRouteOnTop = false;
    _syncPlayback();
  }

  @override
  void didPopNext() {
    if (_isRouteOnTop) return;
    _isRouteOnTop = true;
    _syncPlayback();
  }

  @override
  void dispose() {
    if (_isRouteObserverSubscribed) {
      appRouteObserver.unsubscribe(this);
      _isRouteObserverSubscribed = false;
    }
    WidgetsBinding.instance.removeObserver(this);
    _disposePlayer();
    super.dispose();
  }

  static VideoPlayerOptions get _playerOptions => VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      );

  Future<void> _initializePlayer() async {
    if (!_shouldPlay) return;

    // Fastest path: a controller pre-initialized by [ReelPreloadService]
    // (first reel during splash, next reel while the previous one plays).
    final preloaded = await ReelPreloadService.instance.take(widget.videoUrl);
    if (preloaded != null) {
      if (!mounted || !_shouldPlay) {
        preloaded.dispose();
        return;
      }
      try {
        await _attachAndPlay(preloaded);
        return;
      } catch (e) {
        debugPrint('Preloaded reel controller failed, reinitializing: $e');
        _disposePlayer();
        if (!mounted || !_shouldPlay) return;
      }
    }

    // Prefer the offline copy prefetched by [FeedOfflineVideoCache]: instant
    // start and keeps the first feed reels playable with no internet.
    if (!_localPlaybackFailed) {
      final localFile =
          await FeedOfflineVideoCache.instance.localFileFor(widget.videoUrl);
      if (localFile != null) {
        if (!mounted || !_shouldPlay) return;
        try {
          await _attachAndPlay(
            VideoPlayerController.file(
              localFile,
              videoPlayerOptions: _playerOptions,
            ),
          );
          return;
        } catch (e) {
          debugPrint('Offline reel playback failed, using network: $e');
          _localPlaybackFailed = true;
          _disposePlayer();
          if (!mounted || !_shouldPlay) return;
        }
      }
    }

    final urls = _candidateUrls(widget.videoUrl);
    if (urls.isEmpty) return;
    final url = urls[_urlIndex.clamp(0, urls.length - 1)];
    try {
      await _attachAndPlay(
        VideoPlayerController.networkUrl(
          Uri.parse(url),
          videoPlayerOptions: _playerOptions,
        ),
      );
    } catch (e) {
      debugPrint('Error initializing video: $e');
      _disposePlayer();

      // Try fallback URL first (e.g. HLS -> MP4 progressive) before timed retry.
      if (mounted && _urlIndex < urls.length - 1) {
        setState(() => _urlIndex++);
        _retryTimer?.cancel();
        _retryTimer = Timer(const Duration(milliseconds: 700), () {
          if (mounted) _initializePlayer();
        });
        return;
      }

      // Timed retries for transient Cloudflare processing / HTTP 500.
      if (mounted && _retryCount < _maxRetries) {
        setState(() {
          _retryCount++;
          _showError = false;
        });
        _retryTimer?.cancel();
        _retryTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) _initializePlayer();
        });
      } else if (mounted) {
        setState(() => _showError = true);
      }
    }
  }

  /// Initializes [ctrl] (unless already pre-initialized), attaches it to state
  /// and starts playback.
  /// Throws on initialization failure (caller owns retry/fallback policy).
  Future<void> _attachAndPlay(VideoPlayerController ctrl) async {
    ctrl.setLooping(true);
    ctrl.setVolume(_isMuted ? 0 : 1.0);

    if (!ctrl.value.isInitialized) {
      try {
        await ctrl.initialize();
      } catch (_) {
        ctrl.dispose();
        rethrow;
      }
    }

    if (!mounted) {
      ctrl.dispose();
      return;
    }
    setState(() {
      _controller = ctrl;
      _isInitialized = true;
      _showError = false;
      _retryCount = 0;
    });
    // Fresh controller restarts from zero: allow start/completion to notify
    // again (fixes auto-scroll stalling on reels revisited after the keep-alive
    // state outlived a disposed controller).
    _hasNotifiedCompletion = false;
    _hasNotifiedPlaybackStart = false;
    _lastIsPlaying = ctrl.value.isPlaying;
    ctrl.addListener(_onControllerValueChanged);
    // Re-check after async gap: route may have been pushed away during
    // initialize(), in which case we must NOT autoplay.
    if (_shouldPlay) {
      await ctrl.play();
    }
  }

  void _disposePlayer() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _hideTimer?.cancel();
    _hideTimer = null;
    _controller?.removeListener(_onControllerValueChanged);
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }

  void _onControllerValueChanged() {
    final ctrl = _controller;
    if (ctrl == null) return;
    final isPlaying = ctrl.value.isPlaying;
    if (isPlaying != _lastIsPlaying) {
      _lastIsPlaying = isPlaying;
      if (mounted) setState(() {});
    }
    if (isPlaying && !_hasNotifiedPlaybackStart) {
      _hasNotifiedPlaybackStart = true;
      widget.onVideoPlaybackStarted?.call();
    }
    if (!_hasNotifiedCompletion && widget.onVideoCompleted != null) {
      final duration = ctrl.value.duration;
      final position = ctrl.value.position;
      if (duration > Duration.zero &&
          position >= duration - const Duration(milliseconds: 300)) {
        _hasNotifiedCompletion = true;
        widget.onVideoCompleted!();
      }
    }
  }

  List<String> _candidateUrls(String raw) {
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
      // Backward compatibility: if saved host is wrong, still try Cloudflare global domain.
      final hlsFallback =
          'https://videodelivery.net/$videoId/manifest/video.m3u8';
      final mp4Fallback =
          'https://videodelivery.net/$videoId/downloads/default.mp4';
      if (VideoUploadPolicy.isPlayableUrl(hlsFallback)) out.add(hlsFallback);
      if (VideoUploadPolicy.isPlayableUrl(mp4Fallback)) out.add(mp4Fallback);
    }
    return out.toSet().toList();
  }

  /// Idempotent: drives the underlying controller toward [_shouldPlay].
  ///
  /// Called from every effective-visibility change (route, app lifecycle,
  /// ticker mode, parent's [isVisible]). Safe to call multiple times.
  void _syncPlayback() {
    if (!mounted) return;
    if (_shouldPlay) {
      final controller = _controller;
      if (controller == null) {
        // First time we became eligible to play — kick off initialization.
        _initializePlayer();
        return;
      }
      if (_isInitialized && !controller.value.isPlaying) {
        controller.play();
      }
      return;
    }
    // Not eligible to play: fully release the underlying decoder instead of
    // only pausing. Android caps the number of concurrent hardware video
    // decoders (commonly ~16), and this widget keeps itself alive
    // ([wantKeepAlive] == true), so every scrolled-past reel that merely paused
    // its controller would hold a decoder forever — exhausting the limit and
    // crashing the app after ~13–16 reels. Releasing here keeps at most the
    // currently visible reel (plus briefly an adjacent one mid-swipe) decoding.
    // The thumbnail is shown via [_buildLoadingBackground] while uninitialized,
    // so there is no visual regression, and playback re-initializes if the reel
    // becomes visible again.
    _retryTimer?.cancel();
    _retryTimer = null;
    if (_controller != null || _isInitialized) {
      _disposePlayer();
      if (mounted) {
        setState(() {
          _showError = false;
          _retryCount = 0;
        });
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _showControls = true;
        _hideTimer?.cancel();
      } else {
        _controller!.play();
        _startHideTimer();
      }
    });
  }

  void _toggleMute() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0 : 1.0);
    });
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() => _showControls = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final loadingBg = _buildLoadingBackground();

    // Show loading/retrying state
    if (_controller == null && !_showError) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Stack(
            fit: StackFit.expand,
            children: [
              loadingBg,
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    if (_retryCount > 0) ...[
                      SizedBox(height: AppSpacing.sm),
                      Text(
                        'Preparing video... ($_retryCount/$_maxRetries)',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show error state after all retries exhausted.
    if (_showError) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 48),
              SizedBox(height: AppSpacing.md),
              const Text(
                'Failed to load video (server unavailable)',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () {
                  _disposePlayer();
                  _urlIndex = 0;
                  _retryCount = 0;
                  _showError = false;
                  _initializePlayer();
                },
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show loading if not yet initialized
    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            loadingBg,
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    // Reels style: fullscreen cover (crop to fill, no letterboxing)
    final size = _controller!.value.size;
    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTap: widget.onDoubleTap,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),
            // Progress Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                _controller!,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Color(0xFFEF4444),
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.transparent,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
            // ── Play/Pause & Mute Overlay ─────────────────────────────────────
            Center(
              child: AnimatedOpacity(
                opacity:
                    _showControls || !(_controller?.value.isPlaying ?? true)
                    ? 1.0
                    : 0.0,
                duration: const Duration(milliseconds: 200),
                child: _buildControlPill(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBackground() {
    final thumb = (widget.thumbnailUrl ?? '').trim();
    if (thumb.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: thumb,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 120),
        placeholder: (_, _) => const ColoredBox(color: Colors.black),
        errorWidget: (_, _, _) => const ColoredBox(color: Colors.black),
      );
    }
    return const ColoredBox(color: Colors.black);
  }

  Widget _buildControlPill() {
    final isPlaying = _controller?.value.isPlaying ?? false;
    return GestureDetector(
      onTap: () {}, // Swallow taps to prevent background video toggle
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _togglePlayPause,
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const VerticalDivider(
                color: Colors.white24,
                thickness: 1,
                width: 1,
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _toggleMute,
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
