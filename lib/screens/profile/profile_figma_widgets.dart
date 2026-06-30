import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/profile_assets.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import 'profile_figma_tokens.dart';

/// Circular profile photo with optional story ring (Figma #E51147).
class ProfileFigmaAvatar extends StatelessWidget {
  const ProfileFigmaAvatar({
    super.key,
    required this.imageUrl,
    this.hasStory = false,
    this.onTap,
  });

  final String? imageUrl;
  final bool hasStory;
  final VoidCallback? onTap;

  static bool isValidNetworkUrl(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.isAbsolute || uri.host.isEmpty) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  @override
  Widget build(BuildContext context) {
    final outer = ProfileFigmaTokens.avatarOuterSize;
    final pad = ProfileFigmaTokens.avatarRingPadding;
    final ring = ProfileFigmaTokens.avatarRingWidth;
    // With story: photo sits inside ring + white gap. Without: photo fills frame.
    final photoDiameter = hasStory ? outer - 2 * (pad + ring) : outer;
    final photoRadius = photoDiameter / 2;

    final avatar = CircleAvatar(
      radius: photoRadius,
      backgroundColor: ProfileFigmaTokens.cardBackground,
      backgroundImage:
          isValidNetworkUrl(imageUrl) ? NetworkImage(imageUrl!) : null,
      child: !isValidNetworkUrl(imageUrl)
          ? Icon(
              Icons.person_rounded,
              size: photoRadius,
              color: ProfileFigmaTokens.secondaryText.withValues(alpha: 0.5),
            )
          : null,
    );

    Widget child;
    if (hasStory) {
      child = SizedBox(
        width: outer,
        height: outer,
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: ProfileFigmaTokens.storyRing,
          ),
          padding: EdgeInsets.all(ring),
          child: Container(
            padding: EdgeInsets.all(pad),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: ProfileFigmaTokens.screenBackground,
            ),
            child: avatar,
          ),
        ),
      );
    } else {
      child = SizedBox(
        width: outer,
        height: outer,
        child: Center(child: avatar),
      );
    }

    if (onTap != null) {
      child = GestureDetector(onTap: onTap, child: child);
    }

    return child;
  }
}

