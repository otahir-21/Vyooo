import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/mock/mock_feed_data.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/user_service.dart';
import '../../../../screens/profile/user_profile_screen.dart';
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

class _FeedVideoItemState extends State<FeedVideoItem>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isRouteActive = true;
  bool _showControls = false;
  bool _isMuted = false;
  bool _isAppForeground = true;
  bool _isFollowingAuthor = false;
  bool _followBusy = false;
  String? _targetUserId;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resolveAuthorFollowState();
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
    _syncPlayback();
  }

  Future<void> _resolveAuthorFollowState() async {
    final me = AuthService().currentUser?.uid;
    if (me == null || me.isEmpty) return;

    final handle = widget.post.userHandle.trim().replaceFirst('@', '');
    final username = handle.isNotEmpty ? handle : widget.post.username.trim();
    final user = await UserService().getUserByUsername(username);
    if (!mounted || user == null || user.uid.isEmpty || user.uid == me) return;

    final following = await UserService().isFollowingUser(
      currentUid: me,
      targetUid: user.uid,
    );
    if (!mounted) return;
    setState(() {
      _targetUserId = user.uid;
      _isFollowingAuthor = following;
    });
  }

  Future<void> _onFollowTap() async {
    if (_followBusy) return;
    final me = AuthService().currentUser?.uid;
    final target = _targetUserId;
    if (me == null || me.isEmpty || target == null || target.isEmpty || me == target) {
      return;
    }
    setState(() => _followBusy = true);
    try {
      if (_isFollowingAuthor) {
        await UserService().unfollowUser(currentUid: me, targetUid: target);
      } else {
        await UserService().followUser(currentUid: me, targetUid: target);
      }
      if (!mounted) return;
      setState(() => _isFollowingAuthor = !_isFollowingAuthor);
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeActive = TickerMode.of(context);
    if (routeActive == _isRouteActive) return;
    _isRouteActive = routeActive;
    _syncPlayback();
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
      setState(() {
        _controller = ctrl;
        _initialized = true;
      });
      _syncPlayback();
    } catch (_) {}
  }

  void _syncPlayback() {
    final controller = _controller;
    if (controller == null) return;
    final shouldPlay = widget.isActive && _isRouteActive && _isAppForeground;
    if (shouldPlay) {
      controller.play();
    } else {
      controller.pause();
    }
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
    _hideTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
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
            bottom: 40,
            right: 80,
            child: _UserInfo(
              post: widget.post,
              onSeeMore: widget.onSeeMore,
              onUserTap: _openUserProfile,
              isFollowing: _isFollowingAuthor,
              followBusy: _followBusy,
              onFollowTap: _onFollowTap,
            ),
          ),
          // ── Action buttons ────────────────────────────────────────────────
          Positioned(
            right: 12,
            bottom: 100,
            child: FeedActionButtons(
              viewCount: _formatCount(widget.post.viewCount),
              likeCount: _formatCount(widget.post.likeCount),
              commentCount: _formatCount(widget.post.commentCount),
              favoriteCount: _formatCount(widget.post.viewCount > 1000 ? widget.post.viewCount ~/ 2 : 123), // Dummy for now
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
                child: Image.asset(
                  isPlaying ? 'assets/vyooO_icons/Home/pause.png' : 'assets/vyooO_icons/Settings/Play video.png',
                  color: Colors.white,
                  width: 28,
                  height: 28,
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
                child: Image.asset(
                  _isMuted ? 'assets/vyooO_icons/Home/volume_mute.png' : 'assets/vyooO_icons/Upload_Story_Live/audio.png',
                  color: Colors.white,
                  width: 28,
                  height: 28,
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

  void _openUserProfile() {
    final username = widget.post.userHandle.replaceFirst('@', '').trim();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfileScreen(
          payload: UserProfilePayload(
            username: username.isNotEmpty ? username : widget.post.username,
            displayName: widget.post.username,
            avatarUrl: widget.post.userAvatarUrl,
            isVerified: false,
            postCount: 0,
            followerCount: widget.post.likeCount,
            followingCount: 0,
            bio: '',
            isCreator: true,
            isFollowing: false,
          ),
        ),
      ),
    );
  }
}

// ── User info ─────────────────────────────────────────────────────────────────

class _UserInfo extends StatelessWidget {
  const _UserInfo({
    required this.post,
    this.onSeeMore,
    this.onUserTap,
    this.onFollowTap,
    this.isFollowing = false,
    this.followBusy = false,
  });

  final FeedPost post;
  final VoidCallback? onSeeMore;
  final VoidCallback? onUserTap;
  final VoidCallback? onFollowTap;
  final bool isFollowing;
  final bool followBusy;

  static const Color _pinkAccent = Color(0xFFF81945);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: onUserTap,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white12,
                  backgroundImage: post.userAvatarUrl.isNotEmpty
                      ? NetworkImage(post.userAvatarUrl)
                      : null,
                  child: post.userAvatarUrl.isEmpty
                      ? Image.asset(
                          'assets/vyooO_icons/Home/profile_icon.png',
                          color: Colors.white,
                          width: 20,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onUserTap,
                        child: Text(
                          post.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: followBusy ? null : onFollowTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isFollowing ? Colors.white24 : _pinkAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            followBusy ? '...' : (isFollowing ? 'Following' : 'Follow'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: onUserTap,
                    child: Text(
                      post.userHandle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          post.caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onSeeMore,
          child: const Text(
            'See More',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.music_note_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Original Sound - ${post.username}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
