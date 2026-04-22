import 'package:flutter/material.dart';

/// Standard interaction button used across the app (reels, stories, posts, etc).
/// Vertical layout: icon above count text. Use [count] empty for icon-only (e.g. Crown, More).
class AppInteractionButton extends StatelessWidget {
  const AppInteractionButton({
    super.key,
    required this.icon,
    required this.count,
    this.isActive = false,
    this.onTap,
    this.activeColor = const Color(0xFFD10057),
    this.defaultColor = Colors.white,
    this.iconColor,
    this.iconSize = 28,
    this.textSize = 12,
    this.spacing = 4,
  });

  final IconData icon;
  final String count;
  final bool isActive;
  final VoidCallback? onTap;
  final Color activeColor;
  final Color defaultColor;
  /// Override icon color (e.g. yellow for Crown). If null, uses active/default.
  final Color? iconColor;
  final double iconSize;
  final double textSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? (isActive ? activeColor : defaultColor);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          if (count.isNotEmpty) ...[
            SizedBox(height: spacing),
            Text(
              count,
              style: TextStyle(
                fontSize: textSize,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
