import 'package:flutter/material.dart';

import 'app_feed_header_icon_button.dart';

/// Feed header notification bell with optional unread badge.
class AppFeedNotificationButton extends StatelessWidget {
  const AppFeedNotificationButton({
    super.key,
    required this.onTap,
    this.badge,
  });

  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return AppFeedHeaderIconButton.notifications(
      onTap: onTap,
      badge: badge,
    );
  }
}
