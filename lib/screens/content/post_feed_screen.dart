import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/controllers/reels_controller.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_bottom_navigation.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../core/wrappers/main_nav_wrapper.dart';
import '../../features/comments/widgets/comments_bottom_sheet.dart';
import '../../features/reel/widgets/not_interested_sheet.dart';
import '../../features/reel/widgets/reel_more_options_sheet.dart';
import '../../features/reel/widgets/report_sheet.dart';
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
  final Map<String, bool> _favoriteReels = {};
  final Map<String, bool> _privateSavedReels = {};
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
    final ids = _orderedPosts
        .map((p) => _asString(p['id']).trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return;
    final liked = await _reelsController.getLikedReelIds(ids);
    final favorite = await _reelsController.getFavoriteReelIds(ids);
    final private = await _reelsController.getPrivateSavedReelIds(ids);
    if (!mounted) return;
    setState(() {
      for (final id in ids) {
        _likedReels[id] = liked.contains(id);
        _favoriteReels[id] = favorite.contains(id);
        _privateSavedReels[id] = private.contains(id);
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

  void _adjustPostStat(String reelId, String key, int delta) {
    final i = _orderedPosts.indexWhere((p) => _asString(p['id']) == reelId);
    if (i < 0) return;
    final current = _asInt(_orderedPosts[i][key]);
    setState(() {
      _orderedPosts[i][key] = (current + delta).clamp(0, 1 << 30);
    });
  }

  Future<void> _onLike(Map<String, dynamic> post) async {
    final reelId = _asString(post['id']).trim();
    if (reelId.isEmpty) return;
    final currentlyLiked = _likedReels[reelId] ?? false;
    final newState = await _reelsController.likeReel(
      reelId: reelId,
      currentlyLiked: currentlyLiked,
    );
    if (!mounted) return;
    setState(() => _likedReels[reelId] = newState);
    _adjustPostStat(reelId, 'likes', newState ? 1 : -1);
  }

  Future<void> _onSave(Map<String, dynamic> post) async {
    final reelId = _asString(post['id']).trim();
    if (reelId.isEmpty) return;
    final currentlyFavorite = _favoriteReels[reelId] ?? false;
    final newState = await _reelsController.toggleFavoriteReel(
      reelId: reelId,
      currentlyFavorite: currentlyFavorite,
    );
    if (!mounted) return;
    setState(() => _favoriteReels[reelId] = newState);
    _adjustPostStat(reelId, 'saves', newState ? 1 : -1);
  }

  void _onComment(Map<String, dynamic> post) {
    final reelId = _asString(post['id']).trim();
    if (reelId.isEmpty) return;
    showCommentsBottomSheet(
      context,
      reelId: reelId,
      onCommentCountChanged: (delta) =>
          _adjustPostStat(reelId, 'comments', delta),
    );
  }

  void _onShare(Map<String, dynamic> post) {
    final reelId = _asString(post['id']).trim();
    if (reelId.isEmpty) return;
    showShareBottomSheet(
      context,
      reelId: reelId,
      thumbnailUrl: _mediaUrl(post),
      authorName: _asString(post['username']).isNotEmpty
          ? _asString(post['username'])
          : (widget.payload?.creatorName ?? 'Creator'),
      onShareViaNative: () => _reelsController.shareReel(reelId: reelId),
      onCopyLink: () {},
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

  void _openOwnerPostOptions(Map<String, dynamic> post) {
    final isVideo = _isVideoPost(post);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: Colors.white),
              title: Text(
                isVideo ? 'Edit video caption' : 'Edit photo caption',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _editCaption(post);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.deleteRed,
              ),
              title: const Text(
                'Delete post',
                style: TextStyle(color: AppColors.deleteRed),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _deletePost(post);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payload ?? const PostFeedPayload();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.feed,
        child: Column(
          children: [
            SafeArea(child: _buildAppBar(context)),
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
                          final reelId = _asString(post['id']).trim();
                          return _PostCard(
                            key: _keyFor(index),
                            index: index,
                            activeIndex: _activeVideoIndex,
                            post: post,
                            fallbackCreatorName: p.creatorName,
                            fallbackAvatarUrl: p.avatarUrl,
                            fallbackIsVerified: p.isVerified,
                            isLiked: _likedReels[reelId] ?? false,
                            isSaved: _favoriteReels[reelId] ?? false,
                            onLike: () => _onLike(post),
                            onComment: () => _onComment(post),
                            onSave: () => _onSave(post),
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
    required this.onComment,
    required this.onSave,
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
  final VoidCallback onComment;
  final VoidCallback onSave;
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
    if (title.isNotEmpty) {
      buffer.write(title);
    } else if (oldCaption.isNotEmpty && description.isEmpty && tagsList.isEmpty) {
      // Fallback for old content
      buffer.write(oldCaption);
    }

    if (description.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write(description);
    }

    if (tagsList.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write(tagsList.map((t) => '#${t.toString().trim()}').join(' '));
    }

    final fullText = buffer.toString();
    if (fullText.isEmpty) return const SizedBox.shrink();

    return CaptionWithHashtags(
      text: fullText,
      maxLines: 10,
      overflow: TextOverflow.ellipsis,
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
          const SizedBox(height: AppSpacing.sm),
          _buildCaption(),
          const SizedBox(height: AppSpacing.sm),
          if (mediaUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  AspectRatio(
                    aspectRatio: 800 / 900,
                    child:
                        isVideoPost &&
                            _asString(post['videoUrl']).trim().isNotEmpty
                        ? ValueListenableBuilder<int>(
                            valueListenable: activeIndex,
                            builder: (_, currentActive, _) => ReelItemWidget(
                              videoUrl: _asString(post['videoUrl']).trim(),
                              isVisible: currentActive == index,
                              thumbnailUrl: mediaUrl,
                            ),
                          )
                        : Image.network(mediaUrl, fit: BoxFit.cover),
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
                  if (_asInt(post['mediaCount']) > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          _asInt(post['mediaCount']).clamp(2, 5),
                          (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: 4.5,
                            height: 4.5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == 0
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
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
              const SizedBox(width: 4),
              Text(
                _formatCount(_asInt(post['likes'])),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              GestureDetector(
                onTap: onComment,
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 20,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${_asInt(post['comments'])}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12.5,
                ),
              ),
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
              const SizedBox(width: AppSpacing.md),
              GestureDetector(
                onTap: onShare,
                child: Icon(
                  Icons.reply_rounded,
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
