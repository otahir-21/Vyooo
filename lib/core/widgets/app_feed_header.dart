import 'package:flutter/material.dart';

import '../theme/app_padding.dart';
import '../theme/app_radius.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'vyooo_brand_logo.dart';

/// Common header for feed screens: VyooO logo + actions on top,
/// full-width tab pills on the row below (Figma home feed).
/// Tab text: unselected DM Sans Regular 16 white; selected Bold 16 black.
class AppFeedHeader extends StatelessWidget {
  const AppFeedHeader({
    super.key,
    required this.selectedIndex,
    this.labels = _defaultLabels,
    this.onTabSelected,
    this.trailing,
    this.tabRowTrailing,
  });

  final int selectedIndex;
  final List<String> labels;
  final void Function(int index)? onTabSelected;
  final Widget? trailing;

  /// Shown at the end of the tab pill row (e.g. Following status toggle).
  final Widget? tabRowTrailing;

  static const List<String> _defaultLabels = [
    'Trending',
    'VR',
    'Following',
    'For You',
  ];

  /// Vertical space occupied by header content + its padding (no safe area).
  static double layoutHeight({
    double topPadding = AppSpacing.sm,
    double rowGap = AppSpacing.sm,
    double bottomPadding = AppSpacing.md,
  }) {
    return topPadding +
        AppSizes.feedHeaderContentHeight +
        rowGap +
        bottomPadding;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: AppPadding.screenHorizontal,
            child: SizedBox(
              height: AppSizes.feedHeaderLogoRowHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const VyoooBrandLogo.feed(),
                  const Spacer(),
                  ?trailing,
                ],
              ),
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Padding(
            padding: AppPadding.feedTabRowHorizontal,
            child: AppFeedTabSelector(
              labels: labels,
              selectedIndex: selectedIndex,
              onTabSelected: onTabSelected,
              trailing: tabRowTrailing,
            ),
          ),
        ],
      ),
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
    this.trailing,
  });

  final List<String> labels;
  final int selectedIndex;
  final void Function(int)? onTabSelected;
  final Widget? trailing;

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
        height: AppSizes.feedTabChipHeight,
        padding: AppPadding.feedTabChip,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : White15.value,
          borderRadius: AppRadius.feedTabRadius,
          border: isSelected
              ? null
              : Border.all(color: White24.value, width: 1),
        ),
        child: Text(
          labels[index],
          maxLines: 1,
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
        final trailingExtra = trailing == null
            ? 0.0
            : AppSizes.followingStoriesToggleWidth + AppSpacing.xs;
        final tabsWidth = _estimateTabsWidth(labels, selectedIndex);
        final needsScroll = tabsWidth + trailingExtra > maxWidth;

        if (trailing != null || needsScroll) {
          final rowChildren = <Widget>[
            ..._tabChildren(compactGaps: true),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.xs),
              trailing!,
            ],
          ];
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: rowChildren,
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
