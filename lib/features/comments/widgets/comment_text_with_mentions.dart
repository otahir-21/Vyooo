import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/user_service.dart';
import '../../../core/utils/mention_utils.dart';
import '../../../screens/profile/user_profile_screen.dart';
import '../comment_text_styles.dart';

/// Renders comment [text] with tappable `@username` segments.
class CommentTextWithMentions extends StatefulWidget {
  const CommentTextWithMentions({
    super.key,
    required this.text,
    this.style = CommentTextStyles.body,
    this.mentionColor = AppColors.brandPink,
  });

  final String text;
  final TextStyle style;
  final Color mentionColor;

  @override
  State<CommentTextWithMentions> createState() =>
      _CommentTextWithMentionsState();
}

class _CommentTextWithMentionsState extends State<CommentTextWithMentions> {
  final List<TapGestureRecognizer> _recognizers = [];
  List<InlineSpan> _spans = const [];
  String _spansSource = '';

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _openMentionProfile(String username) async {
    final user = await UserService().getUserByUsername(username);
    if (!mounted || user == null) return;
    final handle = (user.username ?? username).trim();
    final displayName = (user.displayName ?? '').trim().isNotEmpty
        ? user.displayName!.trim()
        : handle;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfileScreen(
          payload: UserProfilePayload(
            username: handle,
            displayName: displayName,
            avatarUrl: (user.profileImage ?? '').trim(),
            isVerified: user.isVerified,
            accountType: user.accountType,
            vipVerified: user.vipVerified,
            monetizationEnabled: user.monetizationEnabled,
            postCount: 0,
            followerCount: user.followersCount,
            followingCount: user.following.length,
            bio: user.bio ?? '',
            targetUserId: user.uid,
          ),
        ),
      ),
    );
  }

  void _rebuildSpansIfNeeded() {
    if (_spansSource == widget.text &&
        (_spans.isNotEmpty || widget.text.isEmpty)) {
      return;
    }
    _disposeRecognizers();
    _spansSource = widget.text;

    final text = widget.text;
    final spans = <InlineSpan>[];
    var start = 0;

    for (final m in MentionUtils.mentionPattern.allMatches(text)) {
      if (m.start > start) {
        spans.add(
          TextSpan(text: text.substring(start, m.start), style: widget.style),
        );
      }
      final raw = m.group(0)!;
      final handle = m.group(1) ?? '';
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _openMentionProfile(handle);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: raw,
          style: widget.style.copyWith(
            color: widget.mentionColor,
            fontWeight: FontWeight.w600,
          ),
          recognizer: recognizer,
        ),
      );
      start = m.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: widget.style));
    }
    _spans = spans.isEmpty && text.isEmpty
        ? const [TextSpan(text: '')]
        : spans;
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  void didUpdateWidget(CommentTextWithMentions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.mentionColor != widget.mentionColor) {
      _spans = const [];
      _spansSource = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    _rebuildSpansIfNeeded();
    return Text.rich(TextSpan(children: _spans));
  }
}
