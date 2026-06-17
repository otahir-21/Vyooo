import 'package:flutter/material.dart';
import 'package:vyooo/core/theme/app_gradients.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_gradient_background.dart';

/// Shown after content is successfully posted to Firestore.
class UploadSuccessScreen extends StatelessWidget {
  const UploadSuccessScreen({
    super.key,
    this.title = 'Video Posted!',
    this.subtitle = 'Your video is live and visible to everyone.',
    this.primaryButtonLabel = 'Go to Feed',
    this.dismissToRoot = true,
  });

  final String title;
  final String subtitle;
  final String primaryButtonLabel;
  /// When true, clears the upload stack back to the main nav. When false, pops once
  /// with `true` so callers (e.g. home story "+") can refresh and stay on feed.
  final bool dismissToRoot;

  /// Success copy for feed posts from carousel [mediaItems] (`type`: `image` | `video`).
  factory UploadSuccessScreen.forMediaPost({
    required List<Map<String, dynamic>> mediaItems,
    bool dismissToRoot = true,
  }) {
    final hasImage =
        mediaItems.any((item) => item['type'] == 'image');
    final hasVideo =
        mediaItems.any((item) => item['type'] == 'video');

    final String title;
    final String subtitle;
    if (hasImage && hasVideo) {
      title = 'Posted Successfully!';
      subtitle = 'Your post is live and visible to everyone.';
    } else if (hasVideo) {
      title = 'Video Posted!';
      subtitle = 'Your video is live and visible to everyone.';
    } else {
      title = 'Images Posted!';
      subtitle = 'Your images are live and visible to everyone.';
    }

    return UploadSuccessScreen(
      title: title,
      subtitle: subtitle,
      dismissToRoot: dismissToRoot,
    );
  }

  void _finish(BuildContext context) {
    if (dismissToRoot) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.premiumDark,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: AppGradients.premiumDarkGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDE106B).withValues(alpha: 0.4),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Material(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: InkWell(
                      onTap: () => _finish(context),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFDE106B), Color(0xFFF81945)],
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 14,
                          ),
                          child: Text(
                            primaryButtonLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () => _finish(context),
                    child: Text(
                      'Back to home',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
