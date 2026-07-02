import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_fonts.dart';
import '../theme/app_padding.dart';
import '../theme/app_radius.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'vyooo_brand_logo.dart';

/// Logo row only: VyooO + optional trailing actions (search, notifications).
/// Matches the top row of [AppFeedHeader] without feed tabs.
class AppFeedLogoBar extends StatelessWidget {
  const AppFeedLogoBar({super.key, this.trailing});

  final Widget? trailing;

  /// Vertical space occupied by the logo row + padding (no safe area).
  static double layoutHeight({
    double topPadding = AppSpacing.sm,
    double bottomPadding = AppSpacing.md,
  }) {
    return topPadding + AppSizes.feedHeaderLogoRowHeight + bottomPadding;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.md,
      ),
      child: Padding(
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
    );
  }
}

/// Common header for feed screens: VyooO logo + actions on top,
/// full-width tab pills on the row below (Figma home feed).
/// Tab text: unselected DM Sans Regular 15 white; selected Bold 15 black.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppFeedLogoBar(trailing: trailing),
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

  static const TextHeightBehavior _tabTextHeightBehavior = TextHeightBehavior(
    applyHeightToFirstAscent: false,
    applyHeightToLastDescent: false,
  );

  static StrutStyle _tabStrutStyle({required bool isSelected}) {
    return StrutStyle(
      fontFamily: AppFonts.body,
      fontSize: AppTypography.feedTabLabelSize,
      height: AppTypography.feedTabLabelLineHeight /
          AppTypography.feedTabLabelSize,
      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  static double _estimateTabsWidth({
    required List<String> labels,
    required int selectedIndex,
    required EdgeInsets chipPadding,
    required double gap,
    required TextScaler textScaler,
  }) {
    var total = 0.0;
    final chipPaddingWidth = chipPadding.horizontal;
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
        textScaler: textScaler,
        strutStyle: _tabStrutStyle(isSelected: isSelected),
        textHeightBehavior: _tabTextHeightBehavior,
        maxLines: 1,
      )..layout();
      total += painter.width + chipPaddingWidth;
      if (i < labels.length - 1) {
        total += gap;
      }
    }
    return total;
  }

  static _FeedTabLayout _resolveLayout({
    required double maxWidth,
    required List<String> labels,
    required int selectedIndex,
    required TextScaler textScaler,
    required bool hasTrailing,
  }) {
    var chipPadding = AppPadding.feedTabChip;
    var gap = AppSpacing.feedTabGap;

    double contentWidth() {
      final trailingExtra = hasTrailing
          ? AppSizes.followingStoriesToggleWidth + gap
          : 0.0;
      return _estimateTabsWidth(
            labels: labels,
            selectedIndex: selectedIndex,
            chipPadding: chipPadding,
            gap: gap,
            textScaler: textScaler,
          ) +
          trailingExtra;
    }

    if (contentWidth() > maxWidth) {
      chipPadding = AppPadding.feedTabChipCompact;
      gap = AppSpacing.feedTabGapCompact;
    }

    final needsScroll = contentWidth() > maxWidth;

    return _FeedTabLayout(
      chipPadding: chipPadding,
      gap: gap,
      needsScroll: needsScroll,
    );
  }

  Widget _buildTabLabel(int index) {
    final isSelected = selectedIndex == index;
    return Text(
      labels[index],
      maxLines: 1,
      softWrap: false,
      textAlign: TextAlign.center,
      strutStyle: _tabStrutStyle(isSelected: isSelected),
      textHeightBehavior: _tabTextHeightBehavior,
      style: isSelected
          ? AppTypography.feedTabLabelSelected
          : AppTypography.feedTabLabel,
    );
  }

  Widget _buildTab(int index, {required EdgeInsets chipPadding}) {
    final isSelected = selectedIndex == index;
    final decoration = BoxDecoration(
      color: isSelected ? AppTheme.primary : White20.value,
      borderRadius: AppRadius.feedTabRadius,
      border: Border.all(color: White20.value, width: 1),
    );

    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: AppSizes.feedTabChipHeight,
      padding: chipPadding,
      alignment: Alignment.center,
      decoration: decoration,
      child: _buildTabLabel(index),
    );

    return GestureDetector(
      onTap: () => onTabSelected?.call(index),
      behavior: HitTestBehavior.opaque,
      child: isSelected
          ? chip
          : ClipRRect(
              borderRadius: AppRadius.feedTabRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: AppSizes.feedTabBlurSigma,
                  sigmaY: AppSizes.feedTabBlurSigma,
                ),
                child: chip,
              ),
            ),
    );
  }

  List<Widget> _tabChildren({
    required EdgeInsets chipPadding,
    required double gap,
  }) {
    return List.generate(labels.length, (index) {
      final tab = _buildTab(index, chipPadding: chipPadding);
      if (index == 0) return tab;
      return Padding(
        padding: EdgeInsets.only(left: gap),
        child: tab,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final textScaler = MediaQuery.textScalerOf(context);
        final layout = _resolveLayout(
          maxWidth: maxWidth,
          labels: labels,
          selectedIndex: selectedIndex,
          textScaler: textScaler,
          hasTrailing: trailing != null,
        );

        final rowChildren = <Widget>[
          ..._tabChildren(
            chipPadding: layout.chipPadding,
            gap: layout.gap,
          ),
          if (trailing != null) ...[
            SizedBox(width: layout.gap),
            trailing!,
          ],
        ];

        Widget row = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: rowChildren,
        );

        if (trailing != null || layout.needsScroll) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            physics: const BouncingScrollPhysics(),
            child: row,
          );
        }

        return row;
      },
    );
  }
}

class _FeedTabLayout {
  const _FeedTabLayout({
    required this.chipPadding,
    required this.gap,
    required this.needsScroll,
  });

  final EdgeInsets chipPadding;
  final double gap;
  final bool needsScroll;
}
