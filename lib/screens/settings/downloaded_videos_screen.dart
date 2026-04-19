import 'package:flutter/material.dart';
import '../../core/widgets/app_gradient_background.dart';

class DownloadedVideosScreen extends StatelessWidget {
  const DownloadedVideosScreen({super.key});

  static const List<Map<String, String>> _videos = [
    {
      'imageUrl': 'https://images.unsplash.com/photo-1514525253361-bee8d4874402?w=500&q=80',
      'username': 'Sydneyshal',
      'description': 'Exploring North Bali, Indo...',
      'isVerified': 'false',
    },
    {
      'imageUrl': 'https://images.unsplash.com/photo-1533105079780-92b9be482077?w=500&q=80',
      'username': 'martixgarret',
      'description': 'Exploring North Bali, Indo...',
      'isVerified': 'true',
    },
    {
      'imageUrl': 'https://images.unsplash.com/photo-1514525253361-bee8d4874402?w=500&q=80',
      'username': 'Sydneyshal',
      'description': 'Exploring North Bali, Indo...',
      'isVerified': 'false',
    },
    {
      'imageUrl': 'https://images.unsplash.com/photo-1533105079780-92b9be482077?w=500&q=80',
      'username': 'martixgarret',
      'description': 'Exploring North Bali, Indo...',
      'isVerified': 'true',
    },
    {
      'imageUrl': 'https://images.unsplash.com/photo-1533105079780-92b9be482077?w=500&q=80',
      'username': 'martixgarret',
      'description': 'Exploring North Bali, Indo...',
      'isVerified': 'true',
    },
    {
      'imageUrl': 'https://images.unsplash.com/photo-1514525253361-bee8d4874402?w=500&q=80',
      'username': 'Sydneyshal',
      'description': 'Exploring North Bali, Indo...',
      'isVerified': 'false',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              _buildAppBar(context),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 24,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: _videos.length,
                  itemBuilder: (context, index) {
                    final video = _videos[index];
                    return _VideoCard(
                      imageUrl: video['imageUrl']!,
                      username: video['username']!,
                      description: video['description']!,
                      isVerified: video['isVerified'] == 'true',
                      showPlayOverlay: index == 1,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                SizedBox(width: 16),
                Text(
                  'Downloaded',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'VyooO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({
    required this.imageUrl,
    required this.username,
    required this.description,
    this.isVerified = false,
    this.showPlayOverlay = false,
  });

  final String imageUrl;
  final String username;
  final String description;
  final bool isVerified;
  final bool showPlayOverlay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Play Overlay
              if (showPlayOverlay)
                Center(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              // Username overlay info
              Positioned(
                left: 12,
                bottom: 12,
                child: Row(
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, color: Color(0xFFF81945), size: 14),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
