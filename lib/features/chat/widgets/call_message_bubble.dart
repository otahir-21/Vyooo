import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/call_session_model.dart';
import '../models/message_model.dart';

class CallMessageBubble extends StatelessWidget {
  const CallMessageBubble({
    super.key,
    required this.message,
    required this.isSent,
  });

  final MessageModel message;
  final bool isSent;

  @override
  Widget build(BuildContext context) {
    final meta = message.metadata;
    final callType = meta['callType'] as String? ?? CallType.audio;
    final callStatus = meta['callStatus'] as String? ?? '';
    final durationSeconds = meta['durationSeconds'] as int?;

    IconData icon;
    String title;
    String? subtitle;

    switch (callStatus) {
      case CallStatus.ended:
        icon = callType == CallType.video ? Icons.videocam : Icons.call;
        title = callType == CallType.video ? 'Video call' : 'Audio call';
        if (durationSeconds != null && durationSeconds > 0) {
          final m = (durationSeconds ~/ 60).toString().padLeft(2, '0');
          final s = (durationSeconds % 60).toString().padLeft(2, '0');
          subtitle = '$m:$s';
        }
      case CallStatus.missed:
        icon = Icons.call_missed;
        title = 'Missed ${callType == CallType.video ? 'video' : 'audio'} call';
      case CallStatus.declined:
        icon = Icons.call_end;
        title = 'Declined ${callType == CallType.video ? 'video' : 'audio'} call';
      case CallStatus.failed:
        icon = Icons.error_outline;
        title = 'Call failed';
      default:
        icon = callType == CallType.video ? Icons.videocam : Icons.call;
        title = callType == CallType.video ? 'Video call' : 'Audio call';
    }

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(
          vertical: AppSpacing.xs - 2,
          horizontal: AppSpacing.md + AppSpacing.xs,
        ),
        constraints: const BoxConstraints(
          minWidth: 172,
          minHeight: AppSizes.chatCallBubbleHeight,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md - AppSpacing.xs,
          vertical: AppSpacing.sm + AppSpacing.xs - 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.chatIncomingBubble,
          borderRadius: BorderRadius.circular(AppSizes.chatCallBubbleRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CallIconBadge(icon: icon),
            SizedBox(width: AppSpacing.sm + AppSpacing.xs - 2),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTypography.chatBubbleText.copyWith(
                      color: AppColors.chatTextPrimary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: AppSpacing.xs - 2),
                    Text(
                      subtitle,
                      style: AppTypography.chatBubbleText.copyWith(
                        color: AppColors.chatCallBubbleSubtitle,
                        fontSize: 12,
                        height: 1.0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallIconBadge extends StatelessWidget {
  const _CallIconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final size = AppSizes.chatCallBubbleIcon;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.1),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Icon(
        icon,
        color: AppColors.chatThreadHeaderName,
        size: 20,
      ),
    );
  }
}
