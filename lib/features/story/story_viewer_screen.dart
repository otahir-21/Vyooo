import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/models/story_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/story_service.dart';
import '../comments/widgets/comments_bottom_sheet.dart';

/// Full-screen story viewer with image/video, like, comment, delete, highlights.
class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.groups,
    this.initialGroupIndex = 0,
    this.initialStoryIndex = 0,
    this.onStoriesModified,
  });

  final List<StoryGroup> groups;
  final int initialGroupIndex;
  final int initialStoryIndex;
  final VoidCallback? onStoriesModified;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with TickerProviderStateMixin {
  late int _groupIndex;
  late int _storyIndex;
  AnimationController? _imageProgress;
  VideoPlayerController? _video;
  bool _didLongPress = false;
  bool _videoEndedHandled = false;

  static const Duration _imageStoryDuration = Duration(seconds: 5);

  final _storyService = StoryService();
  Set<String> _likedStoryIds = {};
  bool _likesLoaded = false;
  bool _currentLiked = false;
  int _likeCount = 0;
  int _commentCount = 0;

  StoryGroup get _group => widget.groups[_groupIndex];
  StoryModel get _story => _group.stories[_storyIndex];

  String? get _myUid => AuthService().currentUser?.uid;

  bool get _isOwnStory =>
      _myUid != null && _myUid!.isNotEmpty && _story.userId == _myUid;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _groupIndex = widget.initialGroupIndex;
    _storyIndex = widget.initialStoryIndex;
    _prefetchLikes();
    _initStoryPlayback();
  }

  Future<void> _prefetchLikes() async {
    final ids = <String>{};
    for (final g in widget.groups) {
      for (final s in g.stories) {
        ids.add(s.id);
      }
    }
    final liked = await _storyService.getLikedStoryIds(ids);
    if (!mounted) return;
    setState(() {
      _likedStoryIds = liked;
      _likesLoaded = true;
    });
    _syncInteractionCounters();
  }

  void _syncInteractionCounters() {
    _currentLiked = _likedStoryIds.contains(_story.id);
    _likeCount = _story.likes;
    _commentCount = _story.comments;
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _disposePlayback();
    super.dispose();
  }

  void _disposePlayback() {
    _imageProgress?.dispose();
    _imageProgress = null;
    _video?.removeListener(_onVideoTick);
    _video?.dispose();
    _video = null;
  }

  void _initStoryPlayback() {
    _disposePlayback();
    _videoEndedHandled = false;
    StoryService().markViewed(_story.id);
    _syncInteractionCounters();

    if (_story.isVideo && _story.mediaUrl.isNotEmpty) {
      final uri = Uri.tryParse(_story.mediaUrl);
      if (uri != null && uri.hasScheme) {
        _video = VideoPlayerController.networkUrl(uri)
          ..initialize().then((_) {
            if (!mounted) return;
            setState(() {});
            _video!.play();
            _video!.addListener(_onVideoTick);
          }).catchError((_) {
            if (mounted) setState(() {});
          });
      }
    } else {
      final dur = _story.durationMs > 500
          ? Duration(milliseconds: _story.durationMs)
          : _imageStoryDuration;
      _imageProgress = AnimationController(vsync: this, duration: dur)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _advance();
        })
        ..forward(from: 0);
    }
  }

  void _onVideoTick() {
    final c = _video;
    if (c == null || !c.value.isInitialized || _videoEndedHandled) return;
    if (c.value.hasError) return;
    final d = c.value.duration;
    if (d == Duration.zero) return;
    if (c.value.position >= d - const Duration(milliseconds: 300)) {
      _videoEndedHandled = true;
      _advance();
      return;
    }
    setState(() {});
  }

  void _advance() {
    if (!mounted) return;
    _video?.removeListener(_onVideoTick);
    _imageProgress?.stop();
    if (_storyIndex < _group.stories.length - 1) {
      setState(() => _storyIndex++);
      _initStoryPlayback();
    } else if (_groupIndex < widget.groups.length - 1) {
      setState(() {
        _groupIndex++;
        _storyIndex = 0;
      });
      _initStoryPlayback();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _goBack() {
    if (!mounted) return;
    _video?.removeListener(_onVideoTick);
    _imageProgress?.stop();
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
    _initStoryPlayback();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  Future<void> _onLikeTap() async {
    final uid = _myUid;
    if (uid == null || uid.isEmpty) return;
    if (!_likesLoaded) return;
    final next = await _storyService.toggleStoryLike(
      storyId: _story.id,
      currentlyLiked: _currentLiked,
    );
    if (!mounted) return;
    setState(() {
      _currentLiked = next;
      _likeCount += next ? 1 : -1;
      if (_likeCount < 0) _likeCount = 0;
      if (next) {
        _likedStoryIds.add(_story.id);
      } else {
        _likedStoryIds.remove(_story.id);
      }
    });
  }

  void _onCommentTap() {
    showStoryCommentsBottomSheet(
      context,
      storyId: _story.id,
      onCommentCountChanged: (delta) {
        if (!mounted) return;
        setState(() {
          _commentCount += delta;
          if (_commentCount < 0) _commentCount = 0;
        });
      },
    );
  }

  Future<void> _confirmDeleteStory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0020),
        title: const Text('Delete story?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This story will be removed for everyone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFFF2D55))),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _storyService.deleteStory(_story.id);
      if (!mounted) return;
      widget.onStoriesModified?.call();
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete story.')),
        );
      }
    }
  }

  Future<void> _openHighlightPicker() async {
    final uid = _myUid;
    if (uid == null) return;
    final highlights = await _storyService.getHighlightsForUser(uid);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF2A1B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Add to highlight',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.add, color: Colors.white70),
                title: const Text(
                  'New highlight',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final nameCtrl = TextEditingController();
                  final name = await showDialog<String>(
                    context: context,
                    builder: (dctx) => AlertDialog(
                      backgroundColor: const Color(0xFF1A0020),
                      title: const Text('Highlight name',
                          style: TextStyle(color: Colors.white)),
                      content: TextField(
                        controller: nameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'e.g. Travel',
                          hintStyle: TextStyle(color: Colors.white38),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dctx),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(
                            dctx,
                            nameCtrl.text.trim(),
                          ),
                          child: const Text('Create'),
                        ),
                      ],
                    ),
                  );
                  if (name == null || name.isEmpty || !mounted) return;
                  try {
                    final hid = await _storyService.createHighlight(name);
                    await _storyService.addStoryToHighlight(
                      highlightId: hid,
                      story: _story,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Added to "$name"')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not save: $e')),
                      );
                    }
                  }
                },
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: highlights.length,
                  itemBuilder: (_, i) {
                    final h = highlights[i];
                    return ListTile(
                      title: Text(
                        h.title,
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () async {
                        Navigator.pop(ctx);
                        try {
                          await _storyService.addStoryToHighlight(
                            highlightId: h.id,
                            story: _story,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Added to "${h.title}"')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not save: $e')),
                            );
                          }
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onMoreTap() {
    if (!_isOwnStory) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF2A1B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.collections_bookmark_outlined,
                  color: Colors.white),
              title: const Text('Add to highlight',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _openHighlightPicker();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.white70),
              title: const Text('Delete story',
                  style: TextStyle(color: Color(0xFFFF2D55))),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteStory();
              },
            ),
          ],
        ),
      ),
    );
  }

  double get _progressValue {
    final v = _video;
    if (v != null && v.value.isInitialized) {
      final d = v.value.duration.inMilliseconds;
      if (d <= 0) return 0;
      return (v.value.position.inMilliseconds / d).clamp(0.0, 1.0);
    }
    final img = _imageProgress;
    if (img != null) return img.value;
    return 0;
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
          _imageProgress?.stop();
          _video?.pause();
        },
        onTapUp: (details) {
          if (_didLongPress) {
            _didLongPress = false;
            _imageProgress?.forward();
            _video?.play();
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
          if (!_didLongPress) {
            _imageProgress?.forward();
            _video?.play();
          }
        },
        onLongPressStart: (_) => setState(() => _didLongPress = true),
        onLongPressEnd: (_) {
          setState(() => _didLongPress = false);
          _imageProgress?.forward();
          _video?.play();
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
            ColoredBox(
              color: Colors.black,
              child: Center(
                child: story.isVideo && story.mediaUrl.isNotEmpty
                    ? _buildVideo(story)
                    : story.mediaUrl.isNotEmpty
                        ? Image.network(
                            story.mediaUrl,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, _, _) =>
                                Container(color: Colors.grey[900]),
                          )
                        : Container(color: Colors.grey[900]),
              ),
            ),
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
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                      child: Row(
                        children: List.generate(group.stories.length, (i) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: i < _storyIndex
                                      ? 1.0
                                      : i == _storyIndex
                                          ? _progressValue
                                          : 0.0,
                                  backgroundColor: Colors.white38,
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                  minHeight: 3,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 16, 4, 0),
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
                          if (_isOwnStory)
                            IconButton(
                              icon: const Icon(Icons.more_horiz,
                                  color: Colors.white, size: 24),
                              onPressed: _onMoreTap,
                            ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.white, size: 22),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (story.caption.isNotEmpty)
              Positioned(
                bottom: 100,
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
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ActionChip(
                      icon: _currentLiked ? Icons.favorite : Icons.favorite_border,
                      label: '$_likeCount',
                      onTap: _onLikeTap,
                    ),
                    const SizedBox(width: 24),
                    _ActionChip(
                      icon: Icons.mode_comment_outlined,
                      label: '$_commentCount',
                      onTap: _onCommentTap,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo(StoryModel story) {
    final c = _video;
    if (c == null || !c.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }
    return AspectRatio(
      aspectRatio: c.value.aspectRatio == 0 ? 9 / 16 : c.value.aspectRatio,
      child: VideoPlayer(c),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
