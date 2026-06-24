import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/video_360_metadata.dart';
import '../services/feed_offline_video_cache.dart';
import '../services/feed_video_audio_controller.dart';
import '../theme/app_spacing.dart';
import '../utils/stream_playback_urls.dart';
import '../utils/video_upload_policy.dart';
import 'double_tap_like_overlay.dart';
import 'sphere_360_panorama.dart';

/// Immersive 360° video player: equirectangular texture on an inner sphere.
///
/// Falls back to flat [VideoPlayer] if sphere rendering fails.
class Vyooo360VideoPlayer extends StatefulWidget {
  const Vyooo360VideoPlayer({
    super.key,
    required this.videoUrl,
    required this.isVisible,
    required this.video360,
    this.autoPlay = true,
    this.muted = false,
    this.enableGyro = true,
    this.enableTouch = true,
    this.thumbnailUrl,
    this.onDoubleTap,
    this.onVideoPlaybackStarted,
    this.onVideoCompleted,
  });

  final String videoUrl;
  final bool isVisible;
  final Video360Metadata video360;
  final bool autoPlay;
  final bool muted;
  final bool enableGyro;
  final bool enableTouch;
  final String? thumbnailUrl;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onVideoPlaybackStarted;
  final VoidCallback? onVideoCompleted;

  @override
  State<Vyooo360VideoPlayer> createState() => _Vyooo360VideoPlayerState();
}

