import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/controllers/reels_controller.dart';
import '../../core/models/reel_media_item.dart';
import '../../core/models/video_360_metadata.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_bottom_navigation.dart';
import '../../core/widgets/post_media_carousel.dart';
import '../../core/widgets/double_tap_like_overlay.dart';
import '../../core/widgets/post_feed_screen_background.dart';
import '../../core/wrappers/main_nav_wrapper.dart';
import '../../features/comments/widgets/comments_bottom_sheet.dart';
import '../../features/reel/widgets/not_interested_sheet.dart';
import '../../core/models/reel_count_privacy.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/reel_engagement.dart';
import '../../core/moderation/content_moderation.dart';
import '../../features/moderation/widgets/report_moderation_cover.dart';
import '../../features/reel/widgets/owner_post_options_sheet.dart';
import '../../features/reel/widgets/reel_more_options_sheet.dart';
import '../../features/reel/widgets/report_sheet.dart';
import '../../features/reel/widgets/report_status_bar.dart';
import '../../features/share/widgets/share_bottom_sheet.dart';
import '../../widgets/caption_with_hashtags.dart';
import '../../widgets/reel_item_widget.dart';

/// Payload for opening the post feed (e.g. from profile post grid).
class PostFeedPayload {
  const PostFeedPayload({
    this.initialIndex = 0,
    this.posts = const [],
    this.creatorName = 'Matt Rife',
    this.creatorHandle = '@mattrife_x',
    this.avatarUrl = '',
    this.isVerified = true,
    this.screenTitle = 'Posts',
  });

  final int initialIndex;
  final List<Map<String, dynamic>> posts;
  final String creatorName;
  final String creatorHandle;
  final String avatarUrl;
  final bool isVerified;
  final String screenTitle;
}

/// Full-screen posts feed: app bar "Posts", scrollable post cards (avatar, caption, media, like/comment/share/save).
/// Design-only; matches Posts view from spec.
class PostFeedScreen extends StatefulWidget {
  const PostFeedScreen({super.key, this.payload});

  final PostFeedPayload? payload;

  @override
  State<PostFeedScreen> createState() => _PostFeedScreenState();
}

class _PostFeedScreenState extends State<PostFeedScreen> {
  final ReelsController _reelsController = ReelsController();
  final Map<String, bool> _likedReels = {};
  final Set<String> _likeInFlight = {};
  final Map<String, bool> _favoriteReels = {};
  final Map<String, bool> _privateSavedReels = {};
  final Map<String, bool> _repostedSourceReels = {};
  late final List<Map<String, dynamic>> _orderedPosts;
  int _currentBottomNavIndex = 4;

