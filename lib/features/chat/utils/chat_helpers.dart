import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/message_model.dart';
import 'chat_constants.dart';

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

  static String messageBodyPreview(MessageModel message, {int maxLength = 80}) {
    if (message.deletedForEveryone) return 'Message deleted';
    switch (message.type) {
      case ChatMessageTypes.text:
        final trimmed = message.text.trim();
        if (trimmed.isEmpty) return 'Message';
        return buildTextPreview(trimmed, maxLength: maxLength);
      case ChatMessageTypes.image:
        return message.isViewOnce ? 'View-once photo' : 'Photo';
      case ChatMessageTypes.video:
        return message.isViewOnce ? 'View-once video' : 'Video';
      case ChatMessageTypes.audio:
        return 'Voice message';
      case ChatMessageTypes.gif:
        return 'GIF';
      case ChatMessageTypes.call:
        return message.text.trim().isNotEmpty ? message.text.trim() : 'Call';
      default:
        return 'Message';
    }
  }

  /// Inbox row timestamp — relative only (e.g. 10m, 2h, 3d). Never a calendar date.
  static String formatInboxTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate().toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);
    final diff = now.difference(date);

    if (messageDay == today) {
      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      return '${diff.inHours}h';
    }

    final dayDiff = today.difference(messageDay).inDays;
    if (dayDiff == 1) return '1d';
    if (dayDiff < 7) return '${dayDiff}d';
    if (dayDiff < 30) return '${dayDiff ~/ 7}w';
    if (dayDiff < 365) return '${dayDiff ~/ 30}mo';
    return '${dayDiff ~/ 365}y';
  }

  /// Thread date pill — "Today 8:00 AM", "Yesterday 6:55 PM", "Friday 2:03 AM".
  static String formatThreadDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);
    final diffDays = today.difference(messageDay).inDays;

    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final time = '$hour:$minute $period';

    if (diffDays == 0) return 'Today $time';
    if (diffDays == 1) return 'Yesterday $time';

    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final weekday = weekdays[date.weekday - 1];
    return '$weekday $time';
  }

  static bool isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Reads avatar from a chat [participantMap] entry (`avatarUrl` is canonical).
  static String? participantAvatarFromMap(Map<String, dynamic>? participant) {
    if (participant == null) return null;
    for (final key in ['avatarUrl', 'profileImage', 'photoURL']) {
      final value = (participant[key] as String?)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static String? participantDisplayNameFromMap(
    Map<String, dynamic>? participant,
  ) {
    if (participant == null) return null;
    final displayName = (participant['displayName'] as String?)?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final username = (participant['username'] as String?)?.trim();
    if (username != null && username.isNotEmpty) return username;
    return null;
  }
}