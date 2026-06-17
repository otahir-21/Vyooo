import 'package:flutter/material.dart';

import '../../services/username_validation.dart';

/// `@username` parsing and in-progress mention detection for comment input.
class MentionUtils {
  MentionUtils._();

  /// Matches `@handle` tokens in posted comment text.
  static final RegExp mentionPattern = RegExp(
    r'@([a-zA-Z0-9_.]+)',
    unicode: true,
  );

  /// Unique handles from [text] (without `@`), preserving first-seen order.
  static List<String> extractMentionUsernames(String text) {
    final seen = <String>{};
    final out = <String>[];
    for (final m in mentionPattern.allMatches(text)) {
      final handle = m.group(1)?.trim() ?? '';
      if (handle.isEmpty || seen.contains(handle)) continue;
      seen.add(handle);
      out.add(handle);
    }
    return out;
  }

  /// When the caret is inside `@query`, returns the `@` index and partial handle.
  static ActiveMentionQuery? activeMentionQuery(String text, int cursor) {
    if (text.isEmpty) return null;
    final safeCursor = _safeCursor(cursor, text.length);
    final before = text.substring(0, safeCursor);
    final at = before.lastIndexOf('@');
    if (at < 0) return null;
    if (at > 0) {
      final prev = before[at - 1];
      if (prev != ' ' && prev != '\n' && prev != '\t') return null;
    }
    final query = before.substring(at + 1);
    if (query.contains(RegExp(r'\s'))) return null;
    return ActiveMentionQuery(atIndex: at, query: query);
  }

  /// Replaces the in-progress `@query` with `@username ` and moves the caret.
  static void insertMention(
    TextEditingController controller,
    String username,
    ActiveMentionQuery active,
  ) {
    final text = controller.text;
    final cursor = _safeCursor(controller.selection.baseOffset, text.length);
    final handle = UsernameValidation.normalize(username.trim());
    if (handle.isEmpty) return;

    final before = text.substring(0, active.atIndex);
    final after = text.substring(cursor);
    final mention = '@$handle ';
    final newText = before + mention + after;
    final newCursor = before.length + mention.length;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }

  static int _safeCursor(int cursor, int textLength) {
    if (cursor < 0) return textLength;
    return cursor.clamp(0, textLength);
  }
}

class ActiveMentionQuery {
  const ActiveMentionQuery({required this.atIndex, required this.query});

  final int atIndex;
  final String query;
}
