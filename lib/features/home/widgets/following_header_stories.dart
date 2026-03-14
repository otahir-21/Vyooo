import 'package:flutter/material.dart';
import '../../../../core/theme/app_gradients.dart';

/// Horizontal story row for Following tab. Circular avatars with thick gradient border.
class FollowingHeaderStories extends StatelessWidget {
  const FollowingHeaderStories({
    super.key,
    required this.stories,
    this.selectedId,
    this.onStoryTap,
  });

  final List<Map<String, dynamic>> stories;
  final String? selectedId;
  final void Function(String id)? onStoryTap;

  static const double _itemSize = 72;
  static const double _borderWidth = 3;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final story = stories[index];
          final id = story['id'] as String? ?? '$index';
          final imageUrl = story['profileImage'] as String? ??
              story['avatarUrl'] as String? ??
              '';
          final isSelected = selectedId == id;
          return _StoryCircle(
            size: _itemSize,
            imageUrl: imageUrl,
            isSelected: isSelected,
            borderWidth: _borderWidth,
            onTap: () => onStoryTap?.call(id),
          );
        },
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
            child: (imageUrl.isNotEmpty)
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholderIcon(),
                  )
                : _placeholderIcon(),
          ),
        ),
      ),
    );
  }

  Widget _placeholderIcon() {
    return Icon(
      Icons.person_rounded,
      size: size * 0.5,
      color: Colors.white.withOpacity(0.5),
    );
  }
}
