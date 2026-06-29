import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../../../core/constants/app_colors.dart';
import '../screens/chat_media_viewer_screen.dart';
import 'message_reply_quote.dart';

class MediaMessageWidget extends StatelessWidget {
  const MediaMessageWidget({
    super.key,
    required this.message,
    required this.isSent,
    required this.time,
    this.seenText,
    this.replyToSenderName,
    this.replyToPreview,
  });

  final MessageModel message;
  final bool isSent;
  final String time;
  final String? seenText;
  final String? replyToSenderName;
  final String? replyToPreview;

  @override
  Widget build(BuildContext context) {
    final isVideo = message.type == 'video';
    final isGif = message.type == 'gif';
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.70,
        ),
        margin: EdgeInsets.only(
          left: isSent ? 60 : 10,
          right: isSent ? 10 : 60,
          top: 2,
          bottom: 2,
        ),
        decoration: BoxDecoration(
          color: isSent ? null : AppColors.chatIncomingBubble,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isSent ? 16 : 4),
            bottomRight: Radius.circular(isSent ? 4 : 16),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (replyToSenderName != null && replyToPreview != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: MessageReplyQuote(
                  senderName: replyToSenderName!,
                  preview: replyToPreview!,
                  isSentBubble: isSent,
                ),
              ),
            GestureDetector(
              onTap: () => _openViewer(context),
              child: Stack(
                children: [
                  _buildMediaContent(isVideo, isGif),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (seenText != null) ...[
                            Text(
                              seenText!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            time,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent(bool isVideo, bool isGif) {
    final url = message.mediaUrl ?? '';
    final thumbUrl = message.thumbnailUrl ?? '';
    final displayUrl = isGif
        ? url
        : (thumbUrl.isNotEmpty ? thumbUrl : url);

    if (displayUrl.isEmpty) {
      return Container(
        height: 180,
        color: Colors.black26,
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.white38, size: 40),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        CachedNetworkImage(
          imageUrl: displayUrl,
          width: double.infinity,
          height: 220,
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(
            height: 220,
            color: Colors.black26,
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFDE106B),
                strokeWidth: 2,
              ),
            ),
          ),
          errorWidget: (_, _, _) => Container(
            height: 220,
            color: Colors.black26,
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.white38, size: 40),
            ),
          ),
        ),
        if (isVideo)
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
      ],
    );
  }

  void _openViewer(BuildContext context) {
    if (message.type == 'gif') return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatMediaViewerScreen(
          mediaUrl: message.mediaUrl ?? '',
          thumbnailUrl: message.thumbnailUrl ?? '',
          isVideo: message.type == 'video',
        ),
      ),
    );
  }
}
