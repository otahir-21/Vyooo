import 'package:flutter/material.dart';

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
        iconColor = Colors.green;
        label = callType == CallType.video ? 'Video call' : 'Audio call';
        if (durationSeconds != null && durationSeconds > 0) {
          final m = (durationSeconds ~/ 60).toString().padLeft(2, '0');
          final s = (durationSeconds % 60).toString().padLeft(2, '0');
          label += ' ($m:$s)';
        }
      case CallStatus.missed:
        icon = Icons.call_missed;
        iconColor = Colors.red;
        label = 'Missed ${callType == CallType.video ? 'video' : 'audio'} call';
      case CallStatus.declined:
        icon = Icons.call_end;
        iconColor = Colors.orange;
        label = 'Declined ${callType == CallType.video ? 'video' : 'audio'} call';
      case CallStatus.failed:
        icon = Icons.error_outline;
        iconColor = Colors.red;
        label = 'Call failed';
      default:
        icon = callType == CallType.video ? Icons.videocam : Icons.call;
        iconColor = Colors.white54;
        label = callType == CallType.video ? 'Video call' : 'Audio call';
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A061E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2A1B2E), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
