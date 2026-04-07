import 'package:flutter/material.dart';

import '../../../core/services/comment_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/user_facing_errors.dart';
import '../models/comment.dart';

/// Bottom sheet: pick a reason and write to `comment_reports`.
Future<void> showReportCommentSheet(
  BuildContext context, {
  required String reelId,
  required Comment comment,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ReportCommentBody(
      reelId: reelId,
      comment: comment,
    ),
  );
}

class _ReportCommentBody extends StatefulWidget {
  const _ReportCommentBody({
    required this.reelId,
    required this.comment,
  });

  final String reelId;
  final Comment comment;

  @override
  State<_ReportCommentBody> createState() => _ReportCommentBodyState();
}

class _ReportCommentBodyState extends State<_ReportCommentBody> {
  static const _reasons = [
    "Spam or misleading",
    "Harassment or hate",
    "Nudity or sexual content",
    "Violence or dangerous acts",
    "Something else",
  ];

  bool _submitting = false;

  Future<void> _submit(String reason) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await CommentService().reportComment(
        reelId: widget.reelId,
        commentId: widget.comment.id,
        commentAuthorId: widget.comment.authorUserId,
        reason: reason,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks — we\'ll review this comment.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(messageForFirestore(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF49113B),
            Color(0xFF210D1D),
            Color(0xFF0F040C),
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Report @${widget.comment.username}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                widget.comment.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_submitting)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                child: Column(
                  children: [
                    for (var i = 0; i < _reasons.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ListTile(
                        title: Text(
                          _reasons[i],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        onTap: () => _submit(_reasons[i]),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
