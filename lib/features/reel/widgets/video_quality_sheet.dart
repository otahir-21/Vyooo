import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

/// Video quality options. [isPremium] shows yellow PREMIUM tag.
const List<VideoQualityOption> kVideoQualityOptions = [
  VideoQualityOption(id: 'auto', label: 'Auto', isPremium: false),
  VideoQualityOption(id: 'max', label: 'Max (4k)', isPremium: true),
  VideoQualityOption(id: 'high', label: 'High (1080p)', isPremium: true),
  VideoQualityOption(id: 'medium', label: 'Medium (720p)', isPremium: true),
  VideoQualityOption(id: 'low', label: 'Low (480p)', isPremium: false),
];

class VideoQualityOption {
  const VideoQualityOption({
    required this.id,
    required this.label,
    this.isPremium = false,
  });
  final String id;
  final String label;
  final bool isPremium;
}

void showVideoQualitySheet(
  BuildContext context, {
  required String selectedId,
  required void Function(String id, String label) onSelected,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _VideoQualitySheet(
      selectedId: selectedId,
      onSelected: onSelected,
    ),
  );
}

abstract final class _Layout {
  static const double dragHandleWidth = 36;
  static const double dragHandleHeight = 4;
}

class _VideoQualitySheet extends StatelessWidget {
  const _VideoQualitySheet({
    required this.selectedId,
    required this.onSelected,
  });

  final String selectedId;
  final void Function(String id, String label) onSelected;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.28,
      maxChildSize: 0.65,
      builder: (context, scrollController) {
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DragHandle(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  'Video Quality',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  itemCount: kVideoQualityOptions.length,
                  itemBuilder: (context, index) {
                    final option = kVideoQualityOptions[index];
                    final isSelected = option.id == selectedId;
                    return InkWell(
                      onTap: () {
                        onSelected(option.id, option.label);
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                option.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            if (option.isPremium)
                              Container(
                                margin: const EdgeInsets.only(right: AppSpacing.sm),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.lightGold.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'PREMIUM',
                                  style: TextStyle(
                                    color: AppColors.lightGold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (isSelected)
                              const Icon(
                                Icons.check,
                                color: AppColors.whatsappGreen,
                                size: 24,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.storyItem, bottom: AppSpacing.xs),
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
    );
  }
}
