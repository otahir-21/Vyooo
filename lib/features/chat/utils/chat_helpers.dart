import 'package:cloud_firestore/cloud_firestore.dart';

abstract final class ChatHelpers {
  static String directChatId(String uidA, String uidB) {
    if (uidA.trim().isEmpty || uidB.trim().isEmpty) {
      throw ArgumentError('UIDs must not be empty');
    }
    if (uidA == uidB) {
      throw ArgumentError('UIDs must be different');
    }
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  static String buildTextPreview(String text, {int maxLength = 100}) {
    final trimmed = text.trim();
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength)}…';
  }

  static String formatInboxTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.day}/${date.month}/${date.year}';
  }
}