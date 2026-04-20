import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import '../../core/mock/mock_music_data.dart';
import '../../core/navigation/app_route_observer.dart';
import '../../core/theme/app_spacing.dart';

/// After selecting a track: matches EditVideoScreen layout — "add audio" label,
/// full video preview, tool row (music icon highlighted), waveform trim bar at bottom.
/// Done → pop(true), X → pop(false).
class AddAudioTrimScreen extends StatefulWidget {
  const AddAudioTrimScreen({
    super.key,
    required this.track,
    required this.videoAsset,
  });

  final MusicTrack track;
  final AssetEntity videoAsset;

  @override
  State<AddAudioTrimScreen> createState() => _AddAudioTrimScreenState();
}

class _AddAudioTrimScreenState extends State<AddAudioTrimScreen>
    with RouteAware, WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _videoReady = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _audioPlaying = false;
  bool _isRouteVisible = true;
  bool _isAppForeground = true;
  bool _isRouteObserverSubscribed = false;

  double _trimStart = 0.1;
  double _trimEnd = 0.6;

  static const Color _pink = Color(0xFFDE106B);
  static const Color _darkGrey = Color(0xFF2A2A2E);
  static const double _topRadius = 20;

  static final List<double> _waveformHeights =
      List.generate(80, (_) => 0.2 + math.Random().nextDouble() * 0.8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initVideo();
    _initAudio();
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _audioPlaying =
            state.playing && state.processingState != ProcessingState.completed);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isRouteObserverSubscribed) return;
    final route = ModalRoute.of(context);
    if (route is PageRoute<void>) {
      appRouteObserver.subscribe(this, route);
      _isRouteObserverSubscribed = true;
    }
  }

  Future<void> _initVideo() async {
    try {
      final file = await widget.videoAsset.file;
      if (file == null || !mounted) return;
      _controller = VideoPlayerController.file(file);
      _controller!.setLooping(true);
      _controller!.setVolume(0);
      _controller!.addListener(() {
        if (mounted) setState(() {});
      });
      await _controller!.initialize();
      if (mounted) {
        setState(() => _videoReady = true);
        _syncPlayback();
      }
    } catch (_) {
      if (mounted) setState(() => _videoReady = false);
    }
  }

  Future<void> _initAudio() async {
    try {
      if (widget.track.audioUrl.isNotEmpty) {
        await _audioPlayer.setUrl(widget.track.audioUrl);
        _syncPlayback();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_isRouteObserverSubscribed) {
      appRouteObserver.unsubscribe(this);
      _isRouteObserverSubscribed = false;
    }
    _audioPlayer.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    if (!_isRouteVisible) return;
    setState(() => _isRouteVisible = false);
    _syncPlayback();
  }

  @override
  void didPopNext() {
    if (_isRouteVisible) return;
    setState(() => _isRouteVisible = true);
    _syncPlayback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _isAppForeground) return;
    _isAppForeground = foreground;
    _syncPlayback();
  }

  void _syncPlayback() {
    final shouldPlay = _isRouteVisible && _isAppForeground;
    if (shouldPlay) {
      if (_videoReady) {
        _controller?.play();
      }
      if (_audioPlayer.audioSource != null && !_audioPlayer.playing) {
        _audioPlayer.play();
      }
    } else {
      _controller?.pause();
      if (_audioPlayer.playing) {
        _audioPlayer.pause();
      }
    }
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
            // "add audio" label
            Padding(
              padding: const EdgeInsets.only(
                  left: AppSpacing.md, top: AppSpacing.xs, bottom: AppSpacing.xs),
              child: Text(
                'add audio',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 15,
                ),
              ),
            ),
            // Rounded content area
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(_topRadius)),
                child: Container(
                  color: _darkGrey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context),
                      Expanded(child: _buildVideoArea()),
                      _buildToolRow(),
                      _buildWaveformBar(),
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
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: Row(
        children: [
          // X — cancel, go back to music list
          IconButton(
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close, color: Colors.white, size: 26),
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
            ),
          ),
          const Spacer(),
          // Next > — confirm track selection
          Material(
            color: _pink,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () => Navigator.of(context).pop(true),
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: 10),
                child: Text(
                  'Next >',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
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
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(_topRadius)),
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_videoReady && _controller != null)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              )
            else
              const Center(
                  child: CircularProgressIndicator(color: Colors.white54)),
            // Music badge top-right
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.music_note_rounded,
                        color: _pink, size: 14),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 80,
                      child: Text(
                        widget.track.title,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
          // Music note — highlighted pink (active tool)
          _toolButton(
            icon: Icons.music_note_rounded,
            highlighted: true,
            onTap: () => _audioPlaying
                ? _audioPlayer.pause()
                : _audioPlayer.play(),
          ),
          _toolButton(icon: Icons.filter_rounded, onTap: () {}),
          _toolButton(icon: Icons.lens_blur_rounded, onTap: () {}),
          _toolButton(icon: Icons.content_cut_rounded, onTap: () {}),
          _toolButton(icon: Icons.timer_rounded, onTap: () {}),
          _toolButton(icon: Icons.delete_rounded, onTap: () {}),
        ],
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    return Material(
      color: highlighted ? _pink.withValues(alpha: 0.2) : _darkGrey,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Icon(icon,
              color: highlighted ? _pink : Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildWaveformBar() {
    final dur = _controller?.value.duration ?? Duration.zero;
    final pos = _controller?.value.position ?? Duration.zero;
    final totalMs = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1;
    final progress = (pos.inMilliseconds / totalMs).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      color: Colors.black.withValues(alpha: 0.25),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Waveform with trim handles
          SizedBox(
            height: 44,
            child: LayoutBuilder(builder: (context, constraints) {
              return Stack(
                children: [
                  _WaveformPainter(
                    heights: _waveformHeights,
                    trimStart: _trimStart,
                    trimEnd: _trimEnd,
                    width: constraints.maxWidth,
                  ),
                  // Start handle
                  Positioned(
                    left: (_trimStart * constraints.maxWidth - 14)
                        .clamp(0.0, constraints.maxWidth - 28),
                    top: 0,
                    bottom: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (d) {
                        setState(() {
                          final dx = d.delta.dx / constraints.maxWidth;
                          _trimStart =
                              (_trimStart + dx).clamp(0.0, _trimEnd - 0.05);
                        });
                      },
                      child: SizedBox(
                        width: 28,
                        child: Center(
                          child: Container(
                            width: 3,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // End handle
                  Positioned(
                    left: (_trimEnd * constraints.maxWidth - 14)
                        .clamp(0.0, constraints.maxWidth - 28),
                    top: 0,
                    bottom: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (d) {
                        setState(() {
                          final dx = d.delta.dx / constraints.maxWidth;
                          _trimEnd =
                              (_trimEnd + dx).clamp(_trimStart + 0.05, 1.0);
                        });
                      },
                      child: SizedBox(
                        width: 28,
                        child: Center(
                          child: Container(
                            width: 3,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 6),
          // Playback progress row
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
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: (v) {
                      final ms = (v * totalMs).round();
                      _controller?.seekTo(Duration(milliseconds: ms));
                    },
                  ),
                ),
              ),
              Text(
                _formatDuration(dur),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              IconButton(
                onPressed: () {
                  _audioPlaying ? _audioPlayer.pause() : _audioPlayer.play();
                },
                icon: Icon(
                  _audioPlaying
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Waveform painter ──────────────────────────────────────────────────────────

class _WaveformPainter extends StatelessWidget {
  const _WaveformPainter({
    required this.heights,
    required this.trimStart,
    required this.trimEnd,
    required this.width,
  });

  final List<double> heights;
  final double trimStart;
  final double trimEnd;
  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, 44),
      painter: _WaveformDelegate(
        heights: heights,
        trimStart: trimStart,
        trimEnd: trimEnd,
      ),
    );
  }
}

class _WaveformDelegate extends CustomPainter {
  _WaveformDelegate({
    required this.heights,
    required this.trimStart,
    required this.trimEnd,
  });

  final List<double> heights;
  final double trimStart;
  final double trimEnd;

  static const Color _pink = Color(0xFFDE106B);

  @override
  void paint(Canvas canvas, Size size) {
    final n = heights.length;
    final barWidth = size.width / n;
    final centerY = size.height / 2;

    for (var i = 0; i < n; i++) {
      final t = (i + 0.5) / n;
      final inRange = t >= trimStart && t <= trimEnd;
      final h = (heights[i] * size.height * 0.45).clamp(2.0, size.height * 0.9);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(i * barWidth + barWidth / 2, centerY),
            width: (barWidth * 0.55).clamp(1.5, 4.0),
            height: h,
          ),
          const Radius.circular(2),
        ),
        Paint()
          ..color =
              inRange ? _pink : Colors.white.withValues(alpha: 0.25),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformDelegate old) =>
      old.trimStart != trimStart || old.trimEnd != trimEnd;
}
