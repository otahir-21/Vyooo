import 'package:flutter/material.dart';

import '../theme/app_gradients.dart';

/// Gradient ring for avatars when a user is broadcasting live (not stories).
class LiveAvatarRing extends StatelessWidget {
  const LiveAvatarRing({
    super.key,
    required this.size,
    required this.child,
    this.borderWidth = 3,
    this.showLivePill = false,
  });

  final double size;
  final Widget child;
  final double borderWidth;
  final bool showLivePill;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.liveRingGradient,
            ),
            padding: EdgeInsets.all(borderWidth),
            child: ClipOval(child: child),
          ),
          if (showLivePill)
            Positioned(
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
