import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/moderation/content_moderation.dart';
import '../../../core/services/moderation_service.dart';
import '../../../core/theme/app_spacing.dart';

/// Frosted-glass overlay shown when crowd reports cross the view-tier threshold.
class ReportModerationCover extends StatefulWidget {
  const ReportModerationCover({
    super.key,
    required this.contentId,
    required this.contentKind,
    required this.ownerId,
    required this.moderation,
    this.borderRadius = BorderRadius.zero,
  });

  final String contentId;
  final ModeratedContentKind contentKind;
  final String ownerId;
  final Map<String, dynamic>? moderation;
  final BorderRadius borderRadius;

  @override
  State<ReportModerationCover> createState() => _ReportModerationCoverState();
}

class _ReportModerationCoverState extends State<ReportModerationCover> {
  bool _submitting = false;

  bool get _pending =>
      ContentModeration.hasPendingDispute(widget.moderation);

  Future<void> _dispute() async {
    if (_submitting || _pending) return;
    setState(() => _submitting = true);
    final result = await ModerationService().submitDispute(
      contentId: widget.contentId,
      contentKind: widget.contentKind,
      ownerId: widget.ownerId,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    final messenger = ScaffoldMessenger.maybeOf(context);
    switch (result) {
      case ModerationDisputeResult.success:
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Dispute submitted. Our team will review it.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case ModerationDisputeResult.alreadyPending:
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('A dispute is already under review.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case ModerationDisputeResult.notOwner:
      case ModerationDisputeResult.failed:
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Could not submit dispute. Try again later.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              color: Colors.black.withValues(alpha: 0.45),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility_off_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 40,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    ContentModeration.coverMessage(widget.contentKind),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  if (_pending) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Your dispute is under review.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                  if (ModerationService.isCurrentUserOwner(widget.ownerId) &&
                      !_pending) ...[
                    const SizedBox(height: AppSpacing.lg),
                    TextButton(
                      onPressed: _submitting ? null : _dispute,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Dispute this decision',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps [child] with [ReportModerationCover] when moderation requires it.
class ModeratedContentWrapper extends StatelessWidget {
  const ModeratedContentWrapper({
    super.key,
    required this.contentId,
    required this.contentKind,
    required this.ownerId,
    required this.moderation,
    required this.child,
    this.borderRadius = BorderRadius.zero,
  });

  final String contentId;
  final ModeratedContentKind contentKind;
  final String ownerId;
  final Map<String, dynamic>? moderation;
  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    if (!ContentModeration.isReportCovered(moderation)) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        ReportModerationCover(
          contentId: contentId,
          contentKind: contentKind,
          ownerId: ownerId,
          moderation: moderation,
          borderRadius: borderRadius,
        ),
      ],
    );
  }
}
