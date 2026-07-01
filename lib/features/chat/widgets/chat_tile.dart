import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_padding.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/chat_summary_model.dart';
import '../utils/chat_helpers.dart';

class ChatTile extends StatelessWidget {
  const ChatTile({
    super.key,
    required this.summary,
    required this.onTap,
  });

  final ChatSummaryModel summary;
  final VoidCallback onTap;

  String get _previewBody {
    if (summary.unreadCount > 1) {
      return '${summary.unreadCount}+ new messages';
    }
    if (summary.lastMessage.isNotEmpty) {
      return summary.lastMessage;
    }
    return 'Tap to start chatting';
  }

  String get _timeLabel => ChatHelpers.formatInboxTime(summary.lastMessageAt);

  @override
  Widget build(BuildContext context) {
    final hasAvatar = summary.avatarUrl.trim().isNotEmpty;
    final hasUnread = summary.unreadCount > 0;
    final time = _timeLabel;
    final avatarSize =
        AppSizes.chatInboxScaleW(context, AppSizes.chatInboxAvatar);

    return InkWell(
      onTap: onTap,
      splashColor: AppColors.brandDeepMagenta.withValues(alpha: 0.08),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppPadding.screenHorizontal.left,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: avatarSize / 2,
              backgroundColor: AppColors.chatSearchFill,
              backgroundImage: hasAvatar
                  ? CachedNetworkImageProvider(summary.avatarUrl)
                  : null,
              child: hasAvatar
                  ? null
                  : Icon(
                      summary.type == 'group' ? Icons.group : Icons.person,
                      color: AppColors.chatTextSecondary,
                      size: AppSizes.chatInboxScaleW(
                        context,
                        AppSizes.chatInboxAvatarIcon,
                      ),
                    ),
            ),
            SizedBox(width: AppSpacing.md - AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.chatTileName.copyWith(
                      fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs - 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          TextSpan(
                            children: [
                              TextSpan(
                                text: _previewBody,
                                style: AppTypography.chatTilePreview.copyWith(
                                  fontWeight: hasUnread
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: hasUnread
                                      ? AppColors.chatTextPrimary
                                      : AppColors.chatTextSecondary,
                                ),
                              ),
                              if (time.isNotEmpty) ...[
                                TextSpan(
                                  text: ' · $time',
                                  style: AppTypography.chatTilePreview.copyWith(
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.chatTextSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        SizedBox(width: AppSpacing.sm),
                        Container(
                          width: AppSpacing.sm,
                          height: AppSpacing.sm,
                          decoration: const BoxDecoration(
                            color: AppColors.brandDeepMagenta,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ] else ...[
                        SizedBox(width: AppSpacing.sm),
                        const Icon(
                          Icons.camera_alt_outlined,
                          color: AppColors.chatTextSecondary,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
