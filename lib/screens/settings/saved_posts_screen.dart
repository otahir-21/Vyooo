import 'package:flutter/material.dart';

import '../../core/controllers/reels_controller.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../content/post_feed_screen.dart';

/// Only the signed-in user can open this screen; data comes from [privateSavedReels].
class SavedPostsScreen extends StatelessWidget {
  const SavedPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        type: GradientType.premiumDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAppBar(context),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: ReelsController().fetchPrivateSavedReelsForCurrentUser(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Could not load saved posts.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 15,
                          ),
                        ),
                      ),
                    );
                  }
                  final posts = snapshot.data ?? <Map<String, dynamic>>[];
                  if (posts.isEmpty) {
                    return Center(
                      child: Text(
                        'No private saves yet.\nUse ⋯ → Save privately on a reel.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      childAspectRatio: 1,
                    ),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final reel = posts[index];
                      final thumb = _thumb(reel);
                      final mediaType =
                          ((reel['mediaType'] as String?) ?? '').toLowerCase();
                      final isVideo = mediaType != 'image';
                      return GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PostFeedScreen(
                              payload: PostFeedPayload(
                                posts: posts,
                                initialIndex: index,
                                creatorName: 'Saved',
                                creatorHandle: '@saved',
                                avatarUrl: '',
                                isVerified: false,
                                screenTitle: 'Saved posts',
                              ),
                            ),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(color: Colors.grey[900]),
                              if (thumb.isNotEmpty)
                                Image.network(
                                  thumb,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const SizedBox.shrink(),
                                ),
                              if (isVideo)
                                const Align(
                                  alignment: Alignment.bottomRight,
                                  child: Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white70,
                                      size: 18,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _thumb(Map<String, dynamic> reel) {
    final imageUrl = (reel['imageUrl'] as String?)?.trim() ?? '';
    if (imageUrl.isNotEmpty) return imageUrl;
    final explicitThumb = (reel['thumbnailUrl'] as String?)?.trim() ?? '';
    if (explicitThumb.isNotEmpty) return explicitThumb;
    final videoUrl = (reel['videoUrl'] as String?)?.trim() ?? '';
    if (videoUrl.isEmpty) return '';
    try {
      final uri = Uri.parse(videoUrl);
      final videoId =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      if (videoId.isEmpty) return '';
      return 'https://videodelivery.net/$videoId/thumbnails/thumbnail.jpg';
    } catch (_) {
      return '';
    }
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
          ),
          const Expanded(
            child: Text(
              'Saved posts (private)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
