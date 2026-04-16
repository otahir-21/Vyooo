import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/comment_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/user_facing_errors.dart';
import '../models/comment.dart';
import 'comment_tile.dart';
import 'report_comment_sheet.dart';

// ── Public entry-point ────────────────────────────────────────────────────────

/// Opens Firestore-backed comments for [reelId].
/// [onCommentCountChanged] is called with +1 per new comment (incl. reply) and -N when N comments removed.
void showCommentsBottomSheet(
  BuildContext context, {
  required String reelId,
  void Function(int commentCountDelta)? onCommentCountChanged,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) => _CommentsBottomSheetBody(
      reelId: reelId,
      onCommentCountChanged: onCommentCountChanged,
    ),
  );
}

// ── Row model ────────────────────────────────────────────────────────────────

sealed class _CommentListRow {}

class _RowComment extends _CommentListRow {
  _RowComment({required this.comment, required this.isReply});
  final Comment comment;
  final bool isReply;
}

class _RowViewMore extends _CommentListRow {
  _RowViewMore({required this.rootCommentId, required this.hiddenCount});
  final String rootCommentId;
  final int hiddenCount;
}

List<_CommentListRow> _buildCommentRows(
  List<Comment> roots,
  Set<String> expandedThreadIds,
) {
  final list = <_CommentListRow>[];
  for (final c in roots) {
    list.add(_RowComment(comment: c, isReply: false));
    final rep = c.replies;
    if (rep.isEmpty) continue;
    if (expandedThreadIds.contains(c.id) || rep.length <= 1) {
      for (final r in rep) {
        list.add(_RowComment(comment: r, isReply: true));
      }
    } else {
      list.add(_RowComment(comment: rep.first, isReply: true));
      list.add(_RowViewMore(rootCommentId: c.id, hiddenCount: rep.length - 1));
    }
  }
  return list;
}

// ── Sheet body ───────────────────────────────────────────────────────────────

class _CommentsBottomSheetBody extends StatefulWidget {
  const _CommentsBottomSheetBody({
    required this.reelId,
    this.onCommentCountChanged,
  });

  final String reelId;
  final void Function(int commentCountDelta)? onCommentCountChanged;

  @override
  State<_CommentsBottomSheetBody> createState() =>
      _CommentsBottomSheetBodyState();
}

class _CommentsBottomSheetBodyState extends State<_CommentsBottomSheetBody> {
  final _commentService = CommentService();
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tailSub;

  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> _olderById =
      {};

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _prevTailDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _tailDocs = [];

  bool _hasMoreOlder = true;
  bool _loadingOlder = false;
  bool _streamError = false;
  bool _parsing = false;
  bool _initializing = true;

  List<Comment> _comments = [];

  String? _replyParentId;
  String _replyUsername = '';
  bool _posting = false;

  final Set<String> _expandedReplyThreads = {};

