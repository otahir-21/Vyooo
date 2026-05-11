import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/reels_service.dart';
import '../../core/utils/user_facing_errors.dart';
import '../../core/subscription/subscription_controller.dart';
import '../../core/widgets/app_feed_header.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../screens/content/vr_detail_screen.dart';
import '../subscription/subscription_screen.dart';

Future<void> showVrLockedOverlaySheet(
  BuildContext context, {
  String? backgroundImageUrl,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      pageBuilder: (context, animation, secondaryAnimation) =>
          _VrLockedOverlayRoute(backgroundImageUrl: backgroundImageUrl),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.12),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

class _VrLockedOverlayRoute extends StatelessWidget {
  const _VrLockedOverlayRoute({this.backgroundImageUrl});

  final String? backgroundImageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (backgroundImageUrl != null &&
              backgroundImageUrl!.trim().isNotEmpty)
            Image.network(
              backgroundImageUrl!.trim(),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const _VrFallbackBackground(),
            )
          else
            const _VrFallbackBackground(),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: _VrLockedBottomPanel(),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 8,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _VrFallbackBackground extends StatelessWidget {
  const _VrFallbackBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF07111F), Color(0xFF0D2D4A), Color(0xFF1A0030)],
        ),
      ),
    );
  }
}

class _VrLockedBottomPanel extends StatelessWidget {
  const _VrLockedBottomPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 540),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Stream Your Way - Pay by the Minute!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Stream 360° content by the minute. No commitments, just click and enjoy!',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.75),
                height: 1.35,
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 38,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDE106B), Color(0xFF7A093B)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pay-per-minute coming soon'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Get started'),
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Divider(color: Colors.white.withValues(alpha: 0.25)),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'or',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(color: Colors.white.withValues(alpha: 0.25)),
                ),
              ],
            ),
            SizedBox(height: 16),
            const Text(
              'Become a Member to Watch',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Stream Exclusive Live streams, Immersive VR Content and many more',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.75),
                height: 1.35,
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 38,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const SubscriptionScreen(showRestoreButton: true),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('See Plans'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
        const Positioned.fill(child: _VrFallbackBackground()),
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
                  const Color(
                    0xFF2C0B24,
                  ).withValues(alpha: 0.95), // Deep magenta/purple
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
                                color: const Color(
                                  0xFFDE106B,
                                ).withValues(alpha: 0.3),
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
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Expanded(
                              child: Divider(color: Colors.white12),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                'or',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(color: Colors.white12),
                            ),
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
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
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
class VrGridView extends StatefulWidget {
  const VrGridView({super.key});

  @override
  State<VrGridView> createState() => _VrGridViewState();
}

class _VrGridViewState extends State<VrGridView> {
  late Future<List<Map<String, dynamic>>> _vrReelsFuture;

  @override
  void initState() {
    super.initState();
    _vrReelsFuture = ReelsService().getReelsVR(limit: 60);
  }

  void _refresh() {
    setState(() {
      _vrReelsFuture = ReelsService().getReelsVR(limit: 60);
    });
  }

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
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _vrReelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFDE106B)),
            );
          }

          if (snapshot.hasError) {
            return _VrGridMessage(
              icon: Icons.wifi_off_rounded,
              title: 'Could not load VR content',
              subtitle: messageForFirestore(snapshot.error),
              actionLabel: 'Retry',
              onAction: _refresh,
            );
          }

          final reels = snapshot.data ?? const <Map<String, dynamic>>[];
          if (reels.isEmpty) {
            return _VrGridMessage(
              icon: Icons.video_library_outlined,
              title: 'No VR videos yet',
              subtitle: 'VR content will appear here once creators publish it.',
              actionLabel: 'Refresh',
              onAction: _refresh,
            );
          }

          return GridView.builder(
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 1.5,
              mainAxisSpacing: 1.5,
              childAspectRatio: 1.0,
            ),
            itemCount: reels.length,
            itemBuilder: (context, index) {
              final reel = reels[index];
              final videoUrl = (reel['videoUrl'] as String? ?? '').trim();
              final thumbnailUrl = ((reel['thumbnailUrl'] as String?) ?? '').trim();
              final caption = (reel['caption'] as String? ?? '').trim();
              final username = (reel['username'] as String? ?? '').trim();
              final handle = (reel['handle'] as String? ?? '').trim();
              final avatarUrl = (reel['avatarUrl'] as String? ?? '').trim();
              final resolvedTitle = caption.isNotEmpty
                  ? caption
                  : (username.isNotEmpty ? username : 'VR');

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => VRDetailScreen(
                        payload: VRDetailPayload(
                          title: resolvedTitle,
                          videoUrl: videoUrl.isNotEmpty ? videoUrl : null,
                          thumbnailUrl: thumbnailUrl,
                          creatorName: username.isNotEmpty ? username : 'Creator',
                          creatorHandle: handle,
                          avatarUrl: avatarUrl,
                          description: caption,
                          likeCount: (reel['likes'] as int?) ?? 0,
                          commentCount: (reel['comments'] as int?) ?? 0,
                          viewCount: (reel['views'] as int?) ?? 0,
                          shareCount: (reel['shares'] as int?) ?? 0,
                          saveCount: (reel['saves'] as int?) ?? 0,
                        ),
                      ),
                    ),
                  );
                },
                child: thumbnailUrl.isNotEmpty
                    ? Image.network(
                        thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildThumbFallback(),
                      )
                    : _buildThumbFallback(),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildThumbFallback() {
    return Container(
      color: Colors.white12,
      child: const Icon(
        Icons.videocam_off,
        color: Colors.white38,
        size: 32,
      ),
    );
  }
}

class _VrGridMessage extends StatelessWidget {
  const _VrGridMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 32),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel,
                style: const TextStyle(
                  color: Color(0xFFDE106B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
