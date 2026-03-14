import 'package:flutter/material.dart';

import '../../../../core/mock/mock_feed_data.dart';
import 'feed_action_buttons.dart';

/// Single feed video item: full-screen thumbnail, gradient overlay, user info, action buttons.
class FeedVideoItem extends StatelessWidget {
  const FeedVideoItem({
    super.key,
    required this.post,
    this.isLiked = false,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onMore,
    this.onSeeMore,
  });

  final FeedPost post;
  final bool isLiked;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onMore;
  final VoidCallback? onSeeMore;

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.network(
            post.thumbnailUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey[900],
              child: const Icon(
                Icons.broken_image_outlined,
                size: 64,
                color: Colors.white38,
              ),
            ),
          ),
        ),
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
                  Colors.black.withValues(alpha: 0.6),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          bottom: 60,
          right: 80,
          child: _UserInfo(post: post, onSeeMore: onSeeMore),
        ),
        Positioned(
          right: 12,
          bottom: 120,
          child: FeedActionButtons(
            viewCount: _formatCount(post.viewCount),
            likeCount: _formatCount(post.likeCount),
            commentCount: _formatCount(post.commentCount),
            isLiked: isLiked,
            onLike: onLike,
            onComment: onComment,
            onShare: onShare,
            onMore: onMore,
          ),
        ),
      ],
    );
  }
}

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
