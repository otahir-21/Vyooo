import 'package:flutter/material.dart';

import '../theme/app_fonts.dart';
import '../theme/app_spacing.dart';
import '../../screens/profile/profile_figma_tokens.dart';

class _NavAssets {
  static const _base = 'assets/vyooO_icons/Home/nav_bar_icons';
  static const homeSelected = '$_base/home.png';
  static const homeUnselected = 'assets/BottomNavBar/HomeUnSlected.png';
  static const searchSelected = '$_base/search_filled.png';
  static const searchUnselected = '$_base/search.png';
  static const addSelected = '$_base/create.png';
  static const addUnselected = '$_base/create.png';
  static const profileDefault = 'assets/vyooO_icons/Home/profile_icon.png';
}

/// Custom bottom nav wrapper matching the VyooO design language.
/// Index: 0 Home, 1 Search, 2 Create (+), 3 Messages, 4 Profile.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.profileImageUrl,
    this.unreadNotificationCount = 0,
    this.unreadChatCount = 0,
  });

  final int currentIndex;
  final void Function(int) onTap;
  final String? profileImageUrl;
  final int unreadNotificationCount;
  final int unreadChatCount;

  static const double _iconSize = 21.25;
  static double get _profileIconSize => _iconSize * 1.35;
  static const Color _iconColor = ProfileFigmaTokens.primaryText;
  static const Color _selectedPillFill = ProfileFigmaTokens.cardBackground;
  static const Color _barFill = ProfileFigmaTokens.screenBackground;
  static const Color _splashColor = Color(0x33750047);

  static const double _tapTargetSize = 44;
  static const double _selectedPillSize = 44;

  Widget _buildProfileIcon(bool isSelected) {
    final hasProfileImage =
        profileImageUrl != null && profileImageUrl!.trim().isNotEmpty;
    final avatar = ClipOval(
      child: hasProfileImage
          ? Image.network(
              profileImageUrl!,
              fit: BoxFit.cover,
              width: _profileIconSize,
              height: _profileIconSize,
              errorBuilder: (_, error, stackTrace) => Image.asset(
                _NavAssets.profileDefault,
                fit: BoxFit.cover,
                width: _profileIconSize,
                height: _profileIconSize,
                errorBuilder: (_, error1, stack1) => Icon(
                  Icons.person_rounded,
                  size: _profileIconSize * 0.7,
                  color: _iconColor,
                ),
              ),
            )
          : Image.asset(
              _NavAssets.profileDefault,
              fit: BoxFit.cover,
              width: _profileIconSize,
              height: _profileIconSize,
              errorBuilder: (_, error2, stack2) => Icon(
                Icons.person_rounded,
                size: _profileIconSize * 0.7,
                color: _iconColor,
              ),
            ),
    );

    if (!isSelected) return avatar;

    return Container(
      width: _selectedPillSize,
      height: _selectedPillSize,
      decoration: const BoxDecoration(
        color: _selectedPillFill,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: avatar,
    );
  }

  Widget _buildNavTap({
    required VoidCallback onPressed,
    required Widget child,
    required bool isSelected,
  }) {
    return SizedBox(
      width: _tapTargetSize,
      height: _tapTargetSize,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onPressed,
          containedInkWell: true,
          highlightShape: BoxShape.circle,
          radius: _tapTargetSize / 2,
          splashColor: _splashColor,
          highlightColor: _splashColor.withValues(alpha: 0.5),
          child: Center(
            child: isSelected
                ? Container(
                    width: _selectedPillSize,
                    height: _selectedPillSize,
                    decoration: const BoxDecoration(
                      color: _selectedPillFill,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: child,
                  )
                : child,
          ),
        ),
      ),
    );
  }

  Widget _buildChatIcon(bool isSelected) {
    final count = unreadChatCount < 0 ? 0 : unreadChatCount;
    final showBadge = count > 0;
    final label = count > 99 ? '99+' : '$count';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          isSelected ? Icons.chat_bubble : Icons.chat_bubble_outline,
          size: _iconSize,
          color: _iconColor,
        ),
        if (showBadge)
          Positioned(
            right: -10,
            top: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF2D55),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _barFill, width: 1),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Nav icons + artwork height (excludes Android/iOS system nav inset).
  static const double barHeight = 60;

  /// Horizontal margin for the floating pill bar.
  static const double _horizontalMargin = 20;

  /// Bottom margin above the system gesture area.
  static const double _bottomMargin = AppSpacing.xs;

  /// Total bottom chrome: margins + [barHeight] + system navigation inset.
  static double totalHeightFor(BuildContext context) {
    return barHeight + _bottomMargin + MediaQuery.viewPaddingOf(context).bottom;
  }

  @override
  Widget build(BuildContext context) {
    final systemBottom = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _horizontalMargin,
        0,
        _horizontalMargin,
        systemBottom + _bottomMargin,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _barFill,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: SizedBox(
          height: barHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                unselectedAsset: _NavAssets.homeUnselected,
                selectedAsset: _NavAssets.homeSelected,
                isSelected: currentIndex == 0,
                onTap: () => onTap(0),
                buildTap: _buildNavTap,
              ),
              _NavItem(
                unselectedAsset: _NavAssets.searchUnselected,
                selectedAsset: _NavAssets.searchSelected,
                isSelected: currentIndex == 1,
                onTap: () => onTap(1),
                buildTap: _buildNavTap,
              ),
              _NavItem(
                unselectedAsset: _NavAssets.addUnselected,
                selectedAsset: _NavAssets.addSelected,
                isSelected: currentIndex == 2,
                onTap: () => onTap(2),
                buildTap: _buildNavTap,
              ),
              _NavItem(
                isSelected: currentIndex == 3,
                onTap: () => onTap(3),
                buildTap: _buildNavTap,
                customChild: _buildChatIcon(currentIndex == 3),
              ),
              _buildNavTap(
                onPressed: () => onTap(4),
                isSelected: currentIndex == 4,
                child: _buildProfileIcon(currentIndex == 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _NavTapBuilder = Widget Function({
  required VoidCallback onPressed,
  required Widget child,
  required bool isSelected,
});

class _NavItem extends StatelessWidget {
  const _NavItem({
    this.unselectedAsset,
    this.selectedAsset,
    required this.isSelected,
    required this.onTap,
    required this.buildTap,
    this.customChild,
  });

  final String? unselectedAsset;
  final String? selectedAsset;
  final bool isSelected;
  final VoidCallback onTap;
  final _NavTapBuilder buildTap;
  final Widget? customChild;

  @override
  Widget build(BuildContext context) {
    final icon = customChild ??
        Image.asset(
          isSelected ? selectedAsset! : unselectedAsset!,
          width: AppBottomNavigation._iconSize,
          height: AppBottomNavigation._iconSize,
          color: AppBottomNavigation._iconColor,
        );

    return buildTap(
      onPressed: onTap,
      isSelected: isSelected,
      child: icon,
    );
  }
}
