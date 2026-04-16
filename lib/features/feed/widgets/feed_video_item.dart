import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/mock/mock_feed_data.dart';
import 'feed_action_buttons.dart';

/// Single feed video item — plays video when active, shows thumbnail fallback.
class FeedVideoItem extends StatefulWidget {
  const FeedVideoItem({
    super.key,
    required this.post,
    required this.isActive,
    this.isLiked = false,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onMore,
    this.onSeeMore,
  });

  final FeedPost post;
  final bool isActive;
  final bool isLiked;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onMore;
  final VoidCallback? onSeeMore;

  @override
  State<FeedVideoItem> createState() => _FeedVideoItemState();
}

class _FeedVideoItemState extends State<FeedVideoItem> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isRouteActive = true;
  bool _showControls = false;
  bool _isMuted = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _initVideo();
  }

  @override
  void didUpdateWidget(FeedVideoItem old) {
    super.didUpdateWidget(old);
    if (_isRouteActive && widget.isActive && !old.isActive) {
      _initVideo();
    } else if (!widget.isActive && old.isActive) {
      _controller?.pause();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeActive = TickerMode.of(context);
    if (routeActive == _isRouteActive) return;
    _isRouteActive = routeActive;
    if (!_isRouteActive) {
      _controller?.pause();
      return;
    }
    if (widget.isActive) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    if (_controller != null) {
      await _controller!.play();
      return;
    }
    final url = widget.post.videoUrl;
    if (url.isEmpty) return;
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      ctrl.setLooping(true);
      await ctrl.play();
      setState(() {
        _controller = ctrl;
        _initialized = true;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    _hideTimer?.cancel();
    if (_showControls) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  void _togglePlay() {
    if (_controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _showControls = true; // Stay visible while paused
        _hideTimer?.cancel();
      } else {
        _controller!.play();
        _startHideTimer();
      }
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleMute() {
    if (_controller == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0 : 1);
    });
    _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_controller == null) return;
        _togglePlay();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Video / fallback ──────────────────────────────────────────────
          Positioned.fill(
            child: _initialized && _controller != null
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  )
                : widget.post.thumbnailUrl.isNotEmpty
                ? Image.network(
                    widget.post.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _placeholder(),
                  )
                : _placeholder(),
          ),
          // ── Bottom gradient ───────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 200,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ),
          // ── User info ─────────────────────────────────────────────────────
          Positioned(
            left: 16,
            bottom: 60,
            right: 80,
            child: _UserInfo(post: widget.post, onSeeMore: widget.onSeeMore),
          ),
          // ── Action buttons ────────────────────────────────────────────────
          Positioned(
            right: 12,
            bottom: 120,
            child: FeedActionButtons(
              viewCount: _formatCount(widget.post.viewCount),
              likeCount: _formatCount(widget.post.likeCount),
              commentCount: _formatCount(widget.post.commentCount),
              isLiked: widget.isLiked,
              onLike: widget.onLike,
              onComment: widget.onComment,
              onShare: widget.onShare,
              onMore: widget.onMore,
            ),
          ),
          // ── Play/Pause & Mute Overlay ─────────────────────────────────────
          if (_initialized)
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
    );
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
                onTap: _togglePlay,
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

  Widget _placeholder() => Container(
    color: Colors.grey[900],
    child: const Center(
      child: CircularProgressIndicator(color: Colors.white38),
    ),
  );
}

// ── User info ─────────────────────────────────────────────────────────────────

class _UserInfo extends StatelessWidget {
  const _UserInfo({required this.post, this.onSeeMore});

  final FeedPost post;
  final VoidCallback? onSeeMore;

  static const Color _pinkAccent = Color(0xFFFF2E93);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white24,
              backgroundImage: post.userAvatarUrl.isNotEmpty
                  ? NetworkImage(post.userAvatarUrl)
                  : null,
              child: post.userAvatarUrl.isEmpty
                  ? const Icon(Icons.person, color: Colors.white54)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    post.userHandle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          post.caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onSeeMore,
          child: const Text(
            'See More',
            style: TextStyle(
              color: _pinkAccent,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
