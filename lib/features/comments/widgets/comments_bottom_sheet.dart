import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../data/mock_comments_data.dart';
import '../models/comment.dart';
import 'comment_tile.dart';

/// Dark purplish-maroon comments sheet with drag handle and scrollable list.
/// [onReply], [onLike], [onViewReplies] are called with the comment id when the user taps.
void showCommentsBottomSheet(
  BuildContext context, {
  String? reelId,
  void Function(String commentId)? onReply,
  void Function(String commentId)? onLike,
  void Function(String commentId)? onViewReplies,
}) {
  final comments = getMockCommentsForReel(reelId ?? '');
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _CommentsSheet(
      comments: comments,
      onReply: onReply,
      onLike: onLike,
      onViewReplies: onViewReplies,
    ),
  );
}

/// Sheet content: drag handle, title, list. Uses [DraggableScrollableSheet] so list scroll + drag work.
class _CommentItem {
  _CommentItem({required this.comment, this.isReply = false});
  final Comment comment;
  final bool isReply;
}

int _flatCommentCount(List<Comment> comments) {
  var n = 0;
  for (final c in comments) {
    n += 1 + c.replies.length;
  }
  return n;
}

_CommentItem _flatCommentAt(List<Comment> comments, int index) {
  var i = 0;
  for (final c in comments) {
    if (i == index) return _CommentItem(comment: c, isReply: false);
    i++;
    for (final r in c.replies) {
      if (i == index) return _CommentItem(comment: r, isReply: true);
      i++;
    }
  }
  throw RangeError.index(index, comments, 'index');
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({
    required this.comments,
    this.onReply,
    this.onLike,
    this.onViewReplies,
  });

  final List<Comment> comments;
  final void Function(String commentId)? onReply;
  final void Function(String commentId)? onLike;
  final void Function(String commentId)? onViewReplies;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  late List<Comment> _comments;

  @override
  void initState() {
    super.initState();
    _comments = List<Comment>.from(widget.comments);
  }

  void _onDeleteComment(String commentId) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.sheetBackground,
        title: const Text('Delete comment?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _comments.removeWhere((c) => c.id == commentId);
              });
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.deleteRed)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF49113B), // Deep Magenta
                Color(0xFF210D1D), // Darker muted purple
                Color(0xFF0F040C), // Near black
              ],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DragHandle(),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Comments',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.only(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    bottom: AppSpacing.xl,
                  ),
                  itemCount: _flatCommentCount(_comments),
                  itemBuilder: (context, index) {
                    final item = _flatCommentAt(_comments, index);
                    return CommentTile(
                      comment: item.comment,
                      isReply: item.isReply,
                      onReply: widget.onReply != null ? () => widget.onReply!(item.comment.id) : null,
                      onLike: widget.onLike != null ? () => widget.onLike!(item.comment.id) : null,
                      onViewReplies: item.comment.replyCount > 0 && widget.onViewReplies != null
                          ? () => widget.onViewReplies!(item.comment.id)
                          : null,
                      onDelete: item.comment.isOwnComment
                          ? () => _onDeleteComment(item.comment.id)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
