import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import '../../core/utils/video_upload_policy.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/navigation/app_route_observer.dart';
import 'edit_video_screen.dart';
import 'upload_details_screen.dart';

/// Preview selected video before upload: play/pause, seek bar, duration, mute, Edit Video, Next.
class UploadVideoPreviewScreen extends StatefulWidget {
  const UploadVideoPreviewScreen({super.key, required this.asset});

  final AssetEntity asset;

  @override
  State<UploadVideoPreviewScreen> createState() =>
      _UploadVideoPreviewScreenState();
}

class _UploadVideoPreviewScreenState extends State<UploadVideoPreviewScreen>
    with RouteAware, WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _muted = true;
  bool _isRouteVisible = true;
  bool _isAppForeground = true;
  bool _isRouteObserverSubscribed = false;
  VideoValidationResult? _validationIssue;

  static const Color _pink = Color(0xFFDE106B);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _validateSelectedVideo();
    _initVideo();
  }

  Future<void> _validateSelectedVideo() async {
    final issue = await VideoUploadPolicy.validateAsset(widget.asset);
    if (!mounted) return;
    setState(() => _validationIssue = issue);
  }

  Future<void> _showFixPrompt() async {
    final issue = _validationIssue;
    if (issue == null || !mounted) return;
    final canEdit = issue.canOpenEditorFix;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E0A1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Video needs adjustment',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                issue.message,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _fixHintForIssue(issue.issue),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              if (canEdit)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _controller?.pause();
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                EditVideoScreen(asset: widget.asset),
                          ),
                        )
                        .then((_) => _controller?.play());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pink,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('Open editor to fix'),
                ),
              if (canEdit) const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('Choose another video'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fixHintForIssue(VideoValidationIssue issue) {
    switch (issue) {
      case VideoValidationIssue.tooLong:
        return 'Trim your video to 60 seconds or less.';
      case VideoValidationIssue.invalidAspectRatio:
        return 'Crop your video to vertical 9:16 (for example 1080x1920).';
      case VideoValidationIssue.tooLarge:
        return 'Export/compress to a smaller file (recommended 1080p, under 100 MB).';
      case VideoValidationIssue.unreadableDimensions:
      case VideoValidationIssue.inaccessibleFile:
        return 'Please pick another video from gallery.';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_isRouteObserverSubscribed) {
      appRouteObserver.unsubscribe(this);
      _isRouteObserverSubscribed = false;
    }
    _controller?.removeListener(_listener);
    _controller?.dispose();
    super.dispose();
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
    if (_isAppForeground == foreground) return;
    _isAppForeground = foreground;
    _syncPlayback();
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
        _syncPlayback();
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

  void _syncPlayback() {
    final controller = _controller;
    if (controller == null || !_isInitialized) return;
    final shouldPlay = _isRouteVisible && _isAppForeground;
    if (shouldPlay) {
      controller.play();
    } else {
      controller.pause();
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
            child: _isInitialized && _controller != null
                ? _buildControls()
                : const SizedBox(),
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
                colors: [
                  Colors.black.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
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
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                ],
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
        IconButton(
          onPressed: () => _showQuitConfirmation(),
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
        ),
        const Spacer(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Edit Video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Image.asset(
              'assets/vyooO_icons/Upload_Story_Live/edit_video.png',
              width: 16,
              height: 16,
              color: Colors.white,
            ),
          ],
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {
            if (_validationIssue != null) {
              _showFixPrompt();
              return;
            }
            _controller?.pause();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => UploadDetailsScreen(asset: widget.asset),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _pink,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Next',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 12,
                ),
              ],
            ),
          ),
        ),
      ],
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
            const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Could not load video',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final pos = _controller!.value.position;
    final dur = _controller!.value.duration;
    final progress = dur.inSeconds > 0
        ? (pos.inSeconds / dur.inSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tools row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildToolIcon(
                'assets/vyooO_icons/Upload_Story_Live/audio_icon.png',
              ),
              _buildToolIcon('assets/vyooO_icons/Upload_Story_Live/adjust.png'),
              _buildToolIcon('assets/vyooO_icons/Upload_Story_Live/filter.png'),
              _buildToolIcon(
                'assets/vyooO_icons/Upload_Story_Live/crop.png',
              ), // Scissors placeholder if scissor icon is crop
              _buildToolIcon('assets/vyooO_icons/Upload_Story_Live/speed.png'),
              _buildToolIcon(
                'assets/vyooO_icons/Upload_Story_Live/delete_inactive.png',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Progress bar and duration
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(_pink),
                    minHeight: 3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatDuration(dur),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _toggleMute,
                child: Image.asset(
                  _muted
                      ? 'assets/vyooO_icons/Upload_Story_Live/mute.png'
                      : 'assets/vyooO_icons/Upload_Story_Live/microphone.png',
                  width: 20,
                  height: 20,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolIcon(String path) {
    return Container(
      width: 48,
      height: 48,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Image.asset(path, color: Colors.white),
    );
  }

  void _showQuitConfirmation() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E0A1E).withValues(alpha: 0.95),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Are you sure you want to quit uploading?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              _buildQuitOption(
                label: 'Continue Uploading',
                iconPath:
                    'assets/vyooO_icons/Upload_Story_Live/continue_uploading.png',
                onTap: () => Navigator.pop(ctx),
              ),
              const Divider(color: Colors.white10, height: 1),
              _buildQuitOption(
                label: 'Exit editing',
                iconPath:
                    'assets/vyooO_icons/Upload_Story_Live/exit_editing.png',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).pop();
                },
                isRed: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuitOption({
    required String label,
    required String iconPath,
    required VoidCallback onTap,
    bool isRed = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Image.asset(
              iconPath,
              width: 24,
              height: 24,
              color: isRed ? Colors.red : Colors.white,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isRed ? Colors.red : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