class ProfileFigmaStatChip extends StatelessWidget {
  const ProfileFigmaStatChip({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius =
        BorderRadius.circular(ProfileFigmaTokens.statChipRadius);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: ProfileFigmaTokens.statChipWidth,
          height: ProfileFigmaTokens.statChipHeight,
          decoration: BoxDecoration(
            color: ProfileFigmaTokens.statChipBackground,
            borderRadius: radius,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: AppTypography.profileStatValue,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.profileStatLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Edit Profile — near-black pill, white label.
class ProfileFigmaActionButton extends StatelessWidget {
  const ProfileFigmaActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius =
        BorderRadius.circular(ProfileFigmaTokens.actionButtonRadius);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: radius,
        child: Ink(
          height: ProfileFigmaTokens.actionButtonHeight,
          decoration: BoxDecoration(
            color: ProfileFigmaTokens.actionButtonFill,
            borderRadius: radius,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: ProfileFigmaTokens.actionButtonPaddingH,
            vertical: ProfileFigmaTokens.actionButtonPaddingV,
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.profileActionButtonLabel,
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular secondary action (Share, etc.) — #F2F2F2 fill.
class ProfileFigmaIconActionButton extends StatelessWidget {
  const ProfileFigmaIconActionButton({
    super.key,
    required this.onPressed,
    this.icon,
    this.iconAssetPath,
  });

  final VoidCallback onPressed;
  final IconData? icon;
  final String? iconAssetPath;

  @override
  Widget build(BuildContext context) {
    final size = ProfileFigmaTokens.actionIconButtonSize;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Ink(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: ProfileFigmaTokens.secondaryActionFill,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: iconAssetPath != null
                ? Image.asset(
                    iconAssetPath!,
                    width: ProfileFigmaTokens.actionIconSize,
                    height: ProfileFigmaTokens.actionIconSize,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    color: ProfileFigmaTokens.primaryText,
                  )
                : Icon(
                    icon ?? Icons.add_rounded,
                    size: ProfileFigmaTokens.actionIconSize,
                    color: ProfileFigmaTokens.primaryText,
                  ),
          ),
        ),
      ),
    );
  }
}

class ProfileFigmaTabBar extends StatelessWidget {
  const ProfileFigmaTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.savedTabIndex,
    this.onSavedTap,
    this.onBookmarkTap,
    this.compact = false,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final int? savedTabIndex;
  final VoidCallback? onSavedTap;
  final VoidCallback? onBookmarkTap;
  final bool compact;

  Widget _accessoryButton({
    required String iconAsset,
    required bool selected,
    required VoidCallback onTap,
    required bool compact,
  }) {
    final width = compact ? 30.0 : ProfileFigmaTokens.tabAccessoryWidth;
    final height = compact ? 34.0 : ProfileFigmaTokens.tabAccessoryHeight;
    final radius =
        compact ? 10.0 : ProfileFigmaTokens.tabAccessoryRadius;
    final iconColor = selected
        ? ProfileFigmaTokens.tabSelectedFill
        : ProfileFigmaTokens.tabAccessoryIconColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: ProfileFigmaTokens.screenBackground,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Center(
            child: SvgPicture.asset(
              iconAsset,
              width: width,
              height: height,
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outerPad =
        compact ? 2.0 : ProfileFigmaTokens.tabBarOuterPadding;
    final barHeight =
        compact ? 32.0 : ProfileFigmaTokens.tabBarHeight;
    final selectedTabFont =
        compact ? 13.0 : ProfileFigmaTokens.tabSelectedFontSize;
    final unselectedTabFont =
        compact ? 11.0 : ProfileFigmaTokens.tabUnselectedFontSize;
    final savedIndex = savedTabIndex;
    final isSavedSelected =
        savedIndex != null && selectedIndex == savedIndex;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            height: barHeight,
            padding: EdgeInsets.all(outerPad),
            decoration: BoxDecoration(
              color: ProfileFigmaTokens.tabTrack,
              borderRadius: BorderRadius.circular(
                compact ? AppRadius.pill : ProfileFigmaTokens.tabBarRadius,
              ),
              boxShadow: compact
                  ? null
                  : const [
                      BoxShadow(
                        color: ProfileFigmaTokens.tabBarShadowColor,
                        blurRadius: ProfileFigmaTokens.tabBarShadowBlur,
                      ),
                    ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(tabs.length, (index) {
                final isSelected =
                    index == selectedIndex && !isSavedSelected;
                final pillRadius = compact
                    ? AppRadius.pill
                    : ProfileFigmaTokens.tabSelectedPillRadius;
                return Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onTabSelected(index),
                      borderRadius: BorderRadius.circular(pillRadius),
                      splashColor: ProfileFigmaTokens.tabSelectedFill
                          .withValues(alpha: 0.12),
                      highlightColor: ProfileFigmaTokens.tabSelectedFill
                          .withValues(alpha: 0.08),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? ProfileFigmaTokens.tabSelectedFill
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(pillRadius),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          tabs[index],
                          style: isSelected
                              ? AppTypography.profileTabSelectedLabel
                                  .copyWith(fontSize: selectedTabFont)
                              : AppTypography.profileTabUnselectedLabel
                                  .copyWith(fontSize: unselectedTabFont),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        if (onBookmarkTap != null) ...[
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            height: barHeight,
            child: Center(
              child: _accessoryButton(
                iconAsset: ProfileAssets.profileTabBookmarkIcon,
                selected: isSavedSelected,
                onTap: onBookmarkTap!,
                compact: compact,
              ),
            ),
          ),
        ],
        if (savedIndex != null && onSavedTap != null) ...[
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            height: barHeight,
            child: Center(
              child: _accessoryButton(
                iconAsset: ProfileAssets.profileTabStarIcon,
                selected: isSavedSelected,
                onTap: onSavedTap!,
                compact: compact,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Aligns [child] under the first tab (Posts) matching [ProfileFigmaTabBar] layout.
class ProfileTabUnderFirstTab extends StatelessWidget {
  const ProfileTabUnderFirstTab({
    super.key,
    required this.tabCount,
    required this.child,
    this.showBookmarkAccessory = false,
    this.showStarAccessory = false,
    this.compact = false,
  });

  final int tabCount;
  final Widget child;
  final bool showBookmarkAccessory;
  final bool showStarAccessory;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accessoryWidth =
        compact ? 30.0 : ProfileFigmaTokens.tabAccessoryWidth;
    final outerPad =
        compact ? 2.0 : ProfileFigmaTokens.tabBarOuterPadding;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: outerPad),
            child: Row(
              children: [
                Expanded(child: child),
                ...List.generate(
                  tabCount - 1,
                  (_) => const Expanded(child: SizedBox.shrink()),
                ),
              ],
            ),
          ),
        ),
        if (showBookmarkAccessory) ...[
          const SizedBox(width: AppSpacing.sm),
          SizedBox(width: accessoryWidth),
        ],
        if (showStarAccessory) ...[
          const SizedBox(width: AppSpacing.sm),
          SizedBox(width: accessoryWidth),
        ],
      ],
    );
  }
}

/// Small magenta handle — expands/collapses the highlights row under Posts.
class ProfileHighlightsToggleHandle extends StatelessWidget {
  const ProfileHighlightsToggleHandle({
    super.key,
    required this.expanded,
    required this.onTap,
  });

  final bool expanded;
  final VoidCallback onTap;

  static final BorderRadius _radius = BorderRadius.vertical(
    top: Radius.circular(ProfileFigmaTokens.highlightsToggleTopRadius),
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: _radius,
        child: Ink(
          height: ProfileFigmaTokens.highlightsToggleHeight,
          decoration: BoxDecoration(
            color: ProfileFigmaTokens.highlightAddFill,
            borderRadius: _radius,
          ),
          child: Center(
            child: Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: ProfileFigmaTokens.screenBackground,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

/// Magenta "+" tile with "Highlights" label underneath.
class ProfileHighlightAddChip extends StatelessWidget {
  const ProfileHighlightAddChip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ProfileFigmaTokens.highlightTileWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(
                ProfileFigmaTokens.highlightTileRadius,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  ProfileFigmaTokens.highlightTileRadius,
                ),
                child: SizedBox(
                  width: ProfileFigmaTokens.highlightTileWidth,
                  height: ProfileFigmaTokens.highlightTileHeight,
                  child: ColoredBox(
                    color: ProfileFigmaTokens.highlightAddFill,
                    child: Center(
                      child: Icon(
                        Icons.add_rounded,
                        color: ProfileFigmaTokens.screenBackground,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: ProfileFigmaTokens.highlightLabelGap),
          Text(
            'Highlights',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.body,
              color: ProfileFigmaTokens.highlightLabelColor,
              fontSize: ProfileFigmaTokens.highlightLabelFontSize,
              fontWeight: ProfileFigmaTokens.highlightLabelFontWeight,
              height: ProfileFigmaTokens.highlightLabelLineHeight /
                  ProfileFigmaTokens.highlightLabelFontSize,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileFigmaDisplayNameRow extends StatelessWidget {
  const ProfileFigmaDisplayNameRow({
    super.key,
    required this.displayName,
    required this.isVerified,
    this.badgeColor = ProfileFigmaTokens.accentMagenta,
  });

  final String displayName;
  final bool isVerified;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayName,
          style: AppTypography.profileDisplayName,
        ),
        if (isVerified) ...[
          const SizedBox(width: ProfileFigmaTokens.nameVerifiedGap),
          Container(
            width: ProfileFigmaTokens.verifiedBadgeSize,
            height: ProfileFigmaTokens.verifiedBadgeSize,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 12,
              color: Colors.white,
            ),
          ),
        ],
      ],
    );
  }
}

/// Figma other-user profile top bar: avatar, name, handle, follow chip, close.
class OtherUserProfileTopBar extends StatelessWidget {
  const OtherUserProfileTopBar({
    super.key,
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    required this.followLabel,
    required this.followOutlined,
    required this.followBusy,
    required this.onFollowTap,
    required this.onClose,
  });

  final String displayName;
  final String username;
  final String avatarUrl;
  final String followLabel;
  final bool followOutlined;
  final bool followBusy;
  final VoidCallback onFollowTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        top + AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: ProfileFigmaTokens.otherUserHeaderAvatarRadius,
            backgroundColor: ProfileFigmaTokens.cardBackground,
            backgroundImage: ProfileFigmaAvatar.isValidNetworkUrl(avatarUrl)
                ? NetworkImage(avatarUrl)
                : null,
            child: !ProfileFigmaAvatar.isValidNetworkUrl(avatarUrl)
                ? Icon(
                    Icons.person_rounded,
                    size: ProfileFigmaTokens.otherUserHeaderAvatarRadius,
                    color: ProfileFigmaTokens.secondaryText.withValues(alpha: 0.5),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    color: ProfileFigmaTokens.primaryText,
                    fontSize: ProfileFigmaTokens.otherUserHeaderNameFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '@${ProfileFigmaTokens.displayUsername(username)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    color: ProfileFigmaTokens.otherUserHeaderHandleColor,
                    fontSize: ProfileFigmaTokens.otherUserHeaderHandleFontSize,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ProfileFigmaHeaderFollowChip(
            label: followLabel,
            outlined: followOutlined,
            busy: followBusy,
            onTap: followBusy ? () {} : onFollowTap,
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(
              Icons.close_rounded,
              size: 22,
              color: ProfileFigmaTokens.secondaryText,
            ),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}

/// Outlined "Following" / filled "Follow" chip for profile header.
class ProfileFigmaHeaderFollowChip extends StatelessWidget {
  const ProfileFigmaHeaderFollowChip({
    super.key,
    required this.label,
    required this.outlined,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool outlined;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: outlined ? Colors.transparent : AppColors.brandPink,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: outlined
                ? Border.all(
                    color: ProfileFigmaTokens.profileFollowingBorder,
                    width: 1,
                  )
                : null,
          ),
          child: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ProfileFigmaTokens.primaryText,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    color: outlined
                        ? ProfileFigmaTokens.primaryText
                        : Colors.white,
                    fontSize: ProfileFigmaTokens.otherUserHeaderFollowFontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Profile bio — always shows the full text (scroll handled by parent).
class ProfileBioText extends StatelessWidget {
  const ProfileBioText({
    super.key,
    required this.bio,
    this.textAlign = TextAlign.center,
  });

  final String bio;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final text = bio.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return Text(
      text,
      textAlign: textAlign,
      style: const TextStyle(
        fontFamily: AppFonts.body,
        color: ProfileFigmaTokens.secondaryText,
        fontSize: ProfileFigmaTokens.bioFontSize,
        height: 1.35,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class ProfileFigmaMusicLine extends StatelessWidget {
  const ProfileFigmaMusicLine({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_circle_outline_rounded,
            size: 14,
            color: ProfileFigmaTokens.secondaryText,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppFonts.body,
                color: ProfileFigmaTokens.secondaryText,
                fontSize: ProfileFigmaTokens.musicFontSize,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Left-edge sliding drawer: collapsed burgundy handle → expanded icon rail.
class ProfileSideDrawer extends StatefulWidget {
  const ProfileSideDrawer({
    super.key,
    required this.onMenuTap,
    required this.onWalletTap,
    required this.onChatTap,
    required this.onRevenueTap,
  });

  final VoidCallback onMenuTap;
  final VoidCallback onWalletTap;
  final VoidCallback onChatTap;
  final VoidCallback onRevenueTap;

  @override
  State<ProfileSideDrawer> createState() => _ProfileSideDrawerState();
}

class _ProfileSideDrawerState extends State<ProfileSideDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _dragOrigin = 0;

  static double get _expandedWidth => ProfileFigmaTokens.profileSideRailWidth;

  static double get _collapsedWidth =>
      ProfileFigmaTokens.profileSideRailHandleWidth;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: ProfileFigmaTokens.profileSideDrawerAnimation,
      value: 0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isExpanded => _controller.value >= 0.5;

  void _toggle() {
    if (_isExpanded) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  void _onDragStart(DragStartDetails details) {
    _dragOrigin = _controller.value;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    final travel = _expandedWidth - _collapsedWidth;
    if (travel <= 0) return;
    _controller.value = (_dragOrigin + delta / travel).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() > 280) {
      if (velocity > 0) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
      return;
    }
    if (_controller.value >= 0.5) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = ProfileFigmaTokens.profileSideRailIconSize;
    final railHeight = ProfileFigmaTokens.profileSideRailHeight;
    final iconSlotHeight = (railHeight - 24) / 4;
    final handleWidth = ProfileFigmaTokens.profileSideRailHandleWidth;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOutCubic.transform(_controller.value);
        final outerWidth =
            _collapsedWidth + (_expandedWidth - _collapsedWidth) * t;
        final iconOpacity = t.clamp(0.0, 1.0);
        final panelRadius = Radius.circular(ProfileFigmaTokens.profileSideRailRadius);

        return GestureDetector(
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          onTap: t < 0.85 ? _toggle : null,
          behavior: HitTestBehavior.translucent,
          child: SizedBox(
            width: outerWidth,
            height: railHeight,
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerRight,
                widthFactor: outerWidth / _expandedWidth,
                child: SizedBox(
                  width: _expandedWidth,
                  height: railHeight,
                  child: Material(
                    color: ProfileFigmaTokens.sideDrawerFill,
                    borderRadius: BorderRadius.horizontal(
                      left: t < 0.08
                          ? Radius.circular(handleWidth / 2)
                          : Radius.zero,
                      right: panelRadius,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Opacity(
                      opacity: iconOpacity,
                      child: IgnorePointer(
                        ignoring: t < 0.85,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _ProfileSideRailIconButton(
                              icon: Icons.menu_rounded,
                              size: iconSize,
                              slotHeight: iconSlotHeight,
                              onTap: widget.onMenuTap,
                            ),
                            _ProfileSideRailIconButton(
                              icon: Icons.circle_outlined,
                              size: iconSize,
                              slotHeight: iconSlotHeight,
                              onTap: widget.onWalletTap,
                            ),
                            _ProfileSideRailIconButton(
                              icon: Icons.chat_bubble_outline_rounded,
                              size: iconSize,
                              slotHeight: iconSlotHeight,
                              onTap: widget.onChatTap,
                            ),
                            _ProfileSideRailIconButton(
                              icon: Icons.bar_chart_rounded,
                              size: iconSize,
                              slotHeight: iconSlotHeight,
                              onTap: widget.onRevenueTap,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileSideRailIconButton extends StatelessWidget {
  const _ProfileSideRailIconButton({
    required this.icon,
    required this.size,
    required this.slotHeight,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final double slotHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ProfileFigmaTokens.profileSideRailWidth,
      height: slotHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Icon(
              icon,
              size: size,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
