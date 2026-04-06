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
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full screen video
          _buildVideo(),
          
          // 2. Gradients for visibility
          _buildGradients(),

          // 3. Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: _buildHeader(context),
          ),

          // 4. Bottom controls
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: _isInitialized && _controller != null ? _buildControls() : const SizedBox(),
          ),
        ],
      ),
    );
  }

  Widget _buildGradients() {
    return IgnorePointer(
      child: Column(
        children: [
          Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.5), Colors.transparent],
              ),
            ),
          ),
          const Spacer(),
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.close, color: Colors.white, size: 28),
        ),
        const Spacer(),
        _headerActionPill(
          label: 'Edit Video',
          icon: Icons.edit_rounded,
          onTap: () {
            _controller?.pause();
            Navigator.of(context)
                .push(MaterialPageRoute<void>(
              builder: (_) => EditVideoScreen(asset: widget.asset),
            ))
                .then((_) => _controller?.play());
          },
          isPink: false,
        ),
        const SizedBox(width: 8),
        _headerActionPill(
          label: 'Next',
          icon: Icons.arrow_forward_ios_rounded,
          onTap: () {
            _controller?.pause();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => UploadDetailsScreen(asset: widget.asset),
              ),
            );
          },
          isPink: true,
        ),
      ],
    );
  }

  Widget _headerActionPill({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isPink,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isPink ? _pink : Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(width: 6),
            Icon(icon, color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }


  Widget _buildVideo() {
    return Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isInitialized && _controller != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            )
          else if (_hasError)
            _buildError()
          else
            const Center(child: CircularProgressIndicator(color: Colors.white54)),
        ],
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                overlayColor: Colors.transparent,
                thumbColor: _pink,
                activeTrackColor: _pink,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
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
          const SizedBox(width: 8),
          Text(
            _formatDuration(dur),
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _toggleMute,
            child: Icon(
              _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}
