import 'package:flutter/material.dart';
import '../../../../core/theme/app_gradients.dart';

/// Horizontal story row for Following tab. Circular avatars with gradient border + username label.
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

  static const double _itemSize = 68;
  static const double _borderWidth = 3;

  @override
  Widget build(BuildContext context) {
    final showMine = onAddStory != null;
    final total = stories.length + (showMine ? 1 : 0);

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: total,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          if (showMine && index == 0) {
            return _MyStoryCircle(
              size: _itemSize,
              borderWidth: _borderWidth,
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
          final name = story['username'] as String? ?? '';
          final isSelected = selectedId == id;
          return _StoryCircle(
            size: _itemSize,
            imageUrl: imageUrl,
            label: name,
            isSelected: isSelected,
            borderWidth: _borderWidth,
            onTap: () => onStoryTap?.call(id),
          );
        },
      ),
    );
  }
}

// ── Your Story ─────────────────────────────────────────────────────────────

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
      child: SizedBox(
        width: size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient:
                        hasStory ? AppGradients.storyRingGradient : null,
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
                            errorBuilder: (_, _, _) => _placeholder(),
                          )
                        : _placeholder(),
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
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFDE106B), Color(0xFFF81945)],
                        ),
                      ),
                      child: const Icon(Icons.add,
                          color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Your Story',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Icon(
        Icons.person_rounded,
        size: size * 0.45,
        color: Colors.white.withValues(alpha: 0.5),
      );
}

// ── Other user story circle ────────────────────────────────────────────────

class _StoryCircle extends StatelessWidget {
  const _StoryCircle({
    required this.size,
    required this.imageUrl,
    required this.label,
    required this.isSelected,
    required this.borderWidth,
    required this.onTap,
  });

  final double size;
  final String imageUrl;
  final String label;
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
        child: SizedBox(
          width: size,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
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
                          errorBuilder: (_, _, _) => _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Icon(
        Icons.person_rounded,
        size: size * 0.45,
        color: Colors.white.withValues(alpha: 0.5),
      );
}
