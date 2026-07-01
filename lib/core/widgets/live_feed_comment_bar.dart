import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/app_colors.dart';
import '../constants/live_stream_assets.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'live_comment_input_field.dart';

/// Live feed bottom row — comment field expands; then chevron, like, share.
class LiveFeedCommentBar extends StatelessWidget {
  const LiveFeedCommentBar({
    super.key,
    required this.controller,
    required this.likeCount,
    required this.isLiked,
    required this.onSendMessage,
    required this.onLike,
    required this.onShare,
    this.onChevronTap,
    this.hostCaptionVisible = true,
    this.enabled = true,
  });

  final TextEditingController controller;
  final int likeCount;
  final bool isLiked;
  final VoidCallback onSendMessage;
  final VoidCallback onLike;
  final VoidCallback onShare;
  final VoidCallback? onChevronTap;

  /// When true, chevron points down (caption shown). When false, rotated up.
  final bool hostCaptionVisible;
  final bool enabled;

  static String formatLikeCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = AppSizes.liveFeedScaleW(
      context,
      AppSizes.liveFeedChevronSize,
    );
    final rowHeight = AppSizes.liveFeedScaleH(
      context,
      AppSizes.liveFeedActionRowHeight,
    );
    final commentToChevron = AppSizes.liveFeedScaleW(
      context,
      AppSizes.liveFeedCommentToChevronGap,
    );
    final chevronToLike = AppSizes.liveFeedScaleW(
      context,
      AppSizes.liveFeedChevronToLikeGap,
    );
    final likeToShare = AppSizes.liveFeedScaleW(
      context,
      AppSizes.liveFeedLikeToShareGap,
    );
    final heartToCount = AppSizes.liveFeedScaleW(context, AppSpacing.xs);

    return LayoutBuilder(
      builder: (context, constraints) {
        final rowWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : double.infinity;

        return SizedBox(
          height: rowHeight,
          width: rowWidth,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: LiveCommentInputField(
                  controller: controller,
                  enabled: enabled,
                  onSubmitted: (_) => onSendMessage(),
                ),
              ),
              SizedBox(width: commentToChevron),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: onChevronTap,
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedRotation(
                      turns: hostCaptionVisible ? 0 : 0.5,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: SvgPicture.asset(
                        LiveStreamAssets.feedChevron,
                        width: iconSize,
                        height: iconSize,
                      ),
                    ),
                  ),
                  SizedBox(width: chevronToLike),
                  GestureDetector(
                    onTap: onLike,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked
                              ? AppColors.feedLikeActive
                              : Colors.white,
                          size: iconSize,
                        ),
                        SizedBox(width: heartToCount),
                        Text(
                          formatLikeCount(likeCount),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.liveFeedLikeCount,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: likeToShare),
                  GestureDetector(
                    onTap: onShare,
                    behavior: HitTestBehavior.opaque,
                    child: SvgPicture.asset(
                      LiveStreamAssets.feedShare,
                      width: AppSizes.liveFeedScaleW(
                        context,
                        AppSizes.liveFeedShareIconSize,
                      ),
                      height: AppSizes.liveFeedScaleW(
                        context,
                        AppSizes.liveFeedShareIconSize,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
