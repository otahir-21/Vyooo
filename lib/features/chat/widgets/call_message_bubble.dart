import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
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
    Color iconColor;
    String label;

    switch (callStatus) {
      case CallStatus.ended:
        icon = callType == CallType.video ? Icons.videocam : Icons.call;
        iconColor = AppColors.chatVerified;
        label = callType == CallType.video ? 'Video call' : 'Audio call';
        if (durationSeconds != null && durationSeconds > 0) {
          final m = (durationSeconds ~/ 60).toString().padLeft(2, '0');
          final s = (durationSeconds % 60).toString().padLeft(2, '0');
          label += ' ($m:$s)';
        }
      case CallStatus.missed:
        icon = Icons.call_missed;
        iconColor = AppColors.deleteRed;
        label = 'Missed ${callType == CallType.video ? 'video' : 'audio'} call';
      case CallStatus.declined:
        icon = Icons.call_end;
        iconColor = Colors.orange;
        label = 'Declined ${callType == CallType.video ? 'video' : 'audio'} call';
      case CallStatus.failed:
        icon = Icons.error_outline;
        iconColor = AppColors.deleteRed;
        label = 'Call failed';
      default:
        icon = callType == CallType.video ? Icons.videocam : Icons.call;
        iconColor = AppColors.chatTextSecondary;
        label = callType == CallType.video ? 'Video call' : 'Audio call';
    }

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSent
              ? AppColors.chatOutgoingBubble
              : AppColors.chatIncomingBubble,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: AppTypography.chatTilePreview.copyWith(
                  color: isSent ? Colors.white : AppColors.chatTextPrimary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