  // Tracks which post card is currently the "most visible" one in the
  // ListView so only that ReelItemWidget auto-plays. Prevents overlapping
  // audio while scrolling through video posts.
  final ValueNotifier<int> _activeVideoIndex = ValueNotifier<int>(0);
  final Map<int, GlobalKey> _itemKeys = <int, GlobalKey>{};
  final GlobalKey _listKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final p = widget.payload ?? const PostFeedPayload();
    final source = p.posts.map((e) => Map<String, dynamic>.from(e)).toList();
    if (source.isEmpty) {
      _orderedPosts = [];
      return;
    }
    final safeStart = p.initialIndex.clamp(0, source.length - 1);
    _orderedPosts = [
      ...source.sublist(safeStart),
      ...source.sublist(0, safeStart),
    ];
    _warmInteractionState();
  }

  @override
  void dispose() {
    _activeVideoIndex.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(int index) =>
      _itemKeys.putIfAbsent(index, () => GlobalKey());

  /// Recompute which post card overlaps the viewport center the most.
  /// Called from a [NotificationListener] on the [ListView] so the active
  /// index updates as the user scrolls.
  void _updateActiveVideoIndex() {
    if (!mounted) return;
    final listContext = _listKey.currentContext;
    if (listContext == null) return;
    final listBox = listContext.findRenderObject();
    if (listBox is! RenderBox || !listBox.hasSize) return;
    final viewportTop = listBox.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + listBox.size.height;

    int bestIndex = _activeVideoIndex.value;
    double bestOverlap = -1;
    _itemKeys.forEach((index, key) {
      final ctx = key.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final top = box.localToGlobal(Offset.zero).dy;
      final bottom = top + box.size.height;
      final overlap =
          (bottom.clamp(viewportTop, viewportBottom) -
                  top.clamp(viewportTop, viewportBottom))
              .toDouble();
      if (overlap > bestOverlap) {
        bestOverlap = overlap;
        bestIndex = index;
      }
    });
    if (bestOverlap > 0 && _activeVideoIndex.value != bestIndex) {
      _activeVideoIndex.value = bestIndex;
    }
  }

  Future<void> _warmInteractionState() async {
    final engagementIds = _orderedPosts
        .map((p) => ReelEngagement.sourceReelId(p))
        .where((id) => id.isNotEmpty)
        .toSet();
    if (engagementIds.isEmpty) return;
    final liked = await _reelsController.getLikedReelIds(engagementIds);
    final favorite = await _reelsController.getFavoriteReelIds(engagementIds);
    final private =
        await _reelsController.getPrivateSavedReelIds(engagementIds);
    final reposted =
        await _reelsController.getRepostedSourceReelIds(engagementIds);
    if (!mounted) return;
    setState(() {
      for (final id in engagementIds) {
        _likedReels[id] = liked.contains(id);
        _favoriteReels[id] = favorite.contains(id);
        _privateSavedReels[id] = private.contains(id);
        _repostedSourceReels[id] = reposted.contains(id);
      }
    });
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static String _asString(dynamic value) => value?.toString() ?? '';

  static String _formatRelativeTime(dynamic raw) {
    final Timestamp? ts = raw is Timestamp ? raw : null;
    if (ts == null) return 'Just now';
    final dt = ts.toDate();
    final now = DateTime.now();
    final d = now.difference(dt);
    if (d.inSeconds < 60) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays} day${d.inDays == 1 ? '' : 's'} ago';
    final weeks = d.inDays ~/ 7;
    if (weeks < 5) return '$weeks week${weeks == 1 ? '' : 's'} ago';
    final months = d.inDays ~/ 30;
    if (months < 12) return '$months month${months == 1 ? '' : 's'} ago';
    final years = d.inDays ~/ 365;
    return '$years year${years == 1 ? '' : 's'} ago';
  }

  static String _mediaUrl(Map<String, dynamic> post) {
    final mediaType = (_asString(post['mediaType'])).toLowerCase();
    final image = _asString(post['imageUrl']).trim();
    final thumb = _asString(post['thumbnailUrl']).trim();
    final video = _asString(post['videoUrl']).trim();
    if (mediaType == 'image') {
      return image.isNotEmpty ? image : thumb;
    }
    if (thumb.isNotEmpty) return thumb;
    if (image.isNotEmpty) return image;
    return _thumbnailFromVideoUrl(video);
  }

  static bool _isVideoPost(Map<String, dynamic> post) {
    final mediaType = (_asString(post['mediaType'])).toLowerCase();
    if (mediaType == 'video') return true;
    if (mediaType == 'image') return false;
    return _asString(post['videoUrl']).trim().isNotEmpty;
  }

  static String _thumbnailFromVideoUrl(String videoUrl) {
    if (videoUrl.isEmpty) return '';
    try {
      final uri = Uri.parse(videoUrl);
      final videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      if (videoId.isEmpty) return '';
      return 'https://videodelivery.net/$videoId/thumbnails/thumbnail.jpg';
    } catch (_) {
      return '';
    }
  }

  void _adjustPostStat(String engagementId, String key, int delta) {
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < _orderedPosts.length; i++) {
        if (ReelEngagement.sourceReelId(_orderedPosts[i]) != engagementId) {
          continue;
        }
        final current = _asInt(_orderedPosts[i][key]);
        final next = (current + delta).clamp(0, 1 << 30);
        _orderedPosts[i][key] = next;
        if (key == 'reposts' || key == 'shares') {
          _orderedPosts[i]['reposts'] = next;
          _orderedPosts[i]['shares'] = next;
        }
      }
    });
  }

  String _sourceOwnerId(Map<String, dynamic> post) {
    if (ReelEngagement.isRepostStub(post)) {
      return _asString(post['repostOfUserId']).trim();
    }
    return _asString(post['userId']).trim();
  }

  bool _canRepostPost(Map<String, dynamic> post) {
    final uid = AuthService().currentUser?.uid ?? '';
    if (uid.isEmpty) return false;
    return _sourceOwnerId(post) != uid;
  }

  Future<void> _onRepostToggle(Map<String, dynamic> post) async {
    final sourceId = ReelEngagement.sourceReelId(post);
    if (sourceId.isEmpty) return;
    final wasReposted = _repostedSourceReels[sourceId] ?? false;
    if (wasReposted) {
      final ok = await _reelsController.unrepostReel(sourceReelId: sourceId);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove repost. Try again.')),
        );
        return;
      }
      setState(() => _repostedSourceReels[sourceId] = false);
      _adjustPostStat(sourceId, 'reposts', -1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from your profile')),
      );
      return;
    }
    final stubId = await _reelsController.repostReel(sourceReelId: sourceId);
    if (!mounted) return;
    if (stubId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not repost. Try again.')),
      );
      return;
    }
    setState(() => _repostedSourceReels[sourceId] = true);
    _adjustPostStat(sourceId, 'reposts', 1);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reposted to your profile')),
    );
  }

  Future<void> _onLike(Map<String, dynamic> post) async {
    final engagementId = ReelEngagement.sourceReelId(post);
    if (engagementId.isEmpty || _likeInFlight.contains(engagementId)) {
      debugPrint(
        '[Vyooo][Like][UI][PostFeed] skip engagementId=$engagementId',
      );
      return;
    }

    final currentlyLiked = _likedReels[engagementId] ?? false;
    final wantLiked = !currentlyLiked;
    debugPrint(
      '[Vyooo][Like][UI][PostFeed] tap engagementId=$engagementId '
      'currentlyLiked=$currentlyLiked wantLiked=$wantLiked',
    );
    _likeInFlight.add(engagementId);
    setState(() => _likedReels[engagementId] = wantLiked);
    _adjustPostStat(engagementId, 'likes', wantLiked ? 1 : -1);

    final actual = await _reelsController.likeReel(
      reelId: engagementId,
      like: wantLiked,
    );
    _likeInFlight.remove(engagementId);
    if (!mounted) return;

    debugPrint(
      '[Vyooo][Like][UI][PostFeed] result engagementId=$engagementId '
      'wantLiked=$wantLiked actual=$actual',
    );

    if (actual != wantLiked) {
      debugPrint('[Vyooo][Like][UI][PostFeed] ROLLBACK engagementId=$engagementId');
      setState(() => _likedReels[engagementId] = actual);
      _adjustPostStat(engagementId, 'likes', wantLiked ? -1 : 1);
    }
  }

  void _onDoubleTapLike(Map<String, dynamic> post) {
    final engagementId = ReelEngagement.sourceReelId(post);
    if (engagementId.isEmpty || _likeInFlight.contains(engagementId)) return;
    final alreadyLiked = _likedReels[engagementId] ?? false;
    if (!alreadyLiked) {
      _onLike(post);
    }
  }

  Future<void> _onSave(Map<String, dynamic> post) async {
    final engagementId = ReelEngagement.sourceReelId(post);
    if (engagementId.isEmpty) return;
    final currentlyFavorite = _favoriteReels[engagementId] ?? false;
    final newState = await _reelsController.toggleFavoriteReel(
      reelId: engagementId,
      currentlyFavorite: currentlyFavorite,
    );
    if (!mounted) return;
    setState(() => _favoriteReels[engagementId] = newState);
    _adjustPostStat(engagementId, 'saves', newState ? 1 : -1);
  }

  void _onComment(Map<String, dynamic> post) {
    final engagementId = ReelEngagement.sourceReelId(post);
    if (engagementId.isEmpty) return;
    showCommentsBottomSheet(
      context,
      reelId: engagementId,
      onCommentCountChanged: (delta) =>
          _adjustPostStat(engagementId, 'comments', delta),
    );
  }

  void _onShare(Map<String, dynamic> post) {
    final sourceId = ReelEngagement.sourceReelId(post);
    if (sourceId.isEmpty) return;
    final uid = AuthService().currentUser?.uid ?? '';
    showShareBottomSheet(
      context,
      reelId: sourceId,
      thumbnailUrl: _mediaUrl(post),
      authorName: _asString(post['username']).isNotEmpty
          ? _asString(post['username'])
          : (widget.payload?.creatorName ?? 'Creator'),
      isOwnPost: _sourceOwnerId(post) == uid,
      isReposted: _repostedSourceReels[sourceId] ?? false,
      onRepost: () => _onRepostToggle(post),
      onRemoveRepost: () => _onRepostToggle(post),
      onShareViaNative: () => _reelsController.shareReel(reelId: sourceId),
      onCopyLink: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Link copied to clipboard'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  Future<void> _onPrivateSaveFromSheet(String reelId) async {
    final currently = _privateSavedReels[reelId] ?? false;
    final newState = await _reelsController.togglePrivateSavedReel(
      reelId: reelId,
      currentlySaved: currently,
    );
    if (!mounted) return;
    setState(() => _privateSavedReels[reelId] = newState);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newState ? 'Saved privately' : 'Removed from private saves'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onMoreOptions(Map<String, dynamic> post) {
    final reelId = _asString(post['id']).trim();
    if (reelId.isEmpty) return;
    if (_isOwnerPost(post)) {
      _openOwnerPostOptions(post);
      return;
    }
    final authorId = _asString(post['userId']).trim();
    showReelMoreOptionsSheet(
      context,
      reelId: reelId,
      playbackSpeed: 'Normal',
      quality: 'Auto (1080p HD)',
      onDownload: () {},
      onSavePrivately: () => _onPrivateSaveFromSheet(reelId),
      onReport: () => showReportSheet(
        context,
        username: _asString(post['username']).isNotEmpty
            ? _asString(post['username'])
            : 'User',
        avatarUrl: _asString(post['avatarUrl']),
        targetUserId: authorId.isEmpty ? null : authorId,
        reelId: reelId,
        isFollowing: false,
      ),
      onNotInterested: () => showNotInterestedSheet(context),
      onCaptions: () {},
      onPlaybackSpeed: () {},
      onQuality: () {},
      onManagePreferences: () {},
      onWhyThisPost: () {},
    );
  }

  bool _isOwnerPost(Map<String, dynamic> post) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUid.isEmpty) return false;
    return _asString(post['userId']).trim() == currentUid;
  }

  Future<void> _editCaption(Map<String, dynamic> post) async {
    final reelId = _asString(post['id']).trim();
    if (reelId.isEmpty) return;
    final existing = _asString(post['caption']);
    final controller = TextEditingController(text: existing);
    final nextCaption = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit caption'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Write a caption'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted || nextCaption == null || nextCaption == existing) return;
    try {
      await FirebaseFirestore.instance.collection('reels').doc(reelId).update({
        'caption': nextCaption,
      });
      if (!mounted) return;
      setState(() {
        final i = _orderedPosts.indexWhere((r) => _asString(r['id']) == reelId);
        if (i >= 0) _orderedPosts[i]['caption'] = nextCaption;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update caption. Please try again.'),
        ),
      );
    }
  }

  Future<void> _deletePost(Map<String, dynamic> post) async {
    final reelId = _asString(post['id']).trim();
    if (reelId.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text(
          'This will remove this post from your profile feed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await FirebaseFirestore.instance.collection('reels').doc(reelId).delete();
      if (!mounted) return;
      setState(() {
        _orderedPosts.removeWhere((r) => _asString(r['id']) == reelId);
      });
      if (_orderedPosts.isEmpty && mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete post. Please try again.'),
        ),
      );
    }
  }

  Future<void> _updateCountPrivacy(
    Map<String, dynamic> post,
    String field,
    bool hidden,
  ) async {
    final reelId = _asString(post['id']).trim();
    if (reelId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('reels')
          .doc(reelId)
          .update({field: hidden});
      if (!mounted) return;
      setState(() {
        final i = _orderedPosts.indexWhere((r) => _asString(r['id']) == reelId);
        if (i >= 0) _orderedPosts[i][field] = hidden;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update privacy. Please try again.'),
        ),
      );
    }
  }

  void _openOwnerPostOptions(Map<String, dynamic> post) {
    if (ReelEngagement.isRepostStub(post)) {
      final sourceId = ReelEngagement.sourceReelId(post);
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF141414),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.undo_rounded, color: Colors.white),
                title: const Text(
                  'Remove repost from profile',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _onRepostToggle(post);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text(
                  'Delete from profile',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  if (sourceId.isEmpty) return;
                  await _reelsController.unrepostReel(sourceReelId: sourceId);
                  if (!mounted) return;
                  setState(() {
                    _repostedSourceReels[sourceId] = false;
                    _orderedPosts.removeWhere(
                      (p) => _asString(p['id']) == _asString(post['id']),
                    );
                  });
                  if (_orderedPosts.isEmpty && mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
        ),
      );
      return;
    }
    showOwnerPostOptionsSheet(
      context: context,
      post: post,
      isVideo: _isVideoPost(post),
      onPrivacyChanged: (field, hidden) =>
          _updateCountPrivacy(post, field, hidden),
      onEditCaption: () => _editCaption(post),
      onDelete: () => _deletePost(post),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payload ?? const PostFeedPayload();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PostFeedScreenBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: _orderedPosts.isEmpty
                      ? Center(
                          child: Text(
                            'No posts found',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification is ScrollUpdateNotification ||
                                notification is ScrollEndNotification) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _updateActiveVideoIndex();
                              });
                            }
                            return false;
                          },
                          child: ListView.builder(
                            key: _listKey,
                            padding: const EdgeInsets.only(bottom: 10, top: 2),
                            itemCount: _orderedPosts.length,
                            itemBuilder: (context, index) {
                              final post = _orderedPosts[index];
                              final engagementId =
                                  ReelEngagement.sourceReelId(post);
                              return _PostCard(
                                key: _keyFor(index),
                                index: index,
                                activeIndex: _activeVideoIndex,
                                post: post,
                                fallbackCreatorName: p.creatorName,
                                fallbackAvatarUrl: p.avatarUrl,
                                fallbackIsVerified: p.isVerified,
                                isLiked: _likedReels[engagementId] ?? false,
                                isSaved: _favoriteReels[engagementId] ?? false,
                                showRepost: _canRepostPost(post),
                                isReposted:
                                    _repostedSourceReels[engagementId] ?? false,
                                onLike: () => _onLike(post),
                                onDoubleTapLike: () => _onDoubleTapLike(post),
                                onComment: () => _onComment(post),
                                onSave: () => _onSave(post),
                                onRepost: () => _onRepostToggle(post),
                                onShare: () => _onShare(post),
                                onMore: () => _onMoreOptions(post),
                              );
                            },
                          ),
                        ),
                ),
                AppBottomNavigation(
                  currentIndex: _currentBottomNavIndex,
                  onTap: (index) {
                    if (index == 4) return;
                    setState(() => _currentBottomNavIndex = index);
                    _navigateFromBottomNav(context, index);
                  },
                  profileImageUrl: p.avatarUrl,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final title = (widget.payload?.screenTitle ?? 'Posts').trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, AppSpacing.xs, 2),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 22,
            ),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title.isEmpty ? 'Posts' : title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateFromBottomNav(BuildContext context, int index) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => MainNavWrapper(initialIndex: index),
      ),
      (route) => false,
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    super.key,
    required this.index,
    required this.activeIndex,
    required this.post,
    required this.fallbackCreatorName,
    required this.fallbackAvatarUrl,
    required this.fallbackIsVerified,
    required this.isLiked,
    required this.isSaved,
    required this.onLike,
    required this.onDoubleTapLike,
    required this.onComment,
    required this.onSave,
    required this.showRepost,
    required this.isReposted,
    required this.onRepost,
    required this.onShare,
    required this.onMore,
  });

  final int index;
  final ValueListenable<int> activeIndex;
  final Map<String, dynamic> post;
  final String fallbackCreatorName;
  final String fallbackAvatarUrl;
  final bool fallbackIsVerified;
  final bool isLiked;
  final bool isSaved;
  final VoidCallback onLike;
  final VoidCallback onDoubleTapLike;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final bool showRepost;
  final bool isReposted;
  final VoidCallback onRepost;
  final VoidCallback onShare;
  final VoidCallback onMore;

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static String _asString(dynamic value) => value?.toString() ?? '';

  static String _formatRelativeTime(dynamic raw) {
    final Timestamp? ts = raw is Timestamp ? raw : null;
    if (ts == null) return 'Just now';
    final d = DateTime.now().difference(ts.toDate());
    if (d.inSeconds < 60) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays} day${d.inDays == 1 ? '' : 's'} ago';
    return '${(d.inDays / 7).floor()}w ago';
  }

  static String _mediaUrl(Map<String, dynamic> post) {
    final mediaType = (_asString(post['mediaType'])).toLowerCase();
    final image = _asString(post['imageUrl']).trim();
    final thumb = _asString(post['thumbnailUrl']).trim();
    final video = _asString(post['videoUrl']).trim();
    if (mediaType == 'image') {
      return image.isNotEmpty ? image : thumb;
    }
    if (thumb.isNotEmpty) return thumb;
    if (image.isNotEmpty) return image;
    return _thumbnailFromVideoUrl(video);
  }

  static String _thumbnailFromVideoUrl(String videoUrl) {
    if (videoUrl.isEmpty) return '';
    try {
      final uri = Uri.parse(videoUrl);
      final videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      if (videoId.isEmpty) return '';
      return 'https://videodelivery.net/$videoId/thumbnails/thumbnail.jpg';
    } catch (_) {
      return '';
    }
  }

  static bool _isVideoPost(Map<String, dynamic> post) {
    final mediaType = (_asString(post['mediaType'])).toLowerCase();
    if (mediaType == 'video') return true;
    if (mediaType == 'image') return false;
    return _asString(post['videoUrl']).trim().isNotEmpty;
  }

  Widget _buildCaption() {
    final title = _asString(post['title']).trim();
    final description = _asString(post['description']).trim();
    final tagsList = post['tags'] as List? ?? [];
    final oldCaption = _asString(post['caption']).trim();

    final buffer = StringBuffer();
    if (description.isNotEmpty) {
      buffer.write(description);
    }
    if (tagsList.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write(tagsList.map((t) => '#${t.toString().trim()}').join(' '));
    }

    var fullText = buffer.toString();
    if (fullText.isEmpty) {
      // Legacy reels without structured fields — skip when caption is only the
      // stored upload title (title is not shown on the feed).
      fullText = title.isEmpty ? oldCaption : '';
    }

    final locationMap = post['location'] as Map<String, dynamic>?;
    final locationName = (locationMap?['name'] as String?)?.trim() ?? '';
    final locationAddress = (locationMap?['address'] as String?)?.trim() ?? '';

    if (fullText.isEmpty && locationName.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (fullText.isNotEmpty)
          CaptionWithHashtags(
            text: fullText,
            maxLines: 10,
            overflow: TextOverflow.ellipsis,
          ),
        if (locationName.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  locationName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (locationAddress.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(
                locationAddress,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final creatorName = _asString(post['username']).trim().isNotEmpty
        ? _asString(post['username']).trim()
        : fallbackCreatorName;
    final avatarUrl = _asString(post['avatarUrl']).trim().isNotEmpty
        ? _asString(post['avatarUrl']).trim()
        : fallbackAvatarUrl;
    final isVerified = post['isVerified'] == true || fallbackIsVerified;
    final mediaUrl = _mediaUrl(post);
    final isVideoPost = _isVideoPost(post);
    final mediaItems = ReelMediaItem.listFromPost(post);
    final privacy = ReelCountPrivacy.fromMap(post);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, AppSpacing.sm, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl.isEmpty
                    ? const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 18,
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          creatorName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatRelativeTime(post['createdAt']),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onMore,
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 24,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              ),
            ],
          ),
          if (ReelEngagement.isRepostStub(post)) ...[
            Row(
              children: [
                const Icon(Icons.repeat_rounded, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Reposted from ${_asString(post['repostOfUsername']).isNotEmpty ? _asString(post['repostOfUsername']) : 'creator'}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (ReportStatusThresholds.severityFor(_asInt(post['reportCount'])) !=
              ReportSeverity.none) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: ReportStatusBar.fromReel(post),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          _buildCaption(),
          const SizedBox(height: AppSpacing.sm),
          if (mediaItems.length > 1)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 800 / 900,
                child: ValueListenableBuilder<int>(
                  valueListenable: activeIndex,
                  builder: (_, currentActive, _) => PostMediaCarousel(
                    items: mediaItems,
                    video360: Video360Metadata.fromPost(post),
                    isVisible: currentActive == index,
                    onDoubleTap: onDoubleTapLike,
                  ),
                ),
              ),
            )
          else if (mediaUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  ModeratedContentWrapper(
                    contentId: _asString(post['id']),
                    contentKind: ContentModeration.kindFromReel(post),
                    ownerId: _asString(post['userId']),
                    moderation: post['moderation'] is Map
                        ? Map<String, dynamic>.from(post['moderation'] as Map)
                        : null,
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 800 / 900,
                      child:
                          isVideoPost &&
                              _asString(post['videoUrl']).trim().isNotEmpty
                          ? ValueListenableBuilder<int>(
                              valueListenable: activeIndex,
                              builder: (_, currentActive, _) => ReelItemWidget(
                                videoUrl: _asString(post['videoUrl']).trim(),
                                video360: Video360Metadata.fromPost(post),
                                isVisible: currentActive == index,
                                thumbnailUrl: mediaUrl,
                                onDoubleTap: onDoubleTapLike,
                              ),
                            )
                          : DoubleTapLikeOverlay(
                              onDoubleTap: onDoubleTapLike,
                              child: Image.network(
                                mediaUrl,
                                fit: BoxFit.cover,
                                cacheWidth:
                                    (MediaQuery.of(context).size.width *
                                            MediaQuery.of(
                                              context,
                                            ).devicePixelRatio)
                                        .round(),
                              ),
                            ),
                    ),
                  ),
                  if (isVideoPost && _asString(post['videoUrl']).trim().isEmpty)
                    const Positioned(
                      top: 10,
                      right: 10,
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (privacy.showViews()) ...[
                Icon(
                  Icons.remove_red_eye_outlined,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  privacy.displayCount(
                    ReelCountMetric.views,
                    _asInt(post['views']),
                  ),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
              ],
              GestureDetector(
                onTap: onLike,
                child: Icon(
                  isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_outline_rounded,
                  color: isLiked
                      ? const Color(0xFFF2486A)
                      : Colors.white.withValues(alpha: 0.9),
                  size: 21,
                ),
              ),
              if (privacy.showLikes()) ...[
                const SizedBox(width: 4),
                Text(
                  privacy.displayCount(
                    ReelCountMetric.likes,
                    _asInt(post['likes']),
                  ),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12.5,
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.lg),
              GestureDetector(
                onTap: onComment,
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 20,
                ),
              ),
              if (privacy.showComments()) ...[
                const SizedBox(width: 4),
                Text(
                  privacy.displayCount(
                    ReelCountMetric.comments,
                    _asInt(post['comments']),
                  ),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12.5,
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.md),
              GestureDetector(
                onTap: onSave,
                child: Icon(
                  isSaved ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isSaved
                      ? const Color(0xFFFFD700)
                      : Colors.white.withValues(alpha: 0.9),
                  size: 20,
                ),
              ),
              if (privacy.showSaves()) ...[
                const SizedBox(width: 4),
                Text(
                  privacy.displayCount(
                    ReelCountMetric.saves,
                    _asInt(post['saves']),
                  ),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12.5,
                  ),
                ),
              ],
              if (showRepost) ...[
                const SizedBox(width: AppSpacing.md),
                GestureDetector(
                  onTap: onRepost,
                  child: Icon(
                    Icons.repeat_rounded,
                    color: isReposted
                        ? const Color(0xFFF2486A)
                        : Colors.white.withValues(alpha: 0.9),
                    size: 21,
                  ),
                ),
                if (privacy.showShares()) ...[
                  const SizedBox(width: 4),
                  Text(
                    privacy.displayCount(
                      ReelCountMetric.shares,
                      ReelEngagement.repostCount(post),
                    ),
                    style: TextStyle(
                      color: isReposted
                          ? const Color(0xFFF2486A)
                          : Colors.white.withValues(alpha: 0.9),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
              const SizedBox(width: AppSpacing.md),
              GestureDetector(
                onTap: onShare,
                child: Icon(
                  Icons.ios_share_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
