import 'package:flutter/material.dart';

import '../theme/app_padding.dart';
import '../theme/app_spacing.dart';

/// Common header for feed screens: VyooO logo + tab selector.
/// Same design everywhere (Figma: selected = white + capsule 15%, radius 20, padding 14; unselected = white 60%).
class AppFeedHeader extends StatelessWidget {
  const AppFeedHeader({
    super.key,
    required this.selectedIndex,
    this.labels = _defaultLabels,
    this.onTabSelected,
  });

  final int selectedIndex;
  final List<String> labels;
  final void Function(int index)? onTabSelected;

  static const List<String> _defaultLabels = [
    'Trending',
    'VR',
    'Following',
    'For You',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppPadding.screenHorizontal.copyWith(
        top: AppSpacing.sm,
        bottom: AppSpacing.md,
      ),
      child: Row(
        children: [
          _buildLogo(context),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: AppFeedTabSelector(
              labels: labels,
              selectedIndex: selectedIndex,
              onTabSelected: onTabSelected,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final logoHeight = screenWidth < 360 ? 34.0 : (screenWidth < 420 ? 40.0 : 44.0);

    return SizedBox(
      height: 100,
      child: Image.asset(
        'assets/BrandLogo/Vyooo logo (2).png',
        fit: BoxFit.contain,
        errorBuilder: (_, error, stackTrace) => const Text(
          'VyooO',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

/// Tab selector: selected = white pill with black text; unselected = white text with 60% opacity.
class AppFeedTabSelector extends StatelessWidget {
  const AppFeedTabSelector({
    super.key,
    required this.labels,
    required this.selectedIndex,
    this.onTabSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final void Function(int)? onTabSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(labels.length, (index) {
          final isSelected = selectedIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onTabSelected?.call(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? Colors.black
                          : Colors.white,
                    ),
                  ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
