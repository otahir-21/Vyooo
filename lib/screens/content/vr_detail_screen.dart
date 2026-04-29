import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Payload for opening VR full-screen view (from profile VR grid or search).
class VRDetailPayload {
  const VRDetailPayload({
    this.title = 'VR',
    this.videoUrl,
    this.thumbnailUrl = '',
    this.creatorName = 'Creator',
    this.creatorHandle = '',
    this.avatarUrl = '',
    this.description = '',
    this.likeCount = 0,
    this.commentCount = 0,
    this.viewCount = 0,
    this.shareCount = 0,
    this.saveCount = 0,
  });

  final String title;
  final String? videoUrl;
  final String thumbnailUrl;
  final String creatorName;
  final String creatorHandle;
  final String avatarUrl;
  final String description;
  final int likeCount;
  final int commentCount;
  final int viewCount;
  final int shareCount;
  final int saveCount;
}

/// Full-screen VR view: back + "VR", full-height media, VR badge, vertical actions (eye, heart, comment, share, save), creator overlay, description "See more".
class VRDetailScreen extends StatefulWidget {
  const VRDetailScreen({super.key, this.payload});

  final VRDetailPayload? payload;

  @override
  State<VRDetailScreen> createState() => _VRDetailScreenState();
}

class _VRDetailScreenState extends State<VRDetailScreen> {
  bool _showOverlay = false;
  bool _showInstruction = true;

  @override
  void initState() {
    super.initState();
    // Auto-hide instruction after delay
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showInstruction = false);
    });
  }

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  Widget _buildInstructionOverlay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
      ),
      child: const Text(
        'Move device to explore video',
        style: TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMediaFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A1A), Color(0xFF050505)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.vrpano_outlined, color: Colors.white38, size: 56),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payload ?? const VRDetailPayload();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Media
          GestureDetector(
            onTap: () {
              setState(() => _showOverlay = !_showOverlay);
              if (_showOverlay) {
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted) setState(() => _showOverlay = false);
                });
              }
            },
            child: p.thumbnailUrl.trim().isNotEmpty
                ? Image.network(
                    p.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildMediaFallback(),
                  )
                : _buildMediaFallback(),
          ),
          // Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.4),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.6),
                ],
                stops: const [0.0, 0.15, 0.5, 1.0],
              ),
            ),
          ),
          // Sidebar Actions (Always visible or toggleable?) - Matching Design 1
          Positioned(
            right: 12,
            bottom: 120, // Above user info/nav
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionIcon(Icons.visibility_outlined, _formatCount(p.viewCount)),
                  const SizedBox(height: 20),
                  _buildActionIcon(Icons.favorite_border, _formatCount(p.likeCount)),
                  const SizedBox(height: 20),
                  _buildActionIcon(Icons.chat_bubble_outline, _formatCount(p.commentCount)),
                  const SizedBox(height: 20),
                  _buildActionIcon(Icons.star_border, _formatCount(p.saveCount)),
                  const SizedBox(height: 20),
                  _buildActionIcon(Icons.reply, _formatCount(p.shareCount)), // Share icon
                  const SizedBox(height: 20),
                  _buildActionIcon(Icons.more_horiz, null),
                ],
              ),
            ),
          ),
          // Bottom Visibility Toggle Icon (Right Corner)
          Positioned(
            right: 20,
            bottom: 40,
            child: Icon(
              Icons.visibility_off_outlined,
              size: 28,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          // Bottom Info Row
          Positioned(
            left: 0,
            right: 80,
            bottom: 20,
            child: SafeArea(
              child: _buildBottomOverlay(p),
            ),
          ),
          // Top VR Badge
          Positioned(
            top: MediaQuery.of(context).padding.top + 64,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
              ),
              child: const Text(
                'VR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          // Instructional Overlay
          if (_showInstruction)
            Center(
              child: _buildInstructionOverlay(),
            ),
          // AppBar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: _buildAppBar(context)),
          ),
          // Bottom Progress Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 3,
              width: double.infinity,
              color: Colors.black.withValues(alpha: 0.3),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 3,
                  width: MediaQuery.sizeOf(context).width * 0.4, // Mock 40% progress
                  color: const Color(0xFFEF4444),
                ),
              ),
            ),
          ),
        ],
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
          const SizedBox(height: 4),
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomOverlay(VRDetailPayload p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[900],
                  backgroundImage: NetworkImage(p.avatarUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          p.creatorName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 10),
                        ),
                      ],
                    ),
                    Text(
                      p.creatorHandle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            p.description,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {},
            child: Text(
              'See More',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
