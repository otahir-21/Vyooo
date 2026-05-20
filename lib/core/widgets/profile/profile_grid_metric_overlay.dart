import 'package:flutter/material.dart';

import '../../models/reel_count_privacy.dart';
import '../../theme/app_spacing.dart';

/// Views, likes, and share counts on a profile grid thumbnail.
class ProfileGridMetricOverlay extends StatelessWidget {
  const ProfileGridMetricOverlay({
    super.key,
    required this.views,
    required this.likes,
    required this.shares,
    required this.privacy,
    this.isHero = false,
  });

  final int views;
  final int likes;
  final int shares;
  final ReelCountPrivacy privacy;
  final bool isHero;

  @override
  Widget build(BuildContext context) {
    final iconSize = isHero ? 14.0 : 12.0;
    final fontSize = isHero ? 12.0 : 11.0;
    final chips = <Widget>[];

    void addMetric({
      required IconData icon,
      required ReelCountMetric metric,
      required int value,
    }) {
      if (!privacy.showMetric(metric)) return;
      if (value <= 0 && metric != ReelCountMetric.views) return;
      if (chips.isNotEmpty) chips.add(const SizedBox(width: 8));
      chips.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 2),
            Text(
              ReelCountPrivacy.formatCount(value),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: fontSize,
                fontWeight: isHero ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    addMetric(
      icon: Icons.visibility_outlined,
      metric: ReelCountMetric.views,
      value: views,
    );
    addMetric(
      icon: Icons.favorite_border_rounded,
      metric: ReelCountMetric.likes,
      value: likes,
    );
    addMetric(
      icon: Icons.reply_rounded,
      metric: ReelCountMetric.shares,
      value: shares,
    );

    if (chips.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: AppSpacing.sm,
      right: AppSpacing.sm,
      child: Row(mainAxisSize: MainAxisSize.min, children: chips),
    );
  }
}
