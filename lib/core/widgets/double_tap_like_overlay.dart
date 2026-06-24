import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Instagram-style heart burst shown at the double-tap location.
///
/// Wrap post/reel media and pass [onDoubleTap] to trigger the like action.
/// The heart animation always plays on double-tap; [onDoubleTap] decides
/// whether to persist a new like (e.g. skip when already liked).
class DoubleTapLikeOverlay extends StatefulWidget {
  const DoubleTapLikeOverlay({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  @override
  State<DoubleTapLikeOverlay> createState() => _DoubleTapLikeOverlayState();
}

class _HeartBurst {
  _HeartBurst({required this.position, required this.controller});

  final Offset position;
  final AnimationController controller;
}

class _DoubleTapLikeOverlayState extends State<DoubleTapLikeOverlay>
    with TickerProviderStateMixin {
  static const Color _likeColor = AppColors.feedLikeActive;
  static const double _heartSize = 72;

  final List<_HeartBurst> _bursts = <_HeartBurst>[];

  @override
  void dispose() {
    for (final burst in _bursts) {
      burst.controller.dispose();
    }
    super.dispose();
  }

  void _spawnHeart(Offset localPosition) {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    final burst = _HeartBurst(position: localPosition, controller: controller);
    setState(() => _bursts.add(burst));
    controller.forward().whenComplete(() {
      if (!mounted) return;
      setState(() => _bursts.remove(burst));
      controller.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (details) => _spawnHeart(details.localPosition),
      onDoubleTap: widget.onDoubleTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          widget.child,
          for (final burst in _bursts)
            AnimatedBuilder(
              animation: burst.controller,
              builder: (context, _) {
                final t = Curves.easeOut.transform(burst.controller.value);
                final scale = 0.75 + (t * 0.55);
                final opacity = t < 0.45 ? 1.0 : 1.0 - ((t - 0.45) / 0.55);
                return Positioned(
                  left: burst.position.dx - (_heartSize / 2),
                  top: burst.position.dy - (_heartSize / 2),
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: scale,
                        child: Icon(
                          Icons.favorite_rounded,
                          color: _likeColor,
                          size: _heartSize,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
