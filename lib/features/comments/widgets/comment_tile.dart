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

  static const double _avatarSize = 40;
  static const double _avatarSizeReply = 32;

  @override
  Widget build(BuildContext context) {
    final avatarSize = isReply ? _avatarSizeReply : _avatarSize;
    return Container(
      color: isHighlighted ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
      padding: EdgeInsets.only(
        left: isReply ? 72 : 16,
        right: 16,
        top: 10,
        bottom: 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isReply
                  ? null
                  : Border.all(color: Colors.white10, width: 0.5),
            ),
            child: CircleAvatar(
              radius: avatarSize / 2,
              backgroundColor: Colors.grey.shade900,
              backgroundImage: Uri.tryParse(comment.avatarUrl)?.isAbsolute == true
                  ? NetworkImage(comment.avatarUrl)
                  : null,
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Row(
                        children: [
                          Text(
                            comment.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          if (comment.isVerified) ...[
                            const SizedBox(width: 6),
                            const _VerifiedBadge(),
                          ],
                          const SizedBox(width: 12),
                          Text(
                            comment.timeAgo,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  comment.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onReply,
                      child: Text(
                        'Reply',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    if (comment.replyCount > 0 && onViewReplies != null) ...[
                      const SizedBox(width: 24),
                      GestureDetector(
                        onTap: onViewReplies,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View more replies (${comment.replyCount})',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.6),
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
              child: InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 22,
                    color: Color(0xFFEF4444),
                  ),
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
                          comment.isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: comment.isLiked
                              ? const Color(0xFFEF4444)
                              : Colors.white.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${comment.likeCount}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11,
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
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
