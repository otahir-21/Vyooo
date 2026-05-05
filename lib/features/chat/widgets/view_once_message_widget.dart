import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/message_model.dart';
import '../utils/view_once_helpers.dart';

class ViewOnceMessageWidget extends StatelessWidget {
  const ViewOnceMessageWidget({
    super.key,
    required this.message,
    required this.isSent,
    required this.time,
    required this.currentUid,
    required this.isGroup,
    this.senderName,
    this.onTap,
  });

  final MessageModel message;
  final bool isSent;
  final String time;
  final String currentUid;
  final bool isGroup;
  final String? senderName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final state = ViewOnceHelpers.state(
      message: message,
      currentUid: currentUid,
      isGroup: isGroup,
    );
    final label = ViewOnceHelpers.displayLabel(
      message: message,
      currentUid: currentUid,
      isGroup: isGroup,
    );
    final canOpen = ViewOnceHelpers.canOpen(
      message: message,
      currentUid: currentUid,
    );

    final isOpened = state == ViewOnceState.openedRecipient;
    final isExpired = state == ViewOnceState.expired;
    final isVideo = message.type == 'video';

    IconData icon;
    if (isExpired) {
      icon = Icons.visibility_off;
    } else if (isOpened) {
      icon = Icons.visibility;
    } else if (canOpen) {
      icon = isVideo ? Icons.play_circle_outline : Icons.photo_outlined;
    } else {
      icon = isVideo ? Icons.videocam_outlined : Icons.photo_camera_outlined;
    }

    Widget content = Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
        ),
        margin: EdgeInsets.only(
          left: isSent ? 60 : 12,
          right: isSent ? 12 : 60,
          top: 3,
          bottom: 3,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSent
              ? AppColors.brandDeepMagenta.withValues(alpha: 0.7)
              : const Color(0xFF2A1B2E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isSent ? 18 : 4),
            bottomRight: Radius.circular(isSent ? 4 : 18),
          ),
          border: canOpen
              ? Border.all(color: AppColors.brandMagenta.withValues(alpha: 0.5), width: 1)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: canOpen
                      ? AppColors.brandMagenta
                      : Colors.white.withValues(alpha: 0.5),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: canOpen
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                      fontStyle: (isOpened || isExpired) ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  color: AppColors.brandMagenta.withValues(alpha: 0.6),
                  size: 6,
                ),
                const SizedBox(width: 4),
                Text(
                  'View once',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 10,
                  ),
                ),
                const Spacer(),
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (canOpen) {
      content = GestureDetector(onTap: onTap, child: content);
    }

    if (senderName != null) {
      return Align(
        alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 2),
              child: Text(
                senderName!,
                style: const TextStyle(
                  color: AppColors.brandMagenta,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            content,
          ],
        ),
      );
    }

    return content;
  }
}
