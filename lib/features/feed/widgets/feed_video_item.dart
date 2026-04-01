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

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _initVideo();
  }

  @override
  void didUpdateWidget(FeedVideoItem old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _initVideo();
    } else if (!widget.isActive && old.isActive) {
      _controller?.pause();
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_controller == null) return;
        _controller!.value.isPlaying
            ? _controller!.pause()
            : _controller!.play();
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
        ],
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
