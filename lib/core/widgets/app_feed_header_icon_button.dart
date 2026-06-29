import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../constants/feed_header_assets.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// Frosted circular icon button for the home feed header (search, notifications).
class AppFeedHeaderIconButton extends StatelessWidget {
  const AppFeedHeaderIconButton({
    super.key,
    required this.onTap,
    this.iconAsset,
    this.fallbackIcon = Icons.circle_outlined,
    this.iconColor = Colors.white,
    this.semanticsLabel,
    this.badge,
  });

  final VoidCallback onTap;
  final String? iconAsset;
  final IconData fallbackIcon;
  final Color iconColor;
  final String? semanticsLabel;
  final Widget? badge;

  factory AppFeedHeaderIconButton.search({
    Key? key,
    required VoidCallback onTap,
  }) {
    return AppFeedHeaderIconButton(
      key: key,
      onTap: onTap,
      iconAsset: FeedHeaderAssets.search,
      fallbackIcon: Icons.search_rounded,
      semanticsLabel: 'Search',
    );
  }

  factory AppFeedHeaderIconButton.notifications({
    Key? key,
    required VoidCallback onTap,
    Widget? badge,
  }) {
    return AppFeedHeaderIconButton(
      key: key,
      onTap: onTap,
      iconAsset: FeedHeaderAssets.notifications,
      fallbackIcon: Icons.notifications_none_rounded,
      semanticsLabel: 'Notifications',
      badge: badge,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: AppSizes.feedNotificationTapTarget,
          height: AppSizes.feedNotificationTapTarget,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    width: AppSizes.feedNotificationCircle,
                    height: AppSizes.feedNotificationCircle,
                    color: White30.value,
                  ),
                ),
              ),
              _buildIcon(),
              if (badge != null)
                Positioned(
                  right: 0,
                  top: 0,
                  child: badge!,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    final asset = iconAsset;
    if (asset != null && asset.isNotEmpty) {
      return Image.asset(
        asset,
        width: AppSizes.feedNotificationIcon,
        height: AppSizes.feedNotificationIcon,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
        color: iconColor,
        errorBuilder: (_, _, _) => _buildVectorIcon(),
      );
    }
    return _buildVectorIcon();
  }

  Widget _buildVectorIcon() {
    return Icon(
      fallbackIcon,
      color: iconColor,
      size: AppSizes.feedNotificationIcon,
      weight: 500,
    );
  }
}
