import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

/// Playback speed options: 0.25x, 0.5x, 1x (Normal), 1.5x, 2x.
const List<PlaybackSpeedOption> kPlaybackSpeedOptions = [
  PlaybackSpeedOption(id: '0.25', label: '0.25x'),
  PlaybackSpeedOption(id: '0.5', label: '0.5x'),
  PlaybackSpeedOption(id: '1', label: '1x (Normal)'),
  PlaybackSpeedOption(id: '1.5', label: '1.5x'),
  PlaybackSpeedOption(id: '2', label: '2x'),
];

class PlaybackSpeedOption {
  const PlaybackSpeedOption({required this.id, required this.label});
  final String id;
  final String label;
}

void showPlaybackSpeedSheet(
  BuildContext context, {
  required String selectedId,
  required void Function(String id, String label) onSelected,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _PlaybackSpeedSheet(
      selectedId: selectedId,
      onSelected: onSelected,
    ),
  );
}

abstract final class _Layout {
  static const double dragHandleWidth = 36;
  static const double dragHandleHeight = 4;
}

class _PlaybackSpeedSheet extends StatelessWidget {
  const _PlaybackSpeedSheet({
    required this.selectedId,
    required this.onSelected,
  });

  final String selectedId;
  final void Function(String id, String label) onSelected;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.25,
      maxChildSize: 0.6,
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
                  'Playback Speed',
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
                  itemCount: kPlaybackSpeedOptions.length,
                  itemBuilder: (context, index) {
                    final option = kPlaybackSpeedOptions[index];
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