  void _expandReplyThread(String rootCommentId) =>
      setState(() => _expandedReplyThreads.add(rootCommentId));

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(() => setState(() {}));
    _subscribeTail();
  }

  @override
  void dispose() {
    _tailSub?.cancel();
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Stream / data ──────────────────────────────────────────────────────────

  void _subscribeTail() {
    _tailSub?.cancel();
    _tailSub = _commentService
        .watchRecentCommentsTail(widget.reelId)
        .listen(
          _onTailSnapshot,
          onError: (Object error, StackTrace stackTrace) {
            if (mounted) setState(() => _streamError = true);
          },
        );
  }

  void _onTailSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    if (!mounted) return;
    final newTail = snap.docs;
    final newIds = newTail.map((e) => e.id).toSet();
    for (final d in _prevTailDocs) {
      if (!newIds.contains(d.id)) _olderById[d.id] = d;
    }
    _prevTailDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
      newTail,
    );
    _tailDocs = newTail;
    setState(() {
      _streamError = false;
      _initializing = false;
    });
    _rebuildMergedComments();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortedMergedDocs() {
    final m = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final e in _olderById.entries) {
      m[e.key] = e.value;
    }
    for (final d in _tailDocs) {
      m[d.id] = d;
    }
    final list = m.values.toList();
    int ts(QueryDocumentSnapshot<Map<String, dynamic>> d) {
      final t = d.data()['createdAt'];
      if (t is Timestamp) return t.millisecondsSinceEpoch;
      return 0;
    }

    list.sort((a, b) => ts(a).compareTo(ts(b)));
    return list;
  }

  Future<void> _rebuildMergedComments() async {
    if (!mounted) return;
    setState(() => _parsing = true);
    try {
      final merged = _sortedMergedDocs();
      final tree = await _commentService.commentsFromDocuments(
        widget.reelId,
        merged,
      );
      if (!mounted) return;
      setState(() {
        _comments = tree;
        _parsing = false;
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _parsing = false;
          _streamError = true;
        });
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMoreOlder) return;
    final sorted = _sortedMergedDocs();
    if (sorted.isEmpty) {
      setState(() => _hasMoreOlder = false);
      return;
    }
    final oldest = sorted.first;
    setState(() => _loadingOlder = true);
    try {
      final snap = await _commentService.fetchCommentsOlderThan(
        widget.reelId,
        oldest,
      );
      if (!mounted) return;
      if (snap.docs.isEmpty) {
        setState(() {
          _hasMoreOlder = false;
          _loadingOlder = false;
        });
        return;
      }
      for (final d in snap.docs) {
        _olderById[d.id] = d;
      }
      if (snap.docs.length < CommentService.olderPageSize)
        _hasMoreOlder = false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(messageForFirestore(e)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingOlder = false);
        await _rebuildMergedComments();
      }
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _post() async {
    final text = _textCtrl.text;
    final maxLen = CommentService.maxCommentLength;
    if (_posting ||
        text.trim().isEmpty ||
        text.length > maxLen ||
        AuthService().currentUser == null)
      return;

    setState(() => _posting = true);
    try {
      await _commentService.addComment(
        widget.reelId,
        text,
        parentId: _replyParentId ?? '',
      );
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      _textCtrl.clear();
      setState(() {
        _replyParentId = null;
        _replyUsername = '';
      });
      widget.onCommentCountChanged?.call(1);
    } catch (e) {
      if (mounted) _showErrorSnack(messageForFirestore(e));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  void _startReply(Comment c) {
    setState(() {
      _replyParentId = c.id;
      _replyUsername = c.username;
    });
    _focusNode.requestFocus();
  }

  Future<void> _onDelete(String commentId) async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.sheetBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete comment?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        content: const Text(
          'This cannot be undone.',
          style: TextStyle(color: Color(0x99FFFFFF), fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0x99FFFFFF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Color(0xFFF81945),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final removed = await _commentService.deleteComment(
        widget.reelId,
        commentId,
      );
      if (!mounted) return;
      if (removed <= 0) {
        _showErrorSnack(
          'Could not delete this comment. Check your connection or permissions.',
        );
        return;
      }
      widget.onCommentCountChanged?.call(-removed);
    } catch (e) {
      if (mounted) _showErrorSnack(messageForFirestore(e));
    }
  }

  Future<void> _onLike(Comment c) async {
    if (AuthService().currentUser == null) return;
    try {
      await _commentService.toggleCommentLike(widget.reelId, c.id, c.isLiked);
    } catch (e) {
      if (mounted) _showErrorSnack(messageForFirestore(e));
    }
  }

  Future<void> _onReport(Comment c) async {
    if (AuthService().currentUser == null) return;
    await showReportCommentSheet(context, reelId: widget.reelId, comment: c);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final maxLen = CommentService.maxCommentLength;
    final textLen = _textCtrl.text.length;
    final overLimit = textLen > maxLen;
    final canSend =
        textLen > 0 &&
        !overLimit &&
        !_posting &&
        AuthService().currentUser != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Padding(
              padding: EdgeInsets.only(bottom: keyboardBottom),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(36),
                  ),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xF71A1A2E), // ~0.97 opacity
                      Color(0xFC16011A), // ~0.98 opacity
                    ],
                  ),
                  border: Border.all(
                    color: Color(0x14FFFFFF), // rgba(255,255,255,0.08)
                  ),
                ),
                child: Column(
                  children: [
                    // ── Drag handle ──────────────────────────────────────
                    const Padding(
                      padding: EdgeInsets.only(top: 14, bottom: 8),
                      child: _DragHandle(),
                    ),

                    // ── Title ────────────────────────────────────────────
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Comments',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),

                    // ── Comment list ─────────────────────────────────────
                    Expanded(
                      child: StreamBuilder<User?>(
                        stream: FirebaseAuth.instance.authStateChanges(),
                        builder: (context, authSnap) {
                          final signedIn = authSnap.data != null;
                          return _buildCommentList(scrollController, signedIn);
                        },
                      ),
                    ),

                    // ── Reply banner ─────────────────────────────────────
                    if (_replyParentId != null)
                      _ReplyBanner(
                        username: _replyUsername,
                        onCancel: () => setState(() {
                          _replyParentId = null;
                          _replyUsername = '';
                        }),
                      ),

                    // ── Input ────────────────────────────────────────────
                    StreamBuilder<User?>(
                      stream: FirebaseAuth.instance.authStateChanges(),
                      builder: (context, authSnap) {
                        final signedIn = authSnap.data != null;
                        if (!signedIn) {
                          return Padding(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              16 + safeBottom,
                            ),
                            child: const Text(
                              'Sign in to comment.',
                              style: TextStyle(
                                color: Color(0x80FFFFFF),
                                fontSize: 14,
                              ),
                            ),
                          );
                        }
                        return _InputBar(
                          controller: _textCtrl,
                          focusNode: _focusNode,
                          isReply: _replyParentId != null,
                          maxLen: maxLen,
                          textLen: textLen,
                          overLimit: overLimit,
                          canSend: canSend,
                          posting: _posting,
                          safeBottom: safeBottom,
                          onPost: _post,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentList(ScrollController scrollController, bool signedIn) {
    // Error state
    if (_streamError && !_initializing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not load comments',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _streamError = false;
                    _initializing = true;
                  });
                  _subscribeTail();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF81945),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Loading state
    if (_initializing || (_parsing && _comments.isEmpty)) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0x80FFFFFF),
          ),
        ),
      );
    }

    // Empty state
    if (_comments.isEmpty && !_parsing) {
      return ListView(
        controller: scrollController,
        children: [
          const SizedBox(height: 56),
          Text(
            'No comments yet.\nBe the first to say something.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      );
    }

    final headerRows = (_hasMoreOlder || _loadingOlder) ? 1 : 0;
    final rows = _buildCommentRows(_comments, _expandedReplyThreads);

    return Stack(
      children: [
        ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          itemCount: headerRows + rows.length,
          itemBuilder: (context, index) {
            // "Load earlier" header
            if (headerRows > 0 && index == 0) {
              if (_loadingOlder) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0x60FFFFFF),
                      ),
                    ),
                  ),
                );
              }
              return TextButton(
                onPressed: _loadOlder,
                child: Text(
                  'Load earlier comments',
                  style: TextStyle(
                    color: AppColors.pink,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              );
            }

            final ci = index - headerRows;
            final row = rows[ci];

            switch (row) {
              case _RowViewMore(:final rootCommentId, :final hiddenCount):
                return _ViewMoreRepliesRow(
                  hiddenCount: hiddenCount,
                  onTap: () => _expandReplyThread(rootCommentId),
                );
              case _RowComment(:final comment, :final isReply):
                return CommentTile(
                  comment: comment,
                  isReply: isReply,
                  isHighlighted: comment.isOwnComment,
                  onReply: signedIn ? () => _startReply(comment) : null,
                  onLike: signedIn && !comment.isOwnComment
                      ? () => _onLike(comment)
                      : null,
                  onReport: signedIn && !comment.isOwnComment
                      ? () => _onReport(comment)
                      : null,
                  onDelete: comment.isOwnComment
                      ? () => _onDelete(comment.id)
                      : null,
                );
            }
          },
        ),

        // Subtle parsing indicator (top-right spinner)
        if (_parsing && _comments.isNotEmpty)
          const Positioned(
            top: 10,
            right: 14,
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: Color(0x60FFFFFF),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

/// "Replying to @username" banner with Cancel
class _ReplyBanner extends StatelessWidget {
  const _ReplyBanner({required this.username, required this.onCancel});

  final String username;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Replying to $username',
              style: const TextStyle(
                color: Color(0xA6FFFFFF), // ~65%
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0x80FFFFFF),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Text field + send button
class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isReply,
    required this.maxLen,
    required this.textLen,
    required this.overLimit,
    required this.canSend,
    required this.posting,
    required this.safeBottom,
    required this.onPost,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isReply;
  final int maxLen;
  final int textLen;
  final bool overLimit;
  final bool canSend;
  final bool posting;
  final double safeBottom;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 4, 12, 12 + safeBottom),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Text field
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 4,
              // maxLength: maxLen,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: isReply ? 'Write a reply…' : 'Add a comment…',
                hintStyle: const TextStyle(
                  color: Color(0x59FFFFFF), // 35%
                  fontSize: 15,
                ),
                filled: true,
                fillColor: const Color(0x14FFFFFF), // 8%
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: Color(0x33FFFFFF),
                    width: 1,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                // counterText: '$textLen / $maxLen',
                counterStyle: TextStyle(
                  color: overLimit
                      ? const Color(0xFFF81945)
                      : const Color(0x73FFFFFF), // 45%
                  fontSize: 11,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),

          // Send / loading
          if (posting)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0x80FFFFFF),
                ),
              ),
            )
          else
            _SendButton(onPressed: canSend ? onPost : null),
        ],
      ),
    );
  }
}

/// Pink filled send button
class _SendButton extends StatelessWidget {
  const _SendButton({this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onPressed != null
              ? const Color(0xFFDE106B)
              : const Color(0x1FFFFFFF), // disabled
        ),
        child: const Icon(Icons.send_rounded, size: 20, color: Colors.white),
      ),
    );
  }
}

/// Indented "View more replies (n) ↓" row
class _ViewMoreRepliesRow extends StatelessWidget {
  const _ViewMoreRepliesRow({required this.hiddenCount, required this.onTap});

  final int hiddenCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(
          left: 116,
          right: 20,
          top: 4,
          bottom: 12,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'View more replies ($hiddenCount)',
              style: const TextStyle(
                color: Color(0x80FFFFFF),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: Color(0x80FFFFFF),
            ),
          ],
        ),
      ),
    );
  }
}

/// Drag handle pill
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 48,
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0x33FFFFFF), // 20%
          borderRadius: BorderRadius.circular(2.5),
        ),
      ),
    );
  }
}
