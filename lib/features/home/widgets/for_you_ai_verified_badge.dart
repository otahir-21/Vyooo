import 'package:flutter/material.dart';

import '../../../core/constants/feed_interaction_assets.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// For You feed — AI fact-check icon + tooltip (Figma).
class ForYouAiVerifiedBadge extends StatelessWidget {
  const ForYouAiVerifiedBadge({
    super.key,
    required this.showTooltip,
    required this.onIconTap,
  });

  final bool showTooltip;
  final VoidCallback onIconTap;

  static const String _message =
      'This content has been verified by our AI for '
      'factual accuracy and trustworthy information.';

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTooltip) ...[
          const _AiVerifiedTooltipCard(message: _message),
          const SizedBox(width: AppSpacing.sm),
        ],
        GestureDetector(
          onTap: onIconTap,
          behavior: HitTestBehavior.opaque,
          child: Image.asset(
            FeedInteractionAssets.factCheck,
            width: 36,
            height: 36,
            fit: BoxFit.contain,
            errorBuilder: (_, error, stackTrace) => const Icon(
              Icons.verified_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }
}

class _AiVerifiedTooltipCard extends StatelessWidget {
  const _AiVerifiedTooltipCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5A1A45), Color(0xFF2D0B22)],
        ),
        borderRadius: AppRadius.inputRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTypography.feedReelHandle.copyWith(
          color: Colors.white,
          height: 1.35,
        ),
      ),
    );
  }
}
