import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/utils/video_upload_policy.dart';
import '../core/theme/app_spacing.dart';

/// Single reel item for PageView. Handles video playback, auto-play, pause, preload.
/// Use AutomaticKeepAliveClientMixin for performance.
class ReelItemWidget extends StatefulWidget {
  const ReelItemWidget({
    super.key,
    required this.videoUrl,
    required this.isVisible,
    this.thumbnailUrl,
    this.onVisibilityChanged,
  });

  final String videoUrl;
  final bool isVisible;
  final String? thumbnailUrl;
  final VoidCallback? onVisibilityChanged;

  @override
  State<ReelItemWidget> createState() => _ReelItemWidgetState();
}

class _ReelItemWidgetState extends State<ReelItemWidget>
    with AutomaticKeepAliveClientMixin {
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
  static const int _maxRetries = 24; // ~2m wait for Cloudflare processing

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.isVisible) {
      _initializePlayer();
    }
  }

  @override
  void didUpdateWidget(ReelItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposePlayer();
      if (widget.isVisible) {
        _initializePlayer();
      }
    }
    if (oldWidget.isVisible != widget.isVisible) {
      _handleVisibility();
    }
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    if (!widget.isVisible) return;
    final urls = _candidateUrls(widget.videoUrl);
    if (urls.isEmpty) return;
    final url = urls[_urlIndex.clamp(0, urls.length - 1)];
    try {
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      ctrl.setLooping(true);
      ctrl.setVolume(1.0);

      await ctrl.initialize();

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
      _lastIsPlaying = ctrl.value.isPlaying;
      ctrl.addListener(_onControllerValueChanged);
      if (widget.isVisible) await ctrl.play();
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
    final isPlaying = _controller?.value.isPlaying ?? false;
    if (isPlaying == _lastIsPlaying) return;
    _lastIsPlaying = isPlaying;
    if (!mounted) return;
    setState(() {});
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
      final hlsFallback = 'https://videodelivery.net/$videoId/manifest/video.m3u8';
      final mp4Fallback = 'https://videodelivery.net/$videoId/downloads/default.mp4';
      if (VideoUploadPolicy.isPlayableUrl(hlsFallback)) out.add(hlsFallback);
      if (VideoUploadPolicy.isPlayableUrl(mp4Fallback)) out.add(mp4Fallback);
    }
    return out.toSet().toList();
  }

  void _handleVisibility() {
    if (widget.isVisible) {
      if (_controller == null) {
        _initializePlayer();
        return;
      }
      if (_isInitialized) {
        _controller!.play();
      }
      return;
    }
    _retryTimer?.cancel();
    _retryTimer = null;
    if (_isInitialized && _controller != null) {
      _controller!.pause();
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
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
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
      return Image.network(
        thumb,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
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
