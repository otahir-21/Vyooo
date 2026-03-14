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
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      _controller!.setLooping(true);
      _controller!.setVolume(1.0);
      
      await _controller!.initialize();
      
      if (mounted) {
        setState(() => _isInitialized = true);
        if (widget.isVisible) {
          await _controller!.play();
        }
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      // Show error state instead of infinite loading
      if (mounted) {
        setState(() => _isInitialized = false);
      }
    }
  }

  void _disposePlayer() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
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
    
    // Show loading state
    if (_controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    // Show error state if failed to initialize
    if (!_isInitialized && _controller!.value.hasError) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 48),
              SizedBox(height: AppSpacing.md),
              const Text(
                'Failed to load video',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () {
                  _disposePlayer();
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
