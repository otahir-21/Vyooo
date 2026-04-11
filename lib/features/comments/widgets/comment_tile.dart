import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../models/comment.dart';

/// Single comment row: avatar, username, time, text, Reply/View replies, like or delete.
class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    this.isReply = false,
    this.onReply,
    this.onLike,
    this.onViewReplies,
    this.onReport,
    this.onDelete,
    this.isHighlighted = false,
  });

  final Comment comment;
  final bool isReply;
  final VoidCallback? onReply;
  final VoidCallback? onLike;
  final VoidCallback? onViewReplies;
  final VoidCallback? onReport;
  final VoidCallback? onDelete;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final avatarSize = isReply ? 34.0 : 44.0;
    return Container(
      color: isHighlighted
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.transparent,
      padding: EdgeInsets.only(
        left: isReply ? 72 : 16,
        right: 16,
        top: 8,
        bottom: 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: avatarSize / 2,
            backgroundColor: Colors.white12,
            backgroundImage: Uri.tryParse(comment.avatarUrl)?.isAbsolute == true
                ? NetworkImage(comment.avatarUrl)
                : null,
            child: Uri.tryParse(comment.avatarUrl)?.isAbsolute != true
                ? const Icon(Icons.person, color: Colors.white24, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      comment.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14, // Reduced
                      ),
                    ),
                    if (comment.isVerified) ...[
                      const SizedBox(width: 4),
                      const _VerifiedBadge(),
                    ],
                    const SizedBox(width: 8),
                    Text(
                      comment.timeAgo,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12, // Reduced
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15, // Reduced
                    height: 1.3,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onReply,
                      child: Text(
                        'Reply',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (comment.replyCount > 0 && onViewReplies != null) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: onViewReplies,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View more replies (${comment.replyCount})',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          if (comment.isOwnComment && onDelete != null)
            Material(
              color: Colors.transparent,
              child: IconButton(
                onPressed: onDelete,
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444),
                ),
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onLike,
                  behavior: HitTestBehavior.opaque,
                  child: Opacity(
                    opacity: onLike != null ? 1 : 0.35,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          comment.isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 20, // Adjusted size
                          color: comment.isLiked
                              ? const Color(0xFFEF4444)
                              : Colors.white.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${comment.likeCount}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (onReport != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    onPressed: onReport,
                    icon: Icon(
                      Icons.flag_outlined,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: const BoxDecoration(
        color: Color(0xFFEF4444), // Design accurate Red
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, size: 9, color: Colors.white),
    );
  }
}
