import 'package:flutter/material.dart';

import '../models/reel_media_item.dart';
import '../models/video_360_metadata.dart';
import '../theme/app_spacing.dart';
import 'double_tap_like_overlay.dart';
import '../../widgets/reel_item_widget.dart';

/// Instagram-style horizontal media carousel for multi-media posts.
///
/// Renders one page per [ReelMediaItem] with dot indicators and an
/// "n/total" counter. Only the **active** page's video plays (and only while
/// [isVisible] is true), so swiping never leaks audio or holds extra video
/// decoders.
class PostMediaCarousel extends StatefulWidget {
  const PostMediaCarousel({
    super.key,
    required this.items,
    required this.isVisible,
    this.video360 = Video360Metadata.flat,
    this.imageFit = BoxFit.cover,
    this.onDoubleTap,
    this.onActiveVideoCompleted,
    this.onActiveVideoPlaybackStarted,
  });

  final List<ReelMediaItem> items;

  /// Whether this post is the currently visible one in its parent feed.
  final bool isVisible;

  final Video360Metadata video360;

  /// Cover for inline post cards, contain for the full-screen reels feed.
  final BoxFit imageFit;

  final VoidCallback? onDoubleTap;

  /// Forwarded from the video on the active page only.
  final VoidCallback? onActiveVideoCompleted;
  final VoidCallback? onActiveVideoPlaybackStarted;

  @override
  State<PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends State<PostMediaCarousel> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const ColoredBox(color: Colors.black);
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: items.length,
          onPageChanged: (page) => setState(() => _page = page),
          itemBuilder: (context, i) => _buildItem(items[i], i),
        ),
        if (items.length > 1) ...[
          Positioned(
            top: 10,
            right: 10,
            child: IgnorePointer(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_page + 1}/${items.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: AppSpacing.sm,
            child: IgnorePointer(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  items.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 6 : 4.5,
                    height: i == _page ? 6 : 4.5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildItem(ReelMediaItem item, int index) {
    final isActive = index == _page;
    if (item.isVideo) {
      return ReelItemWidget(
        key: ValueKey<String>('carousel_video_${item.url}'),
        videoUrl: item.url,
        thumbnailUrl: item.thumbnailUrl,
        video360: widget.video360,
        isVisible: widget.isVisible && isActive,
        onVideoCompleted: isActive ? widget.onActiveVideoCompleted : null,
        onVideoPlaybackStarted:
            isActive ? widget.onActiveVideoPlaybackStarted : null,
        onDoubleTap: widget.onDoubleTap,
      );
    }
    return DoubleTapLikeOverlay(
      onDoubleTap: widget.onDoubleTap,
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: Image.network(
            item.url,
            fit: widget.imageFit,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white.withValues(alpha: 0.4),
                size: 40,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
