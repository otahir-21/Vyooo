import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'chat_bubble_avatar.dart';
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
        minHeight: isSent
            ? AppSizes.chatOutgoingBubbleMinHeight
            : AppSizes.chatIncomingBubbleMinHeight,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + AppSpacing.xs - 2,
      ),
      decoration: BoxDecoration(
        color: isSent
            ? AppColors.chatOutgoingBubble
            : AppColors.chatIncomingBubble,
        borderRadius: isSent
            ? AppRadius.chatOutgoingBubbleRadius
            : AppRadius.pillRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
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
            style: isSent
                ? AppTypography.chatSentBubbleText.copyWith(
                    fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                    color: isDeleted
                        ? AppColors.chatSentBubbleText.withValues(alpha: 0.6)
                        : AppColors.chatSentBubbleText,
                  )
                : AppTypography.chatIncomingBubbleText.copyWith(
                    color: isDeleted
                        ? AppColors.chatTextSecondary
                        : AppColors.chatIncomingBubbleText,
                    fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
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
    final avatarSlot = AppSizes.chatThreadBubbleAvatar;

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
            ChatBubbleAvatar(imageUrl: senderAvatarUrl)
          else
            SizedBox(width: avatarSlot),
          SizedBox(width: AppSpacing.sm - AppSpacing.xs),
          Flexible(child: bubble),
        ],
      ),
    );
  }
}
