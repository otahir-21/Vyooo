import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Right-side vertical action column: Crown, Views, Likes, Comments, Share, More.
class FeedActionButtons extends StatelessWidget {
  const FeedActionButtons({
    super.key,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.favoriteCount,
    this.isLiked = false,
    this.isFavorited = false,
    this.onLike,
    this.onComment,
    this.onFavorite,
    this.onShare,
    this.onMore,
  });

  final String viewCount;
  final String likeCount;
  final String commentCount;
  final String favoriteCount;
  final bool isLiked;
  final bool isFavorited;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onFavorite;
  final VoidCallback? onShare;
  final VoidCallback? onMore;

  static const double _spacing = 22;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionItem(
          icon: 'assets/vyooO_icons/Home/vr.png',
          count: viewCount,
        ),
        const SizedBox(height: _spacing),
        _ActionItem(
          icon: isLiked ? 'assets/vyooO_icons/Home/heart.png' : 'assets/vyooO_icons/Home/heart.png',
          count: likeCount,
          color: isLiked ? const Color(0xFFFF2E93) : Colors.white,
          onTap: onLike,
        ),
        const SizedBox(height: _spacing),
        _ActionItem(
          icon: 'assets/vyooO_icons/Home/comments.png',
          count: commentCount,
          onTap: onComment,
        ),
        const SizedBox(height: _spacing),
        _ActionItem(
          icon: isFavorited ? 'assets/vyooO_icons/Profile/favourites.png' : 'assets/vyooO_icons/Profile/favourites.png',
          count: favoriteCount,
          color: isFavorited ? const Color(0xFFFFD700) : Colors.white,
          onTap: onFavorite,
        ),
        const SizedBox(height: _spacing),
        _ActionItem(
          icon: 'assets/vyooO_icons/Home/share_to.png',
          onTap: onShare,
        ),
        const SizedBox(height: _spacing),
        _ActionItem(
          icon: 'assets/vyooO_icons/Home/three_dots.png',
          onTap: onMore,
        ),
      ],
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({required this.icon, this.count, this.color, this.onTap});

  final dynamic icon; // Can be IconData or String path
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
          if (icon is IconData)
            Icon(icon as IconData, size: _iconSize, color: c)
          else if (icon is String)
            SizedBox(
              width: _iconSize,
              height: _iconSize,
              child: Image.asset(
                icon as String,
                color: c,
                fit: BoxFit.contain,
              ),
            ),
          if (count != null && count!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              count!,
              style: const TextStyle(
                fontSize: _textSize,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
