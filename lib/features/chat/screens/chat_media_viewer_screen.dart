import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ChatMediaViewerScreen extends StatefulWidget {
  const ChatMediaViewerScreen({
    super.key,
    required this.mediaUrl,
    required this.isVideo,
    this.thumbnailUrl = '',
    this.isViewOnce = false,
  });

  final String mediaUrl;
  final bool isVideo;
  final String thumbnailUrl;
  final bool isViewOnce;

  @override
  State<ChatMediaViewerScreen> createState() => _ChatMediaViewerScreenState();
}

class _ChatMediaViewerScreenState extends State<ChatMediaViewerScreen> {
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _videoError = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo && widget.mediaUrl.isNotEmpty) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.mediaUrl),
    );
    _videoController = controller;
    try {
      await controller.initialize();
      if (mounted) {
        setState(() => _videoInitialized = true);
        controller.play();
      }
    } catch (_) {
      if (mounted) setState(() => _videoError = true);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isViewOnce) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.visibility_off, color: Colors.white38, size: 64),
              const SizedBox(height: 12),
              const Text(
                'View-once media cannot be viewed here',
                style: TextStyle(color: Colors.white54, fontSize: 15),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(child: widget.isVideo ? _buildVideo() : _buildImage()),
            if (_showControls)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            if (widget.isVideo && _videoInitialized) _buildVideoControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (widget.mediaUrl.isEmpty) {
      return const Icon(Icons.broken_image, color: Colors.white38, size: 64);
    }
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: CachedNetworkImage(
        imageUrl: widget.mediaUrl,
        fit: BoxFit.contain,
        placeholder: (_, _) => const CircularProgressIndicator(
          color: Color(0xFFDE106B),
          strokeWidth: 2,
        ),
        errorWidget: (_, _, _) =>
            const Icon(Icons.broken_image, color: Colors.white38, size: 64),
      ),
    );
  }

  Widget _buildVideo() {
    if (_videoError) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.white38, size: 64),
          SizedBox(height: 12),
          Text(
            'Could not load video',
            style: TextStyle(color: Colors.white54, fontSize: 15),
          ),
        ],
      );
    }
    if (!_videoInitialized) {
      return const CircularProgressIndicator(
        color: Color(0xFFDE106B),
        strokeWidth: 2,
      );
    }
    final controller = _videoController!;
    return AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: VideoPlayer(controller),
    );
  }

  Widget _buildVideoControls() {
    if (!_showControls) return const SizedBox.shrink();
    final controller = _videoController!;
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 20,
      left: 16,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (_, value, _) {
              final pos = value.position.inMilliseconds;
              final dur = value.duration.inMilliseconds;
              return Column(
                children: [
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      activeTrackColor: const Color(0xFFDE106B),
                      inactiveTrackColor: Colors.white24,
                      thumbColor: const Color(0xFFDE106B),
                      overlayColor: const Color(
                        0xFFDE106B,
                      ).withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: dur > 0 ? pos / dur : 0,
                      onChanged: (v) {
                        controller.seekTo(
                          Duration(milliseconds: (v * dur).toInt()),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(value.position),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatDuration(value.duration),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (_, value, _) {
              return IconButton(
                icon: Icon(
                  value.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: Colors.white,
                  size: 48,
                ),
                onPressed: () {
                  value.isPlaying ? controller.pause() : controller.play();
                },
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
