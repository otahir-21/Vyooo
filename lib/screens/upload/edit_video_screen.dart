import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import '../../core/mock/mock_music_data.dart';
import '../../core/theme/app_spacing.dart';
import '../music/add_audio_screen.dart';
import 'upload_details_screen.dart';

/// Edit video screen: title, close, Next >, video preview, tool row, timeline with scrubber.
class EditVideoScreen extends StatefulWidget {
  const EditVideoScreen({super.key, required this.asset});

  final AssetEntity asset;

  @override
  State<EditVideoScreen> createState() => _EditVideoScreenState();
}

class _EditVideoScreenState extends State<EditVideoScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _muted = true;

  final AudioPlayer _audioPlayer = AudioPlayer();
  MusicTrack? _selectedTrack;

  static const Color _pink = Color(0xFFDE106B);
  static const Color _darkGrey = Color(0xFF2A2A2E);
  static const double _topRadius = 20;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
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
      _controller!.setLooping(true);
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
      debugPrint('EditVideoScreen: $e');
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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title outside rounded area (light grey)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md, top: AppSpacing.xs, bottom: AppSpacing.xs),
              child: Text(
                'Edit video',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 15,
                ),
              ),
            ),
            // Rounded content area
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(_topRadius)),
                child: Container(
                  color: _darkGrey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context),
                      Expanded(child: _buildVideoArea()),
                      if (_selectedTrack != null) _buildMusicBar(),
                      _buildToolRow(),
                      _buildTimeline(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white, size: 26),
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
            ),
          ),
          const Spacer(),
          Material(
            color: _pink,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => UploadDetailsScreen(asset: widget.asset),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
                child: Text(
                  'Next >',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoArea() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(_topRadius)),
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isInitialized && _controller != null)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              )
            else if (_hasError)
              Center(
                child: Text(
                  'Could not load video',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16),
                ),
              )
            else
              const Center(child: CircularProgressIndicator(color: Colors.white54)),
          ],
        ),
      ),
    );
  }

  Widget _buildToolRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _toolButton(
            icon: Icons.music_note_rounded,
            onTap: () {
              _controller?.pause();
              Navigator.of(context)
                  .push<MusicTrack?>(MaterialPageRoute(
                    builder: (_) => AddAudioScreen(videoAsset: widget.asset),
                  ))
                  .then((track) async {
                if (!mounted) return;
                if (track != null) {
                  setState(() => _selectedTrack = track);
                  // Mute video, play selected music
                  _controller?.setVolume(0);
                  setState(() => _muted = true);
                  try {
                    await _audioPlayer.setUrl(track.audioUrl);
                    await _audioPlayer.play();
                  } catch (_) {}
                }
                _controller?.play();
              });
            },
          ),
          _toolButton(icon: Icons.filter_rounded, onTap: () {}),
          _toolButton(icon: Icons.tune_rounded, onTap: () {}),
          _toolButton(icon: Icons.content_cut_rounded, onTap: () {}),
          _toolButton(icon: Icons.rotate_right_rounded, onTap: () {}),
          _toolButton(icon: Icons.delete_rounded, onTap: () {}),
        ],
      ),
    );
  }

  Widget _toolButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: _darkGrey,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildMusicBar() {
    final t = _selectedTrack!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 8),
      decoration: BoxDecoration(
        color: _pink.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _pink.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.music_note_rounded, color: _pink, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${t.title} • ${t.artist}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () {
              _audioPlayer.stop();
              setState(() => _selectedTrack = null);
              _controller?.setVolume(_muted ? 0 : 1);
            },
            child: const Icon(Icons.close, color: Colors.white70, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    if (!_isInitialized || _controller == null) {
      return const SizedBox(height: 56);
    }
    final pos = _controller!.value.position;
    final dur = _controller!.value.duration;
    final totalSec = dur.inMilliseconds > 0 ? dur.inMilliseconds / 1000 : 1.0;
    final progress = totalSec > 0 ? (pos.inMilliseconds / 1000 / totalSec).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      color: Colors.black.withValues(alpha: 0.25),
      child: Row(
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                overlayColor: Colors.transparent,
                thumbColor: Colors.white,
                activeTrackColor: _pink,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.35),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
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
          const SizedBox(width: AppSpacing.xs),
          IconButton(
            onPressed: _toggleMute,
            icon: Icon(
              _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: Colors.white,
              size: 22,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }
}
