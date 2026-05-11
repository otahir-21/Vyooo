import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/models/story_highlight_model.dart';
import '../../core/services/story_service.dart';
import '../../core/utils/story_playback_limits.dart';

/// Swipe through saved highlight items (persists beyond 24h story expiry).
class HighlightViewerScreen extends StatefulWidget {
  const HighlightViewerScreen({
    super.key,
    required this.userId,
    required this.highlightId,
    required this.title,
  });

  final String userId;
  final String highlightId;
  final String title;

  @override
  State<HighlightViewerScreen> createState() => _HighlightViewerScreenState();
}

class _HighlightViewerScreenState extends State<HighlightViewerScreen> {
  List<StoryHighlightItem> _items = [];
  bool _loading = true;
  String? _error;
  int _index = 0;
  VideoPlayerController? _video;
  int _videoClipIndex = 0;
  int _videoClipCount = 1;
  bool _videoClipHandled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _detachVideoListener();
    _video?.dispose();
    super.dispose();
  }

  void _detachVideoListener() {
    _video?.removeListener(_onVideoTick);
  }

  void _onVideoTick() {
    final c = _video;
    if (c == null || !c.value.isInitialized || _videoClipHandled) return;
    if (c.value.hasError) return;
    final totalMs = c.value.duration.inMilliseconds;
    if (totalMs <= 0) return;
    final cap = storyMaxSlideMs;
    final slotEndMs = ((_videoClipIndex + 1) * cap) < totalMs
        ? (_videoClipIndex + 1) * cap
        : totalMs;
    final posMs = c.value.position.inMilliseconds;
    if (posMs < slotEndMs - 300) {
      return;
    }
    if (_videoClipIndex < _videoClipCount - 1) {
      _videoClipHandled = true;
      final next = _videoClipIndex + 1;
      c.seekTo(Duration(milliseconds: next * cap)).then((_) {
        if (!mounted || _video != c) return;
        setState(() {
          _videoClipIndex = next;
          _videoClipHandled = false;
        });
        c.play();
      });
      return;
    }
    _videoClipHandled = true;
    if (_index < _items.length - 1) {
      setState(() => _index++);
      _prepareMediaForIndex(_index);
    } else {
      c.pause();
      if (mounted) setState(() {});
    }
  }

  Future<void> _load() async {
    try {
      final list = await StoryService().getHighlightItems(
        userId: widget.userId,
        highlightId: widget.highlightId,
      );
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
      if (list.isNotEmpty) {
        await _prepareMediaForIndex(0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _prepareMediaForIndex(int i) async {
    _detachVideoListener();
    await _video?.dispose();
    _video = null;
    _videoClipIndex = 0;
    _videoClipCount = 1;
    _videoClipHandled = false;
    if (i < 0 || i >= _items.length) return;
    final it = _items[i];
    if (!it.isVideo || it.mediaUrl.isEmpty) {
      if (mounted) setState(() {});
      return;
    }
    final uri = Uri.tryParse(it.mediaUrl);
    if (uri == null || !uri.hasScheme) return;
    final c = VideoPlayerController.networkUrl(uri);
    await c.initialize();
    if (!mounted) return;
    final totalMs = c.value.duration.inMilliseconds;
    final clips = storySlideCountForDurationMs(totalMs);
    setState(() {
      _video = c;
      _videoClipCount = clips;
      _videoClipIndex = 0;
      _videoClipHandled = false;
    });
    await c.seekTo(Duration.zero);
    if (!mounted) return;
    c.addListener(_onVideoTick);
    await c.play();
    if (mounted) setState(() {});
  }

  void _next() {
    final c = _video;
    final it = _items.isEmpty ? null : _items[_index];
    if (it != null &&
        it.isVideo &&
        c != null &&
        c.value.isInitialized &&
        _videoClipCount > 1 &&
        _videoClipIndex < _videoClipCount - 1) {
      final cap = storyMaxSlideMs;
      final next = _videoClipIndex + 1;
      _detachVideoListener();
      c.seekTo(Duration(milliseconds: next * cap)).then((_) {
        if (!mounted || _video != c) return;
        setState(() {
          _videoClipIndex = next;
          _videoClipHandled = false;
        });
        c.addListener(_onVideoTick);
        c.play();
      });
      return;
    }
    if (_index >= _items.length - 1) return;
    setState(() => _index++);
    _prepareMediaForIndex(_index);
  }

  void _prev() {
    final c = _video;
    final it = _items.isEmpty ? null : _items[_index];
    if (it != null &&
        it.isVideo &&
        c != null &&
        c.value.isInitialized &&
        _videoClipCount > 1 &&
        _videoClipIndex > 0) {
      final cap = storyMaxSlideMs;
      final prev = _videoClipIndex - 1;
      _detachVideoListener();
      c.seekTo(Duration(milliseconds: prev * cap)).then((_) {
        if (!mounted || _video != c) return;
        setState(() {
          _videoClipIndex = prev;
          _videoClipHandled = false;
        });
        c.addListener(_onVideoTick);
        c.play();
      });
      return;
    }
    if (_index <= 0) return;
    setState(() => _index--);
    _prepareMediaForIndex(_index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.white70),
                  ),
                )
              : _items.isEmpty
                  ? const Center(
                      child: Text(
                        'No items in this highlight yet.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : GestureDetector(
                      onTapUp: (d) {
                        final w = MediaQuery.sizeOf(context).width;
                        if (d.globalPosition.dx < w / 2) {
                          _prev();
                        } else {
                          _next();
                        }
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(child: _buildMedia(_items[_index])),
                          if (_items[_index].caption.isNotEmpty)
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 32,
                              child: Text(
                                _items[_index].caption,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  shadows: [
                                    Shadow(color: Colors.black54, blurRadius: 8),
                                  ],
                                ),
                              ),
                            ),
                          Positioned(
                            top: 8,
                            left: 0,
                            right: 0,
                            child: Text(
                              '${_index + 1} / ${_items.length}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildMedia(StoryHighlightItem it) {
    if (it.isVideo) {
      final v = _video;
      if (v == null || !v.value.isInitialized) {
        return const CircularProgressIndicator(color: Colors.white54);
      }
      return AspectRatio(
        aspectRatio:
            v.value.aspectRatio == 0 ? 9 / 16 : v.value.aspectRatio,
        child: VideoPlayer(v),
      );
    }
    if (it.mediaUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    return Image.network(it.mediaUrl, fit: BoxFit.contain);
  }
}
