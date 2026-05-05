import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/message_model.dart';
import '../services/chat_service.dart';

class ViewOnceMediaViewerScreen extends StatefulWidget {
  const ViewOnceMediaViewerScreen({
    super.key,
    required this.message,
    required this.currentUid,
    required this.chatId,
  });

  final MessageModel message;
  final String currentUid;
  final String chatId;

  @override
  State<ViewOnceMediaViewerScreen> createState() =>
      _ViewOnceMediaViewerScreenState();
}

class _ViewOnceMediaViewerScreenState extends State<ViewOnceMediaViewerScreen>
    with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _videoError = false;
  bool _imageLoaded = false;
  bool _imageError = false;
  bool _markedViewed = false;
  bool _mediaOpened = false;

  bool get _isVideo => widget.message.type == 'video';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_isVideo) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    final url = widget.message.mediaUrl ?? '';
    if (url.isEmpty) {
      if (mounted) setState(() => _videoError = true);
      return;
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoController = controller;
    try {
      await controller.initialize();
      if (mounted) {
        setState(() {
          _videoInitialized = true;
          _mediaOpened = true;
        });
        controller.play();
      }
    } catch (_) {
      if (mounted) setState(() => _videoError = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _markViewedAndPop();
    }
  }

  Future<void> _markViewedAndPop() async {
    if (_markedViewed) return;
    if (!_mediaOpened) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    _markedViewed = true;
    _videoController?.pause();
    await _chatService.markViewOnceViewed(
      chatId: widget.chatId,
      messageId: widget.message.id,
      uid: widget.currentUid,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _markViewedAndPop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _markViewedAndPop,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(child: _isVideo ? _buildVideo() : _buildImage()),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: _markViewedAndPop,
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'View once',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final url = widget.message.mediaUrl ?? '';
    if (url.isEmpty) {
      return const Icon(Icons.broken_image, color: Colors.white38, size: 64);
    }
    return Image.network(
      url,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          if (!_mediaOpened) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _mediaOpened = true);
            });
          }
          if (!_imageLoaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _imageLoaded = true);
            });
          }
          return child;
        }
        return const CircularProgressIndicator(
          color: Color(0xFFDE106B),
          strokeWidth: 2,
        );
      },
      errorBuilder: (_, _, _) {
        if (!_imageError) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _imageError = true);
          });
        }
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.white38, size: 64),
            SizedBox(height: 12),
            Text(
              'Could not load media',
              style: TextStyle(color: Colors.white54, fontSize: 15),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVideo() {
    if (_videoError) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.white38, size: 64),
          SizedBox(height: 12),
          Text(
            'Could not load video',
            style: TextStyle(color: Colors.white54, fontSize: 15),
          ),
        ],
      );
    }
    if (!_videoInitialized) {
      return const CircularProgressIndicator(
        color: Color(0xFFDE106B),
        strokeWidth: 2,
      );
    }
    final controller = _videoController!;
    return AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: VideoPlayer(controller),
    );
  }
}