class _Vyooo360VideoPlayerState extends State<Vyooo360VideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _showError = false;
  bool _useFlatFallback = false;
  final _feedAudio = FeedVideoAudioController.instance;
  VoidCallback? _feedAudioListener;
  bool _showControls = false;
  bool _isAppForeground = true;
  bool _hasNotifiedPlaybackStart = false;
  bool _hasNotifiedCompletion = false;
  int _urlIndex = 0;
  int _retryCount = 0;
  Timer? _hideTimer;
  Timer? _retryTimer;
  static const int _maxRetries = 24;

  bool get _shouldPlay => widget.isVisible && _isAppForeground;

  bool get _isMuted => _feedAudio.isMuted.value;

  void _onFeedAudioChanged() {
    _controller?.setVolume(_feedAudio.volume);
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _feedAudioListener = _onFeedAudioChanged;
    _feedAudio.isMuted.addListener(_feedAudioListener!);
    if (_shouldPlay) {
      _initializePlayer();
    }
  }

  @override
  void didUpdateWidget(covariant Vyooo360VideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposePlayer();
      _urlIndex = 0;
      _retryCount = 0;
      _useFlatFallback = false;
      if (_shouldPlay) _initializePlayer();
      return;
    }
    _syncPlayback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _isAppForeground) return;
    _isAppForeground = foreground;
    _syncPlayback();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_feedAudioListener != null) {
      _feedAudio.isMuted.removeListener(_feedAudioListener!);
      _feedAudioListener = null;
    }
    _hideTimer?.cancel();
    _retryTimer?.cancel();
    _disposePlayer();
    super.dispose();
  }

  void _disposePlayer() {
    _controller?.removeListener(_onControllerTick);
    _controller?.dispose();
    _controller = null;
    _initialized = false;
    _hasNotifiedPlaybackStart = false;
    _hasNotifiedCompletion = false;
  }

  Future<void> _initializePlayer() async {
    final urls = StreamPlaybackUrls.candidates(widget.videoUrl);
    if (urls.isEmpty) {
      if (mounted) setState(() => _showError = true);
      return;
    }
    final url = urls[_urlIndex.clamp(0, urls.length - 1)];
    try {
      VideoPlayerController controller;
      if (!url.startsWith('http')) {
        controller = VideoPlayerController.file(File(url));
      } else {
        final local = await FeedOfflineVideoCache.instance.localFileFor(url);
        if (local != null) {
          controller = VideoPlayerController.file(local);
        } else {
          controller = VideoPlayerController.networkUrl(
            Uri.parse(url),
            videoPlayerOptions: VideoPlayerOptions(
              mixWithOthers: true,
              allowBackgroundPlayback: false,
            ),
          );
        }
      }
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      controller.setLooping(true);
      controller.setVolume(_feedAudio.volume);
      controller.addListener(_onControllerTick);
      setState(() {
        _controller = controller;
        _initialized = true;
        _showError = false;
      });
      _syncPlayback();
    } catch (e) {
      debugPrint('Vyooo360VideoPlayer init failed: $e');
      if (!mounted) return;
      if (_retryCount < _maxRetries) {
        _retryCount++;
        _retryTimer?.cancel();
        _retryTimer = Timer(const Duration(seconds: 5), () {
          if (mounted && _shouldPlay) _initializePlayer();
        });
        return;
      }
      if (_urlIndex + 1 < urls.length) {
        _urlIndex++;
        _retryCount = 0;
        _initializePlayer();
        return;
      }
      setState(() => _showError = true);
    }
  }

  void _onControllerTick() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying && !_hasNotifiedPlaybackStart) {
      _hasNotifiedPlaybackStart = true;
      widget.onVideoPlaybackStarted?.call();
    }
    final pos = controller.value.position;
    final dur = controller.value.duration;
    if (!_hasNotifiedCompletion &&
        dur.inMilliseconds > 0 &&
        pos.inMilliseconds >= dur.inMilliseconds - 200) {
      _hasNotifiedCompletion = true;
      widget.onVideoCompleted?.call();
    }
    if (mounted) setState(() {});
  }

  void _syncPlayback() {
    final controller = _controller;
    if (controller == null) {
      if (_shouldPlay && !_showError) _initializePlayer();
      return;
    }
    if (!_initialized) return;
    if (_shouldPlay && widget.autoPlay) {
      if (!controller.value.isPlaying) controller.play();
    } else {
      if (controller.value.isPlaying) controller.pause();
    }
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
        _showControls = true;
        _hideTimer?.cancel();
      } else {
        controller.play();
        _startHideTimer();
      }
    });
  }

  void _toggleMute() {
    final controller = _controller;
    if (controller == null) return;
    _feedAudio.toggle();
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

  Widget _buildLoadingBackground() {
    final thumb = (widget.thumbnailUrl ?? '').trim();
    if (thumb.isEmpty) {
      return const ColoredBox(color: Colors.black);
    }
    return CachedNetworkImage(
      imageUrl: thumb,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorWidget: (_, _, _) => const ColoredBox(color: Colors.black),
    );
  }

  Widget _buildFlatFallback() {
    final controller = _controller!;
    final size = controller.value.size;
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: VideoPlayer(controller),
          ),
        ),
        Positioned(
          top: AppSpacing.sm,
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '360 playback unavailable — showing flat view',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSphereView() {
    return Sphere360Panorama(
      controller: _controller!,
      croppedArea: widget.video360.panoramaCrop,
      enableGyro: widget.enableGyro,
      enableTouch: widget.enableTouch,
    );
  }

  Widget _buildControlsPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _togglePlayPause,
            child: Icon(
              _controller?.value.isPlaying == true
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: _toggleMute,
            child: Icon(
              _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showError || !VideoUploadPolicy.isPlayableUrl(widget.videoUrl)) {
      return Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildLoadingBackground(),
            const Center(
              child: Text(
                'Could not load 360 video',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }

    if (!_initialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildLoadingBackground(),
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    Widget body;
    try {
      body = _useFlatFallback ? _buildFlatFallback() : _buildSphereView();
    } catch (e, st) {
      debugPrint('Vyooo360VideoPlayer sphere render error: $e\n$st');
      body = _buildFlatFallback();
      _useFlatFallback = true;
    }

    return DoubleTapLikeOverlay(
      onTap: _togglePlayPause,
      onDoubleTap: widget.onDoubleTap,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            body,
            Center(
              child: AnimatedOpacity(
                opacity: _showControls ||
                        !(_controller?.value.isPlaying ?? true)
                    ? 1.0
                    : 0.0,
                duration: const Duration(milliseconds: 200),
                child: _buildControlsPill(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
