import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_spacing.dart';
import 'edit_video_screen.dart';
import 'upload_details_screen.dart';

/// Preview selected video before upload: play/pause, seek bar, duration, mute, Edit Video, Next.
class UploadVideoPreviewScreen extends StatefulWidget {
  const UploadVideoPreviewScreen({super.key, required this.asset});

  final AssetEntity asset;

  @override
  State<UploadVideoPreviewScreen> createState() => _UploadVideoPreviewScreenState();
}

class _UploadVideoPreviewScreenState extends State<UploadVideoPreviewScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _muted = true;

  static const Color _pink = Color(0xFFDE106B);
  static const Color _darkGrey = Color(0xFF2A2A2E);

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void dispose() {
    _controller?.removeListener(_listener);
    _controller?.dispose();
    super.dispose();
  }

  void _listener() {
    if (mounted) setState(() {});
  }

  Future<void> _initVideo() async {
    try {
      final file = await widget.asset.file;
      if (file == null || !mounted) return;
      _controller = VideoPlayerController.file(file);
      _controller!.setLooping(false);
      _controller!.setVolume(_muted ? 0 : 1);
      _controller!.addListener(_listener);
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
        await _controller!.play();
      }
    } catch (e) {
      debugPrint('UploadVideoPreview: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _hasError = true;
        });
      }
    }
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      _controller?.setVolume(_muted ? 0 : 1);
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkGrey,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isInitialized && _controller != null)
                    _buildVideo()
                  else if (_hasError)
                    _buildError()
                  else
                    const Center(child: CircularProgressIndicator(color: Colors.white54)),
                ],
              ),
            ),
            if (_isInitialized && _controller != null) _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload video',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _circleButton(
                icon: Icons.close,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              _pillButton(
                label: 'Edit Video',
                icon: Icons.edit_rounded,
                onPressed: () {
                  _controller?.pause();
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(
                        builder: (_) => EditVideoScreen(asset: widget.asset),
                      ))
                      .then((_) => _controller?.play());
                },
              ),
              const SizedBox(width: AppSpacing.sm),
              _pillButton(
                label: 'Next >',
                icon: null,
                onPressed: () {
                  _controller?.pause();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => UploadDetailsScreen(asset: widget.asset),
                    ),
                  );
                },
                isPrimary: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onPressed}) {
    return Material(
      color: _darkGrey,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    bool isPrimary = false,
  }) {
    return Material(
      color: isPrimary ? _pink : _darkGrey,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideo() {
    return Center(
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: Colors.white.withValues(alpha: 0.6)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Could not load video',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final pos = _controller!.value.position;
    final dur = _controller!.value.duration;
    final totalSec = dur.inMilliseconds > 0 ? dur.inMilliseconds / 1000 : 1.0;
    final progress = totalSec > 0 ? (pos.inMilliseconds / 1000 / totalSec).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      color: Colors.black.withValues(alpha: 0.3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    overlayColor: Colors.transparent,
                    thumbColor: _pink,
                    activeTrackColor: _pink,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                    trackHeight: 2,
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: (v) {
                      final sec = v * dur.inMilliseconds / 1000;
                      _controller?.seekTo(Duration(milliseconds: (sec * 1000).round()));
                    },
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _formatDuration(dur),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                onPressed: _toggleMute,
                icon: Icon(
                  _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
