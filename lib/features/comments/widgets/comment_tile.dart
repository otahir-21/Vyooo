import 'package:flutter/material.dart';

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

  static const double _avatarSize = 56;
  static const double _avatarSizeReply = 36;

  @override
  Widget build(BuildContext context) {
    final avatarSize = isReply ? _avatarSizeReply : _avatarSize;

    return Container(
      color: isHighlighted
          ? Colors.white.withValues(alpha: 0.025)
          : Colors.transparent,
      padding: EdgeInsets.only(
        left: isReply ? 64 : 16,
        right: 16,
        top: 12,
        bottom: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar ──────────────────────────────────────
          CircleAvatar(
            radius: avatarSize / 2,
            backgroundColor: const Color(0xFF2A2A3A),
            backgroundImage: Uri.tryParse(comment.avatarUrl)?.isAbsolute == true
                ? NetworkImage(comment.avatarUrl)
                : null,
          ),
          const SizedBox(width: 16),

          // ── Body ────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username + verified + time
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      comment.username,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: isReply ? 14 : 16,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (comment.isVerified) ...[
                      const SizedBox(width: 8),
                      const _VerifiedBadge(),
                    ],
                    const SizedBox(width: 12),
                    Text(
                      comment.timeAgo,
                      style: const TextStyle(
                        color: Color(0x4DFFFFFF), // 30% white
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Comment text
                Text(
                  comment.text,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isReply ? 16 : 17,
                    height: 1.3,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 10),

                // Reply + View more replies
                Row(
                  children: [
                    GestureDetector(
                      onTap: onReply,
                      behavior: HitTestBehavior.opaque,
                      child: const Text(
                        'Reply',
                        style: TextStyle(
                          color: Color(0x80FFFFFF), // 50% white
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (comment.replyCount > 0 && onViewReplies != null) ...[
                      const SizedBox(width: 24),
                      GestureDetector(
                        onTap: onViewReplies,
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View more replies (${comment.replyCount})',
                              style: const TextStyle(
                                color: Color(0x80FFFFFF),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: Color(0x80FFFFFF),
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
          const SizedBox(width: 12),

          // ── Right: like / delete ────────────────────────
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (comment.isOwnComment && onDelete != null)
                GestureDetector(
                  onTap: onDelete,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: Color(0xFFF81945),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: onLike,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        comment.isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 20,
                        color: comment.isLiked
                            ? const Color(0xFFF81945)
                            : const Color(0x80FFFFFF),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${comment.likeCount}',
                        style: const TextStyle(
                          color: Color(0x80FFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Verified badge ───────────────────────────────────────────────────────────

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: const BoxDecoration(
        color: Color(0xFFF81945),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.check_rounded, size: 9, color: Colors.white),
    );
  }
}
