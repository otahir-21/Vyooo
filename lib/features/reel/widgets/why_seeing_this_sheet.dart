import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// "Why you're seeing this post?" bottom sheet: title, body with Learn More link,
/// then reasons with icons (e.g. You follow X, You've interacted with content about...).
void showWhySeeingThisSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _WhySeeingThisSheet(),
  );
}

abstract final class _Layout {
  static const double dragHandleWidth = 36;
  static const double dragHandleHeight = 4;
  static const double reasonIconSize = 40;
}

class _WhySeeingThisSheet extends StatelessWidget {
  const _WhySeeingThisSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF49113B), // Deep Magenta
            Color(0xFF210D1D), 
            Color(0xFF0F040C),
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.storyItem, bottom: AppSpacing.sm),
                  child: Center(
                    child: Container(
                      width: _Layout.dragHandleWidth,
                      height: _Layout.dragHandleHeight,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const Text(
                  "Why you're seeing this post?",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                    children: [
                      const TextSpan(
                        text:
                            'Posts are shown in feed based on many things, including your activity in VyooO. ',
                      ),
                      TextSpan(
                        text: 'Learn More',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            // TODO: open learn more URL or in-app page
                          },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _ReasonRow(
                  icon: Icons.person_outline_rounded,
                  label: "You follow Robert Thank",
                  avatarUrl: 'https://i.pravatar.cc/100?img=12', // Slightly larger high-quality avatar
                ),
                const SizedBox(height: 24),
                _ReasonRow(
                  icon: Icons.access_time_rounded, // Improved clock icon matching mockup
                  label: "You've interacted with content about travel and more.",
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.label,
    this.icon,
    this.avatarUrl,
  });

  final String label;
  final IconData? icon;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: _Layout.reasonIconSize,
          height: _Layout.reasonIconSize,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: avatarUrl != null
              ? ClipOval(
                  child: Image.network(
                    avatarUrl!,
                    fit: BoxFit.cover,
                    width: _Layout.reasonIconSize,
                    height: _Layout.reasonIconSize,
                  ),
                )
              : Icon(
                  icon ?? Icons.autorenew_rounded,
                  size: 22,
                  color: Colors.white70,
                ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
