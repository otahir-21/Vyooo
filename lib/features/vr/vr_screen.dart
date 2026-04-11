import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/subscription/subscription_controller.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_feed_header.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../screens/content/vr_detail_screen.dart';
import '../subscription/subscription_screen.dart';
import 'vr_player_screen.dart';

/// VR feature screen. Subscription-gated: Standard → locked, Subscriber/Creator → grid.
class VrScreen extends StatelessWidget {
  const VrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        type: GradientType.feed,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppFeedHeader(selectedIndex: 1),
            Expanded(
              child: Consumer<SubscriptionController>(
                builder: (context, subscriptionController, _) {
                  if (!subscriptionController.hasVRAccess) {
                    return const VrLockedView();
                  }
                  return const VrGridView();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// VR paywall content. Reused in home screen when VR tab is selected.
class VrLockedView extends StatelessWidget {
  const VrLockedView({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final cardHeight = screenHeight * 0.45;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Underwater-style background image
        Positioned.fill(
          child: Image.network(
            'https://images.unsplash.com/photo-1544923246-77307dd654ca?q=80&w=2000&auto=format&fit=crop', // A placeholder that looks like a cave/underwater
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF0A1628),
            ),
          ),
        ),
        // Dark overlay for better contrast
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.2),
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: cardHeight,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF2C0B24).withValues(alpha: 0.95), // Deep magenta/purple
                  const Color(0xFF0F040C).withValues(alpha: 1.0),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(40),
              ),
              border: Border.all(color: Colors.white10, width: 1),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Grey Handle Bar
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Stream Your Way – Pay by the Minute!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Stream 360° content by the minute. No commitments,\njust click and enjoy!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.7),
                            height: 1.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Get Started Button with Red/Pink Gradient
                        Container(
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFDE106B), Color(0xFF7A093B)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFDE106B).withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            child: const Text(
                              'Get started',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Expanded(child: Divider(color: Colors.white12)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'or',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                            const Expanded(child: Divider(color: Colors.white12)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Become a Member to Watch',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Stream Exclusive Live streams, Immersive VR Content,\nMonetize Content and many more',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.7),
                            height: 1.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // See Plans Button with Gold Gradient
                        Container(
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFCCAC4C), Color(0xFF826E31)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const SubscriptionScreen(
                                    showRestoreButton: true,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            child: const Text(
                              'See Plans',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// VR grid of thumbnails. Reused in home screen when VR tab is selected.
class VrGridView extends StatelessWidget {
  const VrGridView({super.key});

  static const _thumbnailUrls = [
    'https://picsum.photos/400/400?random=11',
    'https://picsum.photos/400/400?random=12',
    'https://picsum.photos/400/400?random=13',
    'https://picsum.photos/400/400?random=14',
    'https://picsum.photos/400/400?random=15',
    'https://picsum.photos/400/400?random=16',
    'https://picsum.photos/400/400?random=17',
    'https://picsum.photos/400/400?random=18',
    'https://picsum.photos/400/400?random=19',
    'https://picsum.photos/400/400?random=20',
    'https://picsum.photos/400/400?random=21',
    'https://picsum.photos/400/400?random=22',
    'https://picsum.photos/400/400?random=23',
    'https://picsum.photos/400/400?random=24',
    'https://picsum.photos/400/400?random=25',
  ];

  static final _testVideoUrls = [
    ...VrPlayerScreen.testVideoUrls,
    ...VrPlayerScreen.testVideoUrls,
    ...VrPlayerScreen.testVideoUrls,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF5A1245), // Dark magenta/purple
            Colors.black,
          ],
          stops: [0.0, 0.4],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 1.5,
          mainAxisSpacing: 1.5,
          childAspectRatio: 1.0,
        ),
        itemCount: _thumbnailUrls.length,
        itemBuilder: (context, index) {
          final videoUrl = _testVideoUrls[index % _testVideoUrls.length];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => VRDetailScreen(
                    payload: VRDetailPayload(
                      title: 'VR ${index + 1}',
                      videoUrl: videoUrl,
                      thumbnailUrl: _thumbnailUrls[index],
                      likeCount: 100000,
                    ),
                  ),
                ),
              );
            },
            child: Image.network(
              _thumbnailUrls[index],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.white12,
                child: const Icon(
                  Icons.videocam_off,
                  color: Colors.white38,
                  size: 32,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
