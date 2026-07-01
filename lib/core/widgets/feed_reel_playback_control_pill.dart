import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/app_colors.dart';
import '../constants/feed_interaction_assets.dart';
import '../theme/app_radius.dart';
import '../theme/app_sizes.dart';

/// Figma home reel playback pill — frosted 114×50 capsule with pause/play and
/// speaker controls separated by a vertical divider.
class FeedReelPlaybackControlPill extends StatelessWidget {
  const FeedReelPlaybackControlPill({
    super.key,
    required this.isPlaying,
    required this.isMuted,
    required this.onPlayPause,
    this.onMute,
    this.showMute = true,
  });

  final bool isPlaying;
  final bool isMuted;
  final VoidCallback onPlayPause;
  final VoidCallback? onMute;
  final bool showMute;

  static final BorderRadius _radius = AppRadius.feedReelPlaybackControlPillRadius;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: ClipRRect(
        borderRadius: _radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppSizes.feedReelPlaybackControlBlurSigma,
            sigmaY: AppSizes.feedReelPlaybackControlBlurSigma,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.feedReelPlaybackControlFill,
              borderRadius: _radius,
            ),
            child: SizedBox(
              width: showMute
                  ? AppSizes.feedReelPlaybackControlPillWidth
                  : AppSizes.feedReelPlaybackControlPillWidth / 2,
              height: AppSizes.feedReelPlaybackControlPillHeight,
              child: showMute
                  ? Row(
                      children: [
                        Expanded(child: _buildPlayPauseSlot()),
                        _buildDivider(),
                        Expanded(child: _buildMuteSlot()),
                      ],
                    )
                  : Center(child: _buildPlayPauseSlot()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return SvgPicture.asset(
      FeedInteractionAssets.playbackDivider,
      width: AppSizes.feedReelPlaybackControlDividerWidth,
      height: AppSizes.feedReelPlaybackControlDividerHeight,
      fit: BoxFit.contain,
    );
  }

  Widget _buildPlayPauseSlot() {
    final asset = isPlaying
        ? FeedInteractionAssets.playbackPause
        : FeedInteractionAssets.playbackPlay;
    final width = isPlaying
        ? AppSizes.feedReelPlaybackControlIconSize
        : AppSizes.feedReelPlaybackControlPlayIconWidth;
    final height = AppSizes.feedReelPlaybackControlIconSize;

    return _PillTapSlot(
      onTap: onPlayPause,
      child: SvgPicture.asset(
        asset,
        width: width,
        height: height,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildMuteSlot() {
    final asset = isMuted
        ? FeedInteractionAssets.playbackSpeakerMuted
        : FeedInteractionAssets.playbackSpeaker;
    return _PillTapSlot(
      onTap: onMute,
      child: SvgPicture.asset(
        asset,
        width: AppSizes.feedReelPlaybackControlIconSize,
        height: AppSizes.feedReelPlaybackControlIconSize,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _PillTapSlot extends StatelessWidget {
  const _PillTapSlot({
    required this.onTap,
    required this.child,
  });

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.feedReelPlaybackControlPillRadius,
        child: SizedBox(
          height: AppSizes.feedReelPlaybackControlPillHeight,
          child: Center(child: child),
        ),
      ),
    );
  }
}
