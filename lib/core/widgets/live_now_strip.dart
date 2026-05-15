import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_spacing.dart';
import 'live_avatar_ring.dart';

/// Horizontal row of live hosts (under search / discover headers).
class LiveNowStripItem {
  const LiveNowStripItem({
    required this.avatarUrl,
    required this.username,
    required this.onTap,
  });

  final String avatarUrl;
  final String username;
  final VoidCallback onTap;
}

class LiveNowStrip extends StatelessWidget {
  const LiveNowStrip({
    super.key,
    required this.items,
    this.title = 'Live now',
  });

  final List<LiveNowStripItem> items;
  final String title;

  static const double _avatarSize = 64;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF3B30),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = items[index];
              return GestureDetector(
                onTap: item.onTap,
                child: SizedBox(
                  width: _avatarSize,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LiveAvatarRing(
                        size: _avatarSize,
                        showLivePill: true,
                        child: _avatarImage(item.avatarUrl),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _avatarImage(String url) {
    final valid = Uri.tryParse(url)?.isAbsolute == true;
    if (!valid) {
      return ColoredBox(
        color: Colors.white.withValues(alpha: 0.08),
        child: Icon(
          Icons.person_rounded,
          color: Colors.white.withValues(alpha: 0.45),
          size: 28,
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => ColoredBox(
        color: Colors.white.withValues(alpha: 0.08),
        child: Icon(
          Icons.person_rounded,
          color: Colors.white.withValues(alpha: 0.45),
          size: 28,
        ),
      ),
    );
  }
}

/// Compact banner on a profile when the user is live.
class ProfileLiveJoinBanner extends StatelessWidget {
  const ProfileLiveJoinBanner({
    super.key,
    required this.streamTitle,
    required this.viewerCount,
    required this.thumbnailUrl,
    required this.onJoinTap,
  });

  final String streamTitle;
  final int viewerCount;
  final String thumbnailUrl;
  final VoidCallback onJoinTap;

  static String formatViewerCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final title = streamTitle.trim().isEmpty ? 'Live stream' : streamTitle.trim();
    final validThumb = Uri.tryParse(thumbnailUrl)?.isAbsolute == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Material(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onJoinTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: validThumb
                        ? Image.network(
                            thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _thumbFallback(),
                          )
                        : _thumbFallback(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3B30),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.visibility_outlined,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formatViewerCount(viewerCount),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandMagenta,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onJoinTap,
                  child: const Text(
                    'Join',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbFallback() {
    return ColoredBox(
      color: const Color(0xFF26172A),
      child: Icon(
        Icons.sensors_rounded,
        color: Colors.white.withValues(alpha: 0.4),
        size: 32,
      ),
    );
  }
}
