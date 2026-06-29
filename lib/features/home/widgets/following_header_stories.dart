import 'package:flutter/material.dart';

import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';

/// Horizontal story row for Following tab. Circular avatars with gradient border.
/// Pass [myAvatarUrl] + [onAddStory] to prepend "Your Story" as the first item.
class FollowingHeaderStories extends StatelessWidget {
  const FollowingHeaderStories({
    super.key,
    required this.stories,
    this.selectedId,
    this.onStoryTap,
    this.myAvatarUrl,
    this.myHasStory = false,
    this.onAddStory,
  });

  final List<Map<String, dynamic>> stories;
  final String? selectedId;
  final void Function(String id)? onStoryTap;

  final String? myAvatarUrl;
  final bool myHasStory;
  final VoidCallback? onAddStory;

  @override
  Widget build(BuildContext context) {
    final showMine = onAddStory != null;
    final total = stories.length + (showMine ? 1 : 0);

    return SizedBox(
      height: AppSizes.followingStoryRowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs + 2,
          AppSpacing.md + AppSizes.followingStoriesToggleSize + AppSpacing.sm,
          AppSpacing.xs + 2,
        ),
        itemCount: total,
        separatorBuilder: (_, _) =>
            const SizedBox(width: AppSpacing.storyItem + 2),
        itemBuilder: (context, index) {
          if (showMine && index == 0) {
            return _MyStoryCircle(
              size: AppSizes.followingStoryAvatarSize,
              borderWidth: AppSizes.followingStoryBorderWidth,
              avatarUrl: myAvatarUrl ?? '',
              hasStory: myHasStory,
              onTap: onAddStory!,
            );
          }
          final story = stories[index - (showMine ? 1 : 0)];
          final id = story['id'] as String? ?? '$index';
          final imageUrl = story['profileImage'] as String? ??
              story['avatarUrl'] as String? ??
              '';
          final isSelected = selectedId == id;
          return _StoryCircle(
            size: AppSizes.followingStoryAvatarSize,
            imageUrl: imageUrl,
            isSelected: isSelected,
            borderWidth: AppSizes.followingStoryBorderWidth,
            onTap: () => onStoryTap?.call(id),
          );
        },
      ),
    );
  }
}

class _MyStoryCircle extends StatelessWidget {
  const _MyStoryCircle({
    required this.size,
    required this.borderWidth,
    required this.avatarUrl,
    required this.hasStory,
    required this.onTap,
  });

  final double size;
  final double borderWidth;
  final String avatarUrl;
  final bool hasStory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: hasStory ? AppGradients.storyRingGradient : null,
              color: hasStory ? null : Colors.white24,
            ),
            padding: EdgeInsets.all(borderWidth),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
                border: Border.all(color: Colors.black, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _placeholder(size),
                    )
                  : _placeholder(size),
            ),
          ),
          if (!hasStory)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppGradients.vrGetStartedButtonGradient,
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StoryCircle extends StatelessWidget {
  const _StoryCircle({
    required this.size,
    required this.imageUrl,
    required this.isSelected,
    required this.borderWidth,
    required this.onTap,
  });

  final double size;
  final String imageUrl;
  final bool isSelected;
  final double borderWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isSelected ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppGradients.storyRingGradient,
          ),
          padding: EdgeInsets.all(borderWidth),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
              border: Border.all(color: Colors.black, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _placeholder(size),
                  )
                : _placeholder(size),
          ),
        ),
      ),
    );
  }
}

Widget _placeholder(double size) => Icon(
      Icons.person_rounded,
      size: size * 0.45,
      color: Colors.white.withValues(alpha: 0.5),
    );
