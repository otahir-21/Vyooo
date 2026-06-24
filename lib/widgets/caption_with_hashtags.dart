import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/navigation/open_hashtag_feed.dart';

/// Renders [text] with tappable `#hashtag` segments.
class CaptionWithHashtags extends StatefulWidget {
  const CaptionWithHashtags({
    super.key,
    required this.text,
    this.style = const TextStyle(
      color: Colors.white,
      fontSize: 14,
      height: 1.33,
    ),
    this.hashtagStyle,
    this.hashtagColor = AppColors.brandPink,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle style;
  final TextStyle? hashtagStyle;
  final Color hashtagColor;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  State<CaptionWithHashtags> createState() => _CaptionWithHashtagsState();
}

class _CaptionWithHashtagsState extends State<CaptionWithHashtags> {
  final List<TapGestureRecognizer> _recognizers = [];
  List<InlineSpan> _spans = const [];
  String _spansSource = '';

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  void _rebuildSpansIfNeeded() {
    if (_spansSource == widget.text &&
        (_spans.isNotEmpty || widget.text.isEmpty)) {
      return;
    }
    _disposeRecognizers();
    _spansSource = widget.text;

    final text = widget.text;
    final spans = <InlineSpan>[];
    // Match # followed by non-space, non-# run (covers punctuation; normalized on tap).
    final pattern = RegExp(r'#[^\s#]+', unicode: true);
    var start = 0;

    for (final m in pattern.allMatches(text)) {
      if (m.start > start) {
        spans.add(
          TextSpan(text: text.substring(start, m.start), style: widget.style),
        );
      }
      final raw = m.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => openHashtagInSearch(context, raw);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: raw,
          style: widget.hashtagStyle ??
              widget.style.copyWith(
                color: widget.hashtagColor,
                fontWeight: FontWeight.w600,
              ),
          recognizer: recognizer,
        ),
      );
      start = m.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: widget.style));
    }
    _spans = spans.isEmpty && text.isEmpty ? const [TextSpan(text: '')] : spans;
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  void didUpdateWidget(CaptionWithHashtags oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.hashtagColor != widget.hashtagColor) {
      _spans = const [];
      _spansSource = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    _rebuildSpansIfNeeded();
    return SizedBox(
      width: double.infinity,
      child: Text.rich(
        TextSpan(children: _spans),
        maxLines: widget.maxLines,
        overflow: widget.overflow ?? TextOverflow.clip,
        textAlign: TextAlign.start,
      ),
    );
  }
}
