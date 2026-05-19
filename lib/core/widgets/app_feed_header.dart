import 'package:flutter/material.dart';

import '../theme/app_padding.dart';
import '../theme/app_radius.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'vyooo_brand_logo.dart';

/// Common header for feed screens: VyooO logo + tab selector.
/// Selected tab: pill + border (15% fill). Unselected: text only, no background.
/// Typography: unselected DM Sans Regular 14 @ 60% white; selected Bold 16 white.
class AppFeedHeader extends StatelessWidget {
  const AppFeedHeader({
    super.key,
    required this.selectedIndex,
    this.labels = _defaultLabels,
    this.onTabSelected,
    this.trailing,
  });

  final int selectedIndex;
  final List<String> labels;
  final void Function(int index)? onTabSelected;
  final Widget? trailing;

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
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return const VyoooBrandLogo(
      size: AppSizes.feedLogoHeight,
      center: false,
    );
  }
}

/// Tab selector for Trending / VR / Following / For You.
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

  static double _estimateTabsWidth(List<String> labels, int selectedIndex) {
    var total = 0.0;
    final chipPadding = AppPadding.feedTabChip.horizontal * 2;
    for (var i = 0; i < labels.length; i++) {
      final isSelected = selectedIndex == i;
      final painter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: isSelected
              ? AppTypography.feedTabLabelSelected
              : AppTypography.feedTabLabel,
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      total += painter.width + chipPadding;
      if (i < labels.length - 1) {
        total += AppSpacing.xs;
      }
    }
    return total;
  }

  Widget _buildTab(int index) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onTabSelected?.call(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: AppPadding.feedTabChip,
        decoration: isSelected
            ? BoxDecoration(
                color: White15.value,
                borderRadius: AppRadius.pillRadius,
                border: Border.all(color: AppTheme.primary, width: 1),
              )
            : null,
        child: Text(
          labels[index],
          style: isSelected
              ? AppTypography.feedTabLabelSelected
              : AppTypography.feedTabLabel,
        ),
      ),
    );
  }

  List<Widget> _tabChildren({required bool compactGaps}) {
    return List.generate(labels.length, (index) {
      final tab = _buildTab(index);
      if (!compactGaps || index == 0) return tab;
      return Padding(
        padding: const EdgeInsets.only(left: AppSpacing.xs),
        child: tab,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final needsScroll =
            _estimateTabsWidth(labels, selectedIndex) > maxWidth;

        if (needsScroll) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _tabChildren(compactGaps: true),
            ),
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _tabChildren(compactGaps: false),
        );
      },
    );
  }
}
