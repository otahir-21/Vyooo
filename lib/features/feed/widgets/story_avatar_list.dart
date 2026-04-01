import 'package:flutter/material.dart';

import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_padding.dart';
import '../../../../core/theme/app_spacing.dart';

/// Horizontal list of story avatars with pink gradient border ring.
/// Pass [myAvatarUrl] + [onAddStory] to show "Your Story" as the first item.
class StoryAvatarList extends StatelessWidget {
  const StoryAvatarList({
    super.key,
    required this.avatars,
    this.onAvatarTap,
    this.myAvatarUrl,
    this.myHasStory = false,
    this.onAddStory,
  });

  /// List of { 'id': String, 'url': String, 'name': String }
  final List<Map<String, String>> avatars;
  final void Function(String id)? onAvatarTap;

  /// Current user's avatar URL — shows "Your Story" as first item when set.
  final String? myAvatarUrl;

  /// True if the current user already has an active story (shows gradient ring).
  final bool myHasStory;

  /// Called when "Your Story" entry is tapped.
  final VoidCallback? onAddStory;

  static const double _size = 64;
  static const double _borderWidth = 3;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _size + _borderWidth * 2 + 28, // extra height for label
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppPadding.screenHorizontal.copyWith(
          top: AppSpacing.sm,
          bottom: AppSpacing.xs,
        ),
        itemCount: avatars.length + (onAddStory != null ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.storyItem),
        itemBuilder: (context, index) {
          // "Your Story" first slot
          if (onAddStory != null && index == 0) {
            return _MyStoryItem(
              size: _size,
              borderWidth: _borderWidth,
              avatarUrl: myAvatarUrl ?? '',
              hasStory: myHasStory,
              onTap: onAddStory!,
            );
          }
          final a = avatars[index - (onAddStory != null ? 1 : 0)];
          final id = a['id'] ?? '$index';
          final url = a['url'] ?? '';
          final name = a['name'] ?? '';
          return _StoryItem(
            size: _size,
            imageUrl: url,
            label: name,
            borderWidth: _borderWidth,
            onTap: () => onAvatarTap?.call(id),
          );
        },
      ),
    );
  }
}

// ── Your Story item ────────────────────────────────────────────────────────

class _MyStoryItem extends StatelessWidget {
  const _MyStoryItem({
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
        width: size + borderWidth * 2,
        child: Column(
          children: [
            Stack(
              children: [
                // Ring (gradient if has story, grey if not)
                Container(
                  width: size + borderWidth * 2,
                  height: size + borderWidth * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasStory ? AppGradients.storyRingGradient : null,
                    color: hasStory ? null : Colors.white24,
                  ),
                  padding: EdgeInsets.all(borderWidth),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: avatarUrl.isEmpty
                        ? Icon(Icons.person,
                            size: size * 0.5, color: Colors.white54)
                        : Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.person,
                              size: size * 0.5,
                              color: Colors.white54,
                            ),
                          ),
                  ),
                ),
                // + badge
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
}

// ── Other user story item ──────────────────────────────────────────────────

class _StoryItem extends StatelessWidget {
  const _StoryItem({
    required this.size,
    required this.imageUrl,
    required this.label,
    required this.borderWidth,
    required this.onTap,
  });

  final double size;
  final String imageUrl;
  final String label;
  final double borderWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size + borderWidth * 2,
        child: Column(
          children: [
            Container(
              width: size + borderWidth * 2,
              height: size + borderWidth * 2,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.storyRingGradient,
              ),
              padding: EdgeInsets.all(borderWidth),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl.isEmpty
                    ? Icon(Icons.person,
                        size: size * 0.5, color: Colors.white54)
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.person,
                          size: size * 0.5,
                          color: Colors.white54,
                        ),
                      ),
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
    );
  }
}
