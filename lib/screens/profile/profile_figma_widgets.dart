import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import 'profile_figma_tokens.dart';

/// Circular profile photo with Figma 169×169 frame and magenta ring.
class ProfileFigmaAvatar extends StatelessWidget {
  const ProfileFigmaAvatar({
    super.key,
    required this.imageUrl,
  });

  final String? imageUrl;

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
    final inner = outer - 2 * (pad + ring);
    final innerRadius = inner / 2;

    final avatar = CircleAvatar(
      radius: innerRadius,
      backgroundColor: Colors.white.withValues(alpha: 0.1),
      backgroundImage:
          isValidNetworkUrl(imageUrl) ? NetworkImage(imageUrl!) : null,
      child: !isValidNetworkUrl(imageUrl)
          ? Icon(
              Icons.person_rounded,
              size: innerRadius,
              color: Colors.white.withValues(alpha: 0.4),
            )
          : null,
    );

    Widget child = SizedBox(
      width: outer,
      height: outer,
      child: Container(
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: ProfileFigmaTokens.accentMagenta,
            width: ring,
          ),
        ),
        child: avatar,
      ),
    );

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
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: ProfileFigmaTokens.statChipWidth,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: radius,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: ProfileFigmaTokens.statChipBorderWidth,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: ProfileFigmaTokens.statValueFontSize,
                      fontWeight: FontWeight.w600,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: ProfileFigmaTokens.statLabelFontSize,
                      fontWeight: FontWeight.w400,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma Edit Profile / Share — 154×45, radius 52, fill #1C1C1F, 15% white stroke.
class ProfileFigmaActionButton extends StatelessWidget {
  const ProfileFigmaActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconAssetPath,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final String? iconAssetPath;

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
          width: ProfileFigmaTokens.actionButtonWidth,
          height: ProfileFigmaTokens.actionButtonHeight,
          decoration: BoxDecoration(
            color: ProfileFigmaTokens.actionButtonFill,
            borderRadius: radius,
            border: Border.all(
              color: ProfileFigmaTokens.actionButtonStroke,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: ProfileFigmaTokens.actionButtonPaddingH,
            vertical: ProfileFigmaTokens.actionButtonPaddingV,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ),
              if (icon != null || iconAssetPath != null) ...[
                const SizedBox(width: ProfileFigmaTokens.actionIconGap),
                if (iconAssetPath != null)
                  Image.asset(
                    iconAssetPath!,
                    width: 16,
                    height: 16,
                    color: Colors.white,
                  )
                else
                  Icon(icon, size: 16, color: Colors.white),
              ],
            ],
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
    this.compact = false,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final int? savedTabIndex;
  final VoidCallback? onSavedTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final outerPad =
        compact ? 2.0 : ProfileFigmaTokens.tabBarOuterPadding;
    final tabVPad = compact ? 6.0 : ProfileFigmaTokens.tabVerticalPadding;
    final tabFont = compact ? 12.0 : ProfileFigmaTokens.tabFontSize;
    final starPad = compact ? 8.0 : 10.0;
    final starIcon = compact ? 18.0 : 20.0;
    final savedIndex = savedTabIndex;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.all(outerPad),
            decoration: BoxDecoration(
              color: ProfileFigmaTokens.tabTrack,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              children: List.generate(tabs.length, (index) {
                final isSelected = index == selectedIndex;
                return Expanded(
                  child: Row(
                    children: [
                      if (index > 0 &&
                          !isSelected &&
                          selectedIndex != index - 1)
                        Container(
                          width: 1,
                          height: 16,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => onTabSelected(index),
                            borderRadius:
                                BorderRadius.circular(AppRadius.card),
                            child: Container(
                              padding:
                                  EdgeInsets.symmetric(vertical: tabVPad),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? AppGradients.profileTabActiveGradient
                                    : null,
                                color: isSelected ? null : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.card,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  tabs[index],
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white
                                            .withValues(alpha: 0.6),
                                    fontSize: tabFont,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
        if (savedIndex != null && onSavedTap != null) ...[
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSavedTap,
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Container(
                padding: EdgeInsets.all(starPad),
                decoration: BoxDecoration(
                  color: ProfileFigmaTokens.tabTrack,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Icon(
                  selectedIndex == savedIndex
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: selectedIndex == savedIndex
                      ? ProfileFigmaTokens.accentMagenta
                      : Colors.white.withValues(alpha: 0.8),
                  size: starIcon,
                ),
              ),
            ),
          ),
        ],
      ],
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: ProfileFigmaTokens.displayNameFontSize,
            fontWeight: FontWeight.w600,
            height: ProfileFigmaTokens.displayNameHeight,
          ),
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
            color: Colors.white.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
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
