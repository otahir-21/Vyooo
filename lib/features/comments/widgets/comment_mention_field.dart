import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/services/comment_diagnostics.dart';
import '../../../core/services/user_service.dart';
import '../../../core/utils/mention_utils.dart';
import '../comment_text_styles.dart';

/// Comment text field with compact `@` mention autocomplete.
class CommentMentionField extends StatefulWidget {
  const CommentMentionField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isReply,
    required this.fieldPadding,
    this.onSubmit,
    this.canSubmit = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isReply;
  final double fieldPadding;
  final VoidCallback? onSubmit;
  final bool canSubmit;

  @override
  State<CommentMentionField> createState() => CommentMentionFieldState();
}

class CommentMentionFieldState extends State<CommentMentionField> {
  static const int _maxSuggestions = 4;
  static const double _rowHeight = 36;

  final UserService _userService = UserService();
  Timer? _debounce;
  ActiveMentionQuery? _activeMention;
  List<UserDiscoveryItem> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void dismissSuggestions() {
    if (_suggestions.isEmpty && _activeMention == null) return;
    setState(() {
      _activeMention = null;
      _suggestions = const [];
    });
    _debounce?.cancel();
  }

  void _scheduleSearch(ActiveMentionQuery active) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      _loadSuggestions(active);
    });
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    final active = MentionUtils.activeMentionQuery(text, cursor);
    if (active == null) {
      if (_activeMention != null || _suggestions.isNotEmpty) {
        setState(() {
          _activeMention = null;
          _suggestions = const [];
        });
      }
      return;
    }

    if (_activeMention?.atIndex == active.atIndex &&
        _activeMention?.query == active.query) {
      return;
    }

    setState(() => _activeMention = active);
    _scheduleSearch(active);
  }

  Future<void> _loadSuggestions(ActiveMentionQuery active) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      if (!mounted) return;
      setState(() => _suggestions = const []);
      return;
    }

    try {
      final items = await _userService.searchUsersForMention(
        currentUid: uid,
        query: active.query,
        limit: _maxSuggestions,
      );
      if (!mounted) return;
      if (_activeMention?.atIndex != active.atIndex ||
          _activeMention?.query != active.query) {
        return;
      }
      if (kDebugMode) {
        CommentDiagnostics.log(
          'Mention suggestions for "@${active.query}": '
          '${items.map((e) => e.username).join(', ')}',
        );
      }
      setState(() => _suggestions = items);
    } catch (e, st) {
      CommentDiagnostics.logFailure('mention suggestions', e, st);
      if (!mounted) return;
      setState(() => _suggestions = const []);
    }
  }

  void _selectSuggestion(UserDiscoveryItem item, ActiveMentionQuery active) {
    final before = widget.controller.text;
    MentionUtils.insertMention(widget.controller, item.username, active);
    final after = widget.controller.text;
    if (kDebugMode) {
      CommentDiagnostics.log(
        'Inserted mention @${item.username}: "$before" -> "$after"',
      );
    }
    setState(() {
      _activeMention = null;
      _suggestions = const [];
    });
    widget.focusNode.requestFocus();
  }

  void _trySubmit() {
    dismissSuggestions();
    if (widget.canSubmit) {
      widget.onSubmit?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeMention;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_suggestions.isNotEmpty && active != null)
          _buildSuggestionStrip(active),
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          minLines: 1,
          maxLines: 4,
          style: CommentTextStyles.input,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _trySubmit(),
          decoration: InputDecoration(
            hintText: widget.isReply ? 'Write a reply…' : 'Add a comment…',
            hintStyle: CommentTextStyles.inputHint,
            filled: true,
            fillColor: const Color(0x14FFFFFF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(
                color: Color(0x33FFFFFF),
                width: 1,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: widget.fieldPadding,
            ),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }

  Widget _buildSuggestionStrip(ActiveMentionQuery active) {
    final visible = _suggestions.take(_maxSuggestions).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: const Color(0xFF2A1B2E),
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              _SuggestionRow(
                item: visible[i],
                onSelect: () => _selectSuggestion(visible[i], active),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.item, required this.onSelect});

  final UserDiscoveryItem item;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = item.avatarUrl.trim().isNotEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onSelect(),
      child: SizedBox(
        height: CommentMentionFieldState._rowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFF2A2A3A),
                backgroundImage: hasAvatar
                    ? CachedNetworkImageProvider(item.avatarUrl)
                    : null,
                child: hasAvatar
                    ? null
                    : Text(
                        item.displayName.isNotEmpty
                            ? item.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '@${item.username}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (item.displayName.isNotEmpty &&
                          item.displayName.toLowerCase() !=
                              item.username.toLowerCase())
                        TextSpan(
                          text: '  ${item.displayName}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
