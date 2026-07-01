import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_360/video_360.dart';
import 'package:video_player/video_player.dart';

import '../models/video_360_metadata.dart';
import '../services/feed_offline_video_cache.dart';
import '../services/feed_video_audio_controller.dart';
import '../theme/app_spacing.dart';
import '../utils/stream_playback_urls.dart';
import '../utils/video_upload_policy.dart';
import 'double_tap_like_overlay.dart';
import 'feed_reel_playback_control_pill.dart';

/// Immersive 360° video via native spherical player ([Video360View]).
///
/// Falls back to flat [VideoPlayer] when native 360 is unavailable or fails.
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
  Video360Controller? _nativeController;
  VideoPlayerController? _flatController;

  String? _resolvedUrl;
  bool _showError = false;
  bool _useFlatFallback = false;
  bool _nativeIsPlaying = false;
  bool _flatInitialized = false;
  final _feedAudio = FeedVideoAudioController.instance;
  VoidCallback? _feedAudioListener;
  bool _showControls = false;
  bool _isAppForeground = true;
  bool _hasNotifiedPlaybackStart = false;
  bool _hasNotifiedCompletion = false;
  int _urlIndex = 0;
  int _viewGeneration = 0;
  bool _nativeLayoutReady = false;
  bool _useAndroidSurface = true;
  Timer? _hideTimer;
  Timer? _startupWatchdog;

  static const Duration _startupTimeout = Duration(seconds: 12);

  bool get _supportsNative360 =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  bool get _shouldPlay => widget.isVisible && _isAppForeground;

  bool get _isMuted => _feedAudio.isMuted.value;

  void _onFeedAudioChanged() {
    _flatController?.setVolume(_feedAudio.volume);
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _feedAudioListener = _onFeedAudioChanged;
    _feedAudio.isMuted.addListener(_feedAudioListener!);
    if (_shouldPlay) {
      _beginPlayback();
    }
  }

  @override
  void didUpdateWidget(covariant Vyooo360VideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _resetPlayback();
      if (_shouldPlay) _beginPlayback();
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
    _startupWatchdog?.cancel();
    _disposeNative();
    _disposeFlat();
    super.dispose();
  }

  void _resetPlayback() {
    _startupWatchdog?.cancel();
    _disposeNative();
    _disposeFlat();
    _urlIndex = 0;
    _viewGeneration = 0;
    _useFlatFallback = false;
    _showError = false;
    _resolvedUrl = null;
    _nativeIsPlaying = false;
    _nativeLayoutReady = false;
    _useAndroidSurface = true;
  }

  void _disposeNative() {
    final native = _nativeController;
    _nativeController = null;
    unawaited(native?.dispose());
  }

  void _disposeFlat() {
    _flatController?.removeListener(_onFlatControllerTick);
    _flatController?.dispose();
    _flatController = null;
    _flatInitialized = false;
    _hasNotifiedPlaybackStart = false;
    _hasNotifiedCompletion = false;
  }

  Future<void> _beginPlayback() async {
    if (!VideoUploadPolicy.isPlayableUrl(widget.videoUrl)) {
      if (mounted) setState(() => _showError = true);
      return;
    }
    if (!_supportsNative360 || !widget.video360.use360Player) {
      await _initializeFlatFallback();
      return;
    }
    await _resolveNativeUrl();
  }

  Future<void> _resolveNativeUrl() async {
    final urls = StreamPlaybackUrls.candidatesPreferMp4(widget.videoUrl);
    if (urls.isEmpty) {
      if (mounted) setState(() => _showError = true);
      return;
    }
    final raw = urls[_urlIndex.clamp(0, urls.length - 1)];
    try {
      final resolved = await _resolveLocalOrRemote(raw);
      if (!mounted) return;
      setState(() {
        _resolvedUrl = resolved;
        _showError = false;
        _nativeLayoutReady = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _nativeLayoutReady = true);
      });
      _armStartupWatchdog();
    } catch (e) {
      debugPrint('Vyooo360VideoPlayer URL resolve failed: $e');
      if (!mounted) return;
      await _retryOrFallback();
    }
  }

  Future<String> _resolveLocalOrRemote(String url) async {
    if (!url.startsWith('http')) return url;
    final local = await FeedOfflineVideoCache.instance.localFileFor(url);
    return local?.path ?? url;
  }

  void _armStartupWatchdog() {
    _startupWatchdog?.cancel();
    _startupWatchdog = Timer(_startupTimeout, () {
      if (!mounted || _useFlatFallback || _hasNotifiedPlaybackStart) return;
      debugPrint('Vyooo360VideoPlayer native startup timeout');
      unawaited(_retryOrFallback());
    });
  }

  Future<void> _retryOrFallback() async {
    final urls = StreamPlaybackUrls.candidatesPreferMp4(widget.videoUrl);
    if (_urlIndex + 1 < urls.length) {
      _urlIndex++;
      _viewGeneration++;
      _disposeNative();
      if (mounted) {
        setState(() {
          _resolvedUrl = null;
          _nativeLayoutReady = false;
        });
      }
      await _resolveNativeUrl();
      return;
    }
    if (Platform.isAndroid && _useAndroidSurface) {
      _useAndroidSurface = false;
      _viewGeneration++;
      _disposeNative();
      if (mounted) {
        setState(() {
          _resolvedUrl = null;
          _nativeLayoutReady = false;
        });
      }
      await _resolveNativeUrl();
      return;
    }
    await _switchToFlatFallback();
  }

  Future<void> _switchToFlatFallback() async {
    _startupWatchdog?.cancel();
    _disposeNative();
    if (!mounted) return;
    setState(() {
      _useFlatFallback = true;
      _resolvedUrl = null;
    });
    await _initializeFlatFallback();
  }

  Future<void> _initializeFlatFallback() async {
    final urls = StreamPlaybackUrls.candidatesPreferMp4(widget.videoUrl);
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
      controller.addListener(_onFlatControllerTick);
      setState(() {
        _flatController = controller;
        _flatInitialized = true;
        _showError = false;
      });
      _syncPlayback();
    } catch (e) {
      debugPrint('Vyooo360VideoPlayer flat fallback failed: $e');
      if (!mounted) return;
      setState(() => _showError = true);
    }
  }

  void _onNativeCreated(Video360Controller controller) {
    _nativeController = controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncPlayback();
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (!mounted || !_shouldPlay) return;
        unawaited(controller.play());
      });
    });
  }

  void _onNativePlayInfo(Video360PlayInfo info) {
    if (!mounted) return;
    final wasPlaying = _nativeIsPlaying;
    _nativeIsPlaying = info.isPlaying;
    if (info.isPlaying && info.total > 0 && !_hasNotifiedPlaybackStart) {
      _hasNotifiedPlaybackStart = true;
      _startupWatchdog?.cancel();
      widget.onVideoPlaybackStarted?.call();
    }
    if (!_hasNotifiedCompletion &&
        info.total > 0 &&
        info.duration >= info.total - 200) {
      _hasNotifiedCompletion = true;
      widget.onVideoCompleted?.call();
    }
    if (wasPlaying != _nativeIsPlaying) {
      setState(() {});
    }
  }

  void _onFlatControllerTick() {
    final controller = _flatController;
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
    if (_useFlatFallback) {
      _syncFlatPlayback();
      return;
    }
    final native = _nativeController;
    if (native == null) {
      if (_shouldPlay && _resolvedUrl == null && !_showError) {
        unawaited(_beginPlayback());
      }
      return;
    }
    if (_shouldPlay && widget.autoPlay) {
      unawaited(native.play());
    } else {
      unawaited(native.stop());
    }
  }

  void _syncFlatPlayback() {
    final controller = _flatController;
    if (controller == null) {
      if (_shouldPlay && !_showError) unawaited(_initializeFlatFallback());
      return;
    }
    if (!_flatInitialized) return;
    if (_shouldPlay && widget.autoPlay) {
      if (!controller.value.isPlaying) controller.play();
    } else {
      if (controller.value.isPlaying) controller.pause();
    }
  }

  Future<void> _togglePlayPause() async {
    if (_useFlatFallback) {
      final controller = _flatController;
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
      return;
    }
    final native = _nativeController;
    if (native == null) return;
    if (_nativeIsPlaying) {
      await native.stop();
      setState(() {
        _showControls = true;
        _hideTimer?.cancel();
      });
    } else {
      await native.play();
      _startHideTimer();
    }
  }

  void _toggleMute() {
    _feedAudio.toggle();
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      final playing = _useFlatFallback
          ? (_flatController?.value.isPlaying ?? false)
          : _nativeIsPlaying;
      if (playing) setState(() => _showControls = false);
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
    final controller = _flatController!;
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

  Widget _buildNativeView() {
    final url = _resolvedUrl!;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1 || constraints.maxHeight < 1) {
          return _buildLoadingBackground();
        }
        return Video360View(
          key: ValueKey('360-$url-$_viewGeneration-$_useAndroidSurface'),
          url: url,
          isRepeat: true,
          useAndroidViewSurface: _useAndroidSurface,
          onVideo360ViewCreated: _onNativeCreated,
          onPlayInfo: _onNativePlayInfo,
        );
      },
    );
  }

  Widget _buildControlsPill() {
    final isPlaying = _useFlatFallback
        ? (_flatController?.value.isPlaying ?? false)
        : _nativeIsPlaying;
    return FeedReelPlaybackControlPill(
      isPlaying: isPlaying,
      isMuted: _isMuted,
      onPlayPause: () => unawaited(_togglePlayPause()),
      onMute: _toggleMute,
      showMute: _useFlatFallback,
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

    if (_useFlatFallback) {
      if (!_flatInitialized || _flatController == null) {
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
      return _wrapWithChrome(_buildFlatFallback());
    }

    if (_resolvedUrl == null || !_nativeLayoutReady) {
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

    return _wrapWithChrome(_buildNativeView());
  }

  Widget _wrapWithChrome(Widget body) {
    final isPlaying = _useFlatFallback
        ? (_flatController?.value.isPlaying ?? false)
        : _nativeIsPlaying;
    return DoubleTapLikeOverlay(
      onTap: () => unawaited(_togglePlayPause()),
      onDoubleTap: widget.onDoubleTap,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            body,
            Center(
              child: AnimatedOpacity(
                opacity: _showControls || !isPlaying ? 1.0 : 0.0,
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
