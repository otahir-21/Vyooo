import 'package:flutter_test/flutter_test.dart';
import 'package:vyooo/core/utils/mention_utils.dart';

void main() {
  group('MentionUtils.extractMentionUsernames', () {
    test('extracts unique handles', () {
      expect(
        MentionUtils.extractMentionUsernames('Hi @alice and @bob @alice'),
        ['alice', 'bob'],
      );
    });

    test('returns empty for plain text', () {
      expect(MentionUtils.extractMentionUsernames('no mentions here'), isEmpty);
    });
  });

  group('MentionUtils.activeMentionQuery', () {
    test('detects query at end of text', () {
      final active = MentionUtils.activeMentionQuery('Hello @jo', 9);
      expect(active?.query, 'jo');
      expect(active?.atIndex, 6);
    });

    test('returns null when whitespace in query', () {
      expect(
        MentionUtils.activeMentionQuery('Hello @jo hn', 12),
        isNull,
      );
    });

    test('returns null when @ is inside a word', () {
      expect(
        MentionUtils.activeMentionQuery('email@test.com', 14),
        isNull,
      );
    });

    test('allows mention after newline', () {
      final active = MentionUtils.activeMentionQuery('Line\n@ann', 9);
      expect(active?.query, 'ann');
    });

    test('treats invalid cursor as end of text', () {
      final active = MentionUtils.activeMentionQuery('@jo', -1);
      expect(active?.query, 'jo');
    });
  });
}
