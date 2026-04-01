import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/story_model.dart';
import '../../core/services/story_service.dart';

/// Full-screen story viewer.
/// - Animated progress bar per story in current group.
/// - Tap left half → previous story / group.
/// - Tap right half → next story / group.
/// - Long-press → pause.
/// - Swipe down → dismiss.
class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.groups,
    this.initialGroupIndex = 0,
  });

  final List<StoryGroup> groups;
  final int initialGroupIndex;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late int _groupIndex;
  late int _storyIndex;
  late AnimationController _progress;
  bool _didLongPress = false;

  static const Duration _storyDuration = Duration(seconds: 5);

  StoryGroup get _group => widget.groups[_groupIndex];
  StoryModel get _story => _group.stories[_storyIndex];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _groupIndex = widget.initialGroupIndex;
    _storyIndex = 0;
    _progress = AnimationController(vsync: this, duration: _storyDuration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _advance();
      });
    _startStory();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _progress.dispose();
    super.dispose();
  }

  void _startStory() {
    StoryService().markViewed(_story.id);
    _progress.forward(from: 0);
  }

  void _advance() {
    if (!mounted) return;
    _progress.stop();
    if (_storyIndex < _group.stories.length - 1) {
      setState(() => _storyIndex++);
      _startStory();
    } else if (_groupIndex < widget.groups.length - 1) {
      setState(() {
        _groupIndex++;
        _storyIndex = 0;
      });
      _startStory();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _goBack() {
    if (!mounted) return;
    _progress.stop();
    if (_storyIndex > 0) {
      setState(() => _storyIndex--);
    } else if (_groupIndex > 0) {
      final newGroup = _groupIndex - 1;
      final newStory = widget.groups[newGroup].stories.length - 1;
      setState(() {
        _groupIndex = newGroup;
        _storyIndex = newStory;
      });
    }
    _startStory();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final story = _story;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (_) {
          _didLongPress = false;
          _progress.stop();
        },
        onTapUp: (details) {
          if (_didLongPress) {
            _didLongPress = false;
            _progress.forward();
            return;
          }
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 2) {
            _goBack();
          } else {
            _advance();
          }
        },
        onTapCancel: () {
          if (!_didLongPress) _progress.forward();
        },
        onLongPressStart: (_) => setState(() => _didLongPress = true),
        onLongPressEnd: (_) {
          setState(() => _didLongPress = false);
          _progress.forward();
        },
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 200) {
            Navigator.of(context).pop();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Media ──────────────────────────────────────────────────────
            story.mediaUrl.isNotEmpty
                ? Image.network(
                    story.mediaUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Container(color: Colors.grey[900]),
                  )
                : Container(color: Colors.grey[900]),

            // ── Top gradient ───────────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 140,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── Bottom gradient + caption ──────────────────────────────────
            if (story.caption.isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 180,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

            // ── Progress bars ──────────────────────────────────────────────
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Row(
                  children: List.generate(group.stories.length, (i) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: AnimatedBuilder(
                          animation: _progress,
                          builder: (_, _) {
                            final v = i < _storyIndex
                                ? 1.0
                                : i == _storyIndex
                                    ? _progress.value
                                    : 0.0;
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: v,
                                backgroundColor: Colors.white38,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                                minHeight: 3,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            // ── User info bar ──────────────────────────────────────────────
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 26, 4, 0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white24,
                      backgroundImage: group.avatarUrl.isNotEmpty
                          ? NetworkImage(group.avatarUrl)
                          : null,
                      child: group.avatarUrl.isEmpty
                          ? const Icon(Icons.person,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            group.username.isNotEmpty
                                ? group.username
                                : 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _timeAgo(story.createdAt),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),

            // ── Caption ────────────────────────────────────────────────────
            if (story.caption.isNotEmpty)
              Positioned(
                bottom: 48,
                left: 24,
                right: 24,
                child: Text(
                  story.caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(color: Colors.black54, blurRadius: 6),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
