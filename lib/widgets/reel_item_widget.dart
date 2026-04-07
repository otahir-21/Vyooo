import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/theme/app_spacing.dart';

/// Single reel item for PageView. Handles video playback, auto-play, pause, preload.
/// Use AutomaticKeepAliveClientMixin for performance.
class ReelItemWidget extends StatefulWidget {
  const ReelItemWidget({
    super.key,
    required this.videoUrl,
    required this.isVisible,
    this.onVisibilityChanged,
  });

  final String videoUrl;
  final bool isVisible;
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
  static const int _maxRetries = 24; // ~2m wait for Cloudflare processing

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(ReelItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposePlayer();
      _initializePlayer();
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
      if (widget.isVisible) await ctrl.play();
    } catch (e) {
      debugPrint('Error initializing video: $e');
      _disposePlayer();

      // Try fallback URL first (e.g. HLS -> MP4 progressive) before timed retry.
      if (mounted && _urlIndex < urls.length - 1) {
        setState(() => _urlIndex++);
        Future.delayed(const Duration(milliseconds: 700), () {
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
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) _initializePlayer();
        });
      } else if (mounted) {
        setState(() => _showError = true);
      }
    }
  }

  void _disposePlayer() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }

  List<String> _candidateUrls(String raw) {
    final url = raw.trim();
    if (url.isEmpty) return const [];
    final out = <String>[url];
    final m = RegExp(
      r'^(https?:\/\/[^/]+)\/([^/]+)\/manifest\/video\.m3u8$',
      caseSensitive: false,
    ).firstMatch(url);
    if (m != null) {
      final hostBase = m.group(1)!;
      final videoId = m.group(2)!;
      out.add('$hostBase/$videoId/downloads/default.mp4');
      // Backward compatibility: if saved host is wrong, still try Cloudflare global domain.
      out.add('https://videodelivery.net/$videoId/manifest/video.m3u8');
      out.add('https://videodelivery.net/$videoId/downloads/default.mp4');
    }
    return out.toSet().toList();
  }

  void _handleVisibility() {
    if (!_isInitialized || _controller == null) return;
    if (widget.isVisible) {
      _controller!.play();
    } else {
      _controller!.pause();
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    // Show loading/retrying state
    if (_controller == null && !_showError) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              if (_retryCount > 0) ...[
                SizedBox(height: AppSpacing.sm),
                Text(
                  'Preparing video... (${_retryCount}/$_maxRetries)',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
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
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
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
            // Top Indicator Bar
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
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
          ],
        ),
      ),
    );
  }
}
