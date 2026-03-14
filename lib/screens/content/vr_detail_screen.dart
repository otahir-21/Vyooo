import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_bottom_navigation.dart';

/// Payload for opening VR full-screen view (from profile VR grid or search).
class VRDetailPayload {
  const VRDetailPayload({
    this.title = 'VR',
    this.videoUrl,
    this.thumbnailUrl = 'https://picsum.photos/800/1600?random=vrfull',
    this.creatorName = 'Matt Rife',
    this.creatorHandle = '@mattrife_x',
    this.avatarUrl = 'https://i.pravatar.cc/80?img=33',
    this.description = 'It\'s the silence that is more beauti...',
    this.likeCount = 100000,
  });

  final String title;
  final String? videoUrl;
  final String thumbnailUrl;
  final String creatorName;
  final String creatorHandle;
  final String avatarUrl;
  final String description;
  final int likeCount;
}

/// Full-screen VR view: back + "VR", full-height media, VR badge, vertical actions (eye, heart, comment, share, save), creator overlay, description "See more".
class VRDetailScreen extends StatefulWidget {
  const VRDetailScreen({super.key, this.payload});

  final VRDetailPayload? payload;

  @override
  State<VRDetailScreen> createState() => _VRDetailScreenState();
}

class _VRDetailScreenState extends State<VRDetailScreen> {
  int _currentBottomNavIndex = 4;

  static String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payload ?? const VRDetailPayload();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(p.thumbnailUrl, fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.5),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.15, 0.5, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                const Spacer(),
                _buildBottomOverlay(p),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm, top: 56),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionIcon(Icons.visibility_outlined, null),
                    const SizedBox(height: AppSpacing.lg),
                    _buildActionIcon(
                      Icons.favorite_rounded,
                      _formatCount(p.likeCount),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _buildActionIcon(Icons.chat_bubble_outline_rounded, null),
                    const SizedBox(height: AppSpacing.lg),
                    _buildActionIcon(Icons.share_rounded, null),
                    const SizedBox(height: AppSpacing.lg),
                    _buildActionIcon(Icons.bookmark_border_rounded, null),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            right: AppSpacing.md,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'VR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: _currentBottomNavIndex,
        onTap: (index) {
          if (index == 4) return;
          setState(() => _currentBottomNavIndex = index);
        },
        profileImageUrl: widget.payload?.avatarUrl,
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Text(
            'VR',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, String? count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 28),
        if (count != null) ...[
          const SizedBox(height: 2),
          Text(
            count,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomOverlay(VRDetailPayload p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: NetworkImage(p.avatarUrl),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.creatorName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      p.creatorHandle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            p.description,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.35,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          GestureDetector(
            onTap: () {},
            child: Text(
              'See More',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
