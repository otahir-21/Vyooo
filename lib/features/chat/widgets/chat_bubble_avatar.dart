import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_sizes.dart';

/// Incoming message row avatar — Figma mask 31 circle (image 30.998×37.171).
class ChatBubbleAvatar extends StatelessWidget {
  const ChatBubbleAvatar({
    super.key,
    required this.imageUrl,
    this.placeholderIcon = Icons.person,
  });

  final String? imageUrl;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final maskSize = AppSizes.chatThreadBubbleAvatar;
    final hasAvatar = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return ClipOval(
      child: SizedBox(
        width: maskSize,
        height: maskSize,
        child: hasAvatar
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: AppColors.chatSearchFill,
      child: Center(
        child: Icon(
          placeholderIcon,
          color: AppColors.chatTextSecondary,
          size: 14,
        ),
      ),
    );
  }
}
