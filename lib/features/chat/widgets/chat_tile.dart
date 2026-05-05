import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../models/chat_summary_model.dart';
import '../utils/chat_helpers.dart';
import 'unread_badge.dart';

class ChatTile extends StatelessWidget {
  const ChatTile({
    super.key,
    required this.summary,
    required this.onTap,
  });

  final ChatSummaryModel summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = summary.avatarUrl.trim().isNotEmpty;
    final hasUnread = summary.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      splashColor: AppColors.brandDeepMagenta.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasUnread
                    ? const LinearGradient(
                        colors: [Color(0xFFDE106B), Color(0xFF6B21A8)],
                      )
                    : null,
                color: hasUnread ? null : const Color(0xFF2A1B2E),
              ),
              padding: EdgeInsets.all(hasUnread ? 2 : 0),
              child: CircleAvatar(
                radius: hasUnread ? 24 : 27,
                backgroundColor: const Color(0xFF1A0A2E),
                backgroundImage: hasAvatar
                    ? CachedNetworkImageProvider(summary.avatarUrl)
                    : null,
                child: hasAvatar
                    ? null
                    : Icon(
                        summary.type == 'group' ? Icons.group : Icons.person,
                        color: Colors.white54,
                        size: 24,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          summary.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        ChatHelpers.formatInboxTime(summary.lastMessageAt),
                        style: TextStyle(
                          color: hasUnread ? Colors.white : Colors.white.withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          summary.lastMessage.isNotEmpty
                              ? summary.lastMessage
                              : 'Tap to start chatting',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasUnread
                                ? Colors.white.withValues(alpha: 0.8)
                                : Colors.white.withValues(alpha: 0.4),
                            fontSize: 13,
                            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        UnreadBadge(count: summary.unreadCount),
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
