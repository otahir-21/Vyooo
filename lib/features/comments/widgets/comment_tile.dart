import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../comment_text_styles.dart';
import '../models/comment.dart';

/// Single comment row: avatar, username, time, text, Reply/View replies, like.
class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    this.isReply = false,
    this.onReply,
    this.onLike,
    this.onViewReplies,
    this.onLongPress,
    this.isHighlighted = false,
  });

  final Comment comment;
  final bool isReply;
  final VoidCallback? onReply;
  final VoidCallback? onLike;
  final VoidCallback? onViewReplies;
  final VoidCallback? onLongPress;
  final bool isHighlighted;

  static const double _avatarSize = 59;
  static const double _avatarSizeReply = 25;
  static const double _likeIconSize = 12;

  @override
  Widget build(BuildContext context) {
    final avatarSize = isReply ? _avatarSizeReply : _avatarSize;
    final initial = comment.username.trim().isNotEmpty
        ? comment.username.trim()[0].toUpperCase()
        : '?';

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onLongPress?.call();
      },
      child: Container(
        color: isHighlighted
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.transparent,
        padding: EdgeInsets.fromLTRB(
          isReply ? 65 : 13,
          isReply ? 6 : 10,
          13,
          isReply ? 6 : 10,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CommentAvatar(
              avatarUrl: comment.avatarUrl,
              size: avatarSize,
              fallbackInitial: initial,
            ),
            SizedBox(width: isReply ? 12 : 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          comment.username,
                          style: CommentTextStyles.username(
                            verified: comment.isVerified,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (comment.isVerified) ...[
                        const SizedBox(width: 4),
                        const _VerifiedBadge(),
                      ],
                      const SizedBox(width: 16),
                      Text(
                        comment.timeAgo,
                        style: CommentTextStyles.timestamp,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  Text(
                    comment.text,
                    style: CommentTextStyles.body,
                  ),
                  const SizedBox(height: 6),

                  Row(
                    children: [
                      GestureDetector(
                        onTap: onReply,
                        behavior: HitTestBehavior.opaque,
                        child: const Text(
                          'Reply',
                          style: CommentTextStyles.metaAction,
                        ),
                      ),
                      if (comment.replyCount > 0 && onViewReplies != null) ...[
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: onViewReplies,
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            'View more replies (${comment.replyCount})',
                            style: CommentTextStyles.metaAction,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            GestureDetector(
              onTap: onLike,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      comment.isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: _likeIconSize,
                      color: comment.isLiked
                          ? const Color(0xFFF81945)
                          : CommentTextStyles.secondary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${comment.likeCount}',
                      style: CommentTextStyles.likeCount,
                      textAlign: TextAlign.center,
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
}

class _CommentAvatar extends StatelessWidget {
  const _CommentAvatar({
    required this.avatarUrl,
    required this.size,
    required this.fallbackInitial,
  });

  final String avatarUrl;
  final double size;
  final String fallbackInitial;

  bool get _isValidNetworkAvatar {
    final url = avatarUrl.trim();
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isAbsolute || uri.host.isEmpty) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF2A2A3A),
      ),
      alignment: Alignment.center,
      child: Text(
        fallbackInitial,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontWeight: FontWeight.w500,
          fontSize: size * 0.36,
        ),
      ),
    );

    if (!_isValidNetworkAvatar) return fallback;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          avatarUrl.trim(),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 17,
      height: 17,
      decoration: const BoxDecoration(
        color: Color(0xFFF81945),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
    );
  }
}
