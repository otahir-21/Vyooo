import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Right-side vertical action column: Crown, Views, Likes, Comments, Share, More.
class FeedActionButtons extends StatelessWidget {
  const FeedActionButtons({
    super.key,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    this.isLiked = false,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onMore,
  });

  final String viewCount;
  final String likeCount;
  final String commentCount;
  final bool isLiked;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onMore;

  static const double _spacing = 18;
  static const Color _pinkAccent = Color(0xFFFF2E93);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionItem(
          icon: FontAwesomeIcons.crown,
          color: const Color(0xFFFFD700),
        ),
        const SizedBox(height: _spacing),
        _ActionItem(icon: Icons.visibility_outlined, count: viewCount),
        const SizedBox(height: _spacing),
        _ActionItem(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          count: likeCount,
          color: isLiked ? _pinkAccent : null,
          onTap: onLike,
        ),
        const SizedBox(height: _spacing),
        _ActionItem(
          icon: Icons.chat_bubble_outline,
          count: commentCount,
          onTap: onComment,
        ),
        const SizedBox(height: _spacing),
        _ActionItem(icon: Icons.send_outlined, onTap: onShare),
        const SizedBox(height: _spacing),
        _ActionItem(icon: Icons.more_horiz, onTap: onMore),
      ],
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({required this.icon, this.count, this.color, this.onTap});

  final IconData icon;
  final String? count;
  final Color? color;
  final VoidCallback? onTap;

  static const double _iconSize = 26;
  static const double _textSize = 12;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: _iconSize, color: c),
          if (count != null && count!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              count!,
              style: TextStyle(fontSize: _textSize, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}
