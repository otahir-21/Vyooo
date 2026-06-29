import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'message_reply_quote.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.text,
    required this.isSent,
    required this.time,
    this.isDeleted = false,
    this.senderName,
    this.seenText,
    this.replyToSenderName,
    this.replyToPreview,
    this.senderAvatarUrl,
  });

  final String text;
  final bool isSent;
  final String time;
  final bool isDeleted;
  final String? senderName;
  final String? seenText;
  final String? replyToSenderName;
  final String? replyToPreview;
  final String? senderAvatarUrl;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md - AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isSent
            ? AppColors.chatOutgoingBubble
            : AppColors.chatIncomingBubble,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isSent ? 18 : 4),
          bottomRight: Radius.circular(isSent ? 4 : 18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (senderName != null && !isSent)
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.xs - 2),
              child: Text(
                senderName!,
                style: AppTypography.chatTilePreview.copyWith(
                  color: AppColors.brandDeepMagenta,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          if (replyToSenderName != null && replyToPreview != null)
            MessageReplyQuote(
              senderName: replyToSenderName!,
              preview: replyToPreview!,
              isSentBubble: isSent,
            ),
          Text(
            isDeleted ? 'This message was deleted' : text,
            style: AppTypography.chatBubbleText.copyWith(
              color: isDeleted
                  ? (isSent
                      ? Colors.white.withValues(alpha: 0.6)
                      : AppColors.chatTextSecondary)
                  : (isSent ? Colors.white : AppColors.chatTextPrimary),
              fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          SizedBox(height: AppSpacing.xs - 2),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (seenText != null) ...[
                  Text(
                    seenText!,
                    style: AppTypography.chatDateSeparator.copyWith(
                      fontSize: 10,
                      color: isSent
                          ? Colors.white.withValues(alpha: 0.65)
                          : AppColors.chatTextSecondary,
                    ),
                  ),
                  SizedBox(width: AppSpacing.xs),
                ],
                Text(
                  time,
                  style: AppTypography.chatDateSeparator.copyWith(
                    fontSize: 10,
                    color: isSent
                        ? Colors.white.withValues(alpha: 0.65)
                        : AppColors.chatTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isSent) {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.only(
            left: 60,
            right: AppSpacing.sm + AppSpacing.xs,
            top: AppSpacing.xs - 2,
            bottom: AppSpacing.xs - 2,
          ),
          child: bubble,
        ),
      );
    }

    final hasAvatar =
        senderAvatarUrl != null && senderAvatarUrl!.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.sm + AppSpacing.xs,
        right: 60,
        top: AppSpacing.xs - 2,
        bottom: AppSpacing.xs - 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (hasAvatar)
            CircleAvatar(
              radius: AppSizes.chatThreadBubbleAvatar / 2,
              backgroundColor: AppColors.chatSearchFill,
              backgroundImage:
                  CachedNetworkImageProvider(senderAvatarUrl!),
            )
          else
            SizedBox(width: AppSizes.chatThreadBubbleAvatar),
          SizedBox(width: AppSpacing.sm - AppSpacing.xs),
          Flexible(child: bubble),
        ],
      ),
    );
  }
}
