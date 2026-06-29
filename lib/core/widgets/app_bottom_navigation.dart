import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../platform/app_system_ui.dart';
import '../theme/app_fonts.dart';
import '../theme/app_gradients.dart';
import '../theme/app_radius.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../../screens/profile/profile_figma_tokens.dart';

class _NavAssets {
  static const _base = 'assets/BottomNavBar';
  static const homeSelected = '$_base/home_selected.svg';
  static const homeUnselected = '$_base/home_unselected.svg';
  static const broadcastSelected = '$_base/broadcast_selected.svg';
  static const broadcastUnselected = '$_base/broadcast_unselected.svg';
  static const addSelected = '$_base/add_selected.svg';
  static const addUnselected = '$_base/add_unselected.svg';
  static const chatSelected = '$_base/chat_selected.svg';
  static const chatUnselected = '$_base/chat_unselected.svg';
  static const profileSelected = '$_base/profile_selected.png';
  static const profileUnselected = '$_base/profile_unselected.png';
  static const profileDefault = 'assets/vyooO_icons/Home/profile_icon.png';
}

/// Custom bottom nav wrapper matching the VyooO design language.
/// Index: 0 Home, 1 Go Live (broadcast), 2 Create (+), 3 Messages, 4 Profile.
/// Search is opened from the home feed header / hashtag links, not this tab.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.profileImageUrl,
    this.unreadNotificationCount = 0,
    this.unreadChatCount = 0,
    this.useFeedChrome = false,
  });

  final int currentIndex;
  final void Function(int) onTap;
  final String? profileImageUrl;
  final int unreadNotificationCount;
  final int unreadChatCount;

  /// Dark chrome + gradient scrim companion — home feed tab only.
  final bool useFeedChrome;

  static double get _profileIconSize => AppSizes.bottomNavIcon * 1.35;
  static const Color _iconColor = ProfileFigmaTokens.primaryText;
  static const Color _selectedPillFill = ProfileFigmaTokens.cardBackground;
  static const Color _navBarFill = ProfileFigmaTokens.screenBackground;
  static const Color _splashColor = Color(0x33750047);

  static const double _tapTargetSize = AppSizes.bottomNavTapTarget;
  static const double _selectedPillSize = AppSizes.bottomNavTapTarget;

  Widget _navIcon(String assetPath) => _NavIconImage(assetPath: assetPath);

  Widget _navSvgIcon(String assetPath) => _NavSvgIcon(assetPath: assetPath);

  Widget _buildProfileIcon(bool isSelected) {
    final hasProfileImage =
        profileImageUrl != null && profileImageUrl!.trim().isNotEmpty;
    if (!hasProfileImage) {
      return _navIcon(
        isSelected ? _NavAssets.profileSelected : _NavAssets.profileUnselected,
      );
    }

    final avatar = ClipOval(
      child: Image.network(
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
        _navSvgIcon(
          isSelected ? _NavAssets.chatSelected : _NavAssets.chatUnselected,
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
                border: Border.all(color: _navBarFill, width: 1),
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
  static const double barHeight = AppSizes.bottomNavBarHeight;

  /// Horizontal margin for the floating pill bar inside the chrome.
  static const double _horizontalMargin = 20;

  /// Space above the white pill inside the dark chrome strip.
  static const double _chromeTopPadding = AppSpacing.sm;

  /// iOS-only: fraction of the home-indicator inset below the bar (0.5 = floating pill look).
  static const double _iosSafeAreaBottomFactor = 0.5;

  /// Bottom nav height for overlay positioning.
  static double totalHeightFor(
    BuildContext context, {
    bool feedChrome = false,
  }) {
    final bottomInset = AppSystemUi.bottomChromeInset(
      context,
      iosInsetFactor: _iosSafeAreaBottomFactor,
    );
    final chromeTop = feedChrome ? _chromeTopPadding : 0.0;
    return chromeTop + barHeight + bottomInset;
  }

  BoxDecoration get _pillDecoration => BoxDecoration(
        color: _navBarFill,
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
      );

  Widget _buildNavRow() {
    return SizedBox(
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
            unselectedAsset: _NavAssets.broadcastUnselected,
            selectedAsset: _NavAssets.broadcastSelected,
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
    );
  }

  Widget _buildFloatingPill(double bottomInset) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _horizontalMargin,
        0,
        _horizontalMargin,
        bottomInset,
      ),
      child: DecoratedBox(
        decoration: _pillDecoration,
        child: _buildNavRow(),
      ),
    );
  }

  Widget _buildFeedChromePill(double bottomInset) {
    return ClipRRect(
      borderRadius: AppRadius.feedBottomChromeRadius,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppGradients.feedBottomNavChrome,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(AppRadius.feedBottomChrome),
            bottomRight: Radius.circular(AppRadius.feedBottomChrome),
          ),
          border: Border(
            top: BorderSide(
              color: Color(0x1AFFFFFF),
              width: 0.5,
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            _horizontalMargin,
            _chromeTopPadding,
            _horizontalMargin,
            bottomInset,
          ),
          child: DecoratedBox(
            decoration: _pillDecoration,
            child: _buildNavRow(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = AppSystemUi.bottomChromeInset(
      context,
      iosInsetFactor: _iosSafeAreaBottomFactor,
    );

    if (useFeedChrome) {
      return _buildFeedChromePill(bottomInset);
    }
    return _buildFloatingPill(bottomInset);
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
        _NavSvgIcon(
          assetPath: isSelected ? selectedAsset! : unselectedAsset!,
        );

    return buildTap(
      onPressed: onTap,
      isSelected: isSelected,
      child: icon,
    );
  }
}

class _NavIconImage extends StatelessWidget {
  const _NavIconImage({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: AppSizes.bottomNavIcon,
      height: AppSizes.bottomNavIcon,
    );
  }
}

class _NavSvgIcon extends StatelessWidget {
  const _NavSvgIcon({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetPath,
      width: AppSizes.bottomNavIcon,
      height: AppSizes.bottomNavIcon,
      fit: BoxFit.contain,
    );
  }
}
