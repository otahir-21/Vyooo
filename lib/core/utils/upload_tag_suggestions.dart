import 'hashtag_utils.dart';

/// Suggests hashtags for the upload flow from the creator’s own text and category.
///
/// Deliberately **does not** pad to a high count with generic discovery tags — that
/// produced irrelevant hashtags and trained bad posting habits. For stronger
/// relevance at scale, add a moderated server-side or AI step later; keep client
/// output aligned with [HashtagUtils.normalizeForQuery] rules.
class UploadTagSuggestions {
  UploadTagSuggestions._();

  /// Upper bound on how many distinct suggestions we show (user may add up to 30).
  static const int defaultMaxSuggestions = 15;

  /// Single brand tag appended when there is room and it is not already implied.
  static const String _brandTag = 'vyooo';

  /// Function words / fillers — not useful as standalone hashtags.
  static const Set<String> _stopwords = {
    'a', 'an', 'and', 'are', 'as', 'at', 'be', 'been', 'being', 'but', 'by',
    'can', 'could', 'did', 'do', 'does', 'doing', 'done', 'for', 'from', 'get',
    'got', 'had', 'has', 'have', 'having', 'he', 'her', 'here', 'hers', 'him',
    'his', 'how', 'i', 'if', 'in', 'into', 'is', 'it', 'its', 'just', 'me',
    'might', 'more', 'most', 'much', 'must', 'my', 'no', 'nor', 'not', 'of',
    'off', 'on', 'once', 'only', 'or', 'our', 'ours', 'out', 'over', 'own',
    'same', 'she', 'should', 'so', 'some', 'such', 'than', 'that', 'the',
    'their', 'them', 'then', 'there', 'these', 'they', 'this', 'those',
    'through', 'to', 'too', 'under', 'until', 'up', 'us', 'very', 'was',
    'we', 'were', 'what', 'when', 'where', 'which', 'while', 'who', 'whom',
    'why', 'will', 'with', 'would', 'you', 'your', 'yours',
  };

  /// Returns up to [maxSuggestions] unique normalized tags. Order: words from
  /// [title] (then [description]), optional category slug, optional [_brandTag].
  /// Never pads with unrelated viral/FYP lists.
  static List<String> build({
    required String title,
    String? description,
    String? category,
    int maxSuggestions = defaultMaxSuggestions,
  }) {
    if (maxSuggestions <= 0) return const [];

    final out = <String>[];
    final seen = <String>{};

    void add(String raw) {
      if (out.length >= maxSuggestions) return;
      final n = HashtagUtils.normalizeForQuery(raw);
      if (n.length < 2 || n.length > 32) return;
      if (_stopwords.contains(n)) return;
      if (seen.contains(n)) return;
      seen.add(n);
      out.add(n);
    }

    for (final w in _contentWords(title)) {
      add(w);
    }
    for (final w in _contentWords(description ?? '')) {
      add(w);
    }

    final cat = category?.trim();
    if (cat != null && cat.isNotEmpty) {
      final catSlug = HashtagUtils.normalizeForQuery(
        cat.replaceAll(RegExp(r'\s+'), '_'),
      );
      // "Other" is a bucket, not a useful search tag.
      if (catSlug.isNotEmpty && catSlug != 'other') {
        add(catSlug);
      }
    }

    if (out.isNotEmpty && out.length < maxSuggestions && !seen.contains(_brandTag)) {
      add(_brandTag);
    }

    return out;
  }

  static Iterable<String> _contentWords(String text) sync* {
    final parts = text.toLowerCase().split(RegExp(r'[^a-z0-9]+'));
    for (final p in parts) {
      final t = p.trim();
      if (t.length < 2) continue;
      if (t.length > 32) continue;
      yield t;
    }
  }
}
