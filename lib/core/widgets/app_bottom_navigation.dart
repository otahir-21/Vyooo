import 'package:flutter/material.dart';

class _NavAssets {
  static const _base = 'assets/vyooO_icons/Home/nav_bar_icons';
  static const homeSelected = '$_base/home.png';
  static const homeUnselected = 'assets/BottomNavBar/HomeUnSlected.png';
  static const searchSelected = '$_base/search_filled.png';
  static const searchUnselected = '$_base/search.png';
  static const addSelected = '$_base/create.png';
  static const addUnselected = '$_base/create.png';
  static const settingsSelected = '$_base/notification_filled.png';
  static const settingsUnselected = '$_base/notifications.png';
  static const profileDefault = 'assets/vyooO_icons/Home/profile_icon.png';
}

/// Custom bottom nav wrapper matching the VyooO design language.
/// Index: 0 Home, 1 Search, 2 Create (+), 3 Settings (as Notifications), 4 Profile.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.profileImageUrl,
    this.unreadNotificationCount = 0,
  });

  final int currentIndex;
  final void Function(int) onTap;
  final String? profileImageUrl;
  final int unreadNotificationCount;

  static const double _iconSize = 25;
  static const Color _activeIconColor = Colors.white;
  static const Color _inactiveIconColor = Color(0xFF8C8C96);
  static const Color _splashColor = Color(0x44DE106B);

  Widget _buildIcon(String asset, IconData fallback, bool isSelected) {
    return SizedBox(
      width: _iconSize,
      height: _iconSize,
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        color: isSelected ? _activeIconColor : _inactiveIconColor,
        errorBuilder: (ctx, err, stack) => Icon(
          fallback,
          size: _iconSize,
          color: isSelected ? _activeIconColor : _inactiveIconColor,
        ),
      ),
    );
  }

  Widget _buildProfileIcon(bool isSelected) {
    final hasProfileImage =
        profileImageUrl != null && profileImageUrl!.trim().isNotEmpty;
    return Container(
      width: _iconSize,
      height: _iconSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: isSelected ? Border.all(color: Colors.white, width: 1.2) : null,
      ),
      child: ClipOval(
        child: hasProfileImage
            ? Image.network(
                profileImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) => Image.asset(
                  _NavAssets.profileDefault,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error1, stack1) => _buildIcon(
                    _NavAssets.homeUnselected,
                    Icons.person_rounded,
                    isSelected,
                  ),
                ),
              )
            : Image.asset(
                _NavAssets.profileDefault,
                fit: BoxFit.cover,
                errorBuilder: (_, error2, stack2) => _buildIcon(
                  _NavAssets.homeUnselected,
                  Icons.person_rounded,
                  isSelected,
                ),
              ),
      ),
    );
  }

  Widget _buildNavTap({
    required VoidCallback onPressed,
    required Widget child,
  }) {
    return SizedBox(
      width: 62,
      height: 62,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onPressed,
          containedInkWell: true,
          highlightShape: BoxShape.circle,
          radius: 26,
          splashColor: _splashColor,
          highlightColor: _splashColor.withValues(alpha: 0.6),
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(bool isSelected) {
    final count = unreadNotificationCount < 0 ? 0 : unreadNotificationCount;
    final showBadge = count > 0;
    final label = count > 99 ? '99+' : '$count';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Image.asset(
          isSelected
              ? _NavAssets.settingsSelected
              : _NavAssets.settingsUnselected,
          width: 25,
          height: 25,
          color: isSelected ? _activeIconColor : _inactiveIconColor,
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
                border: Border.all(color: const Color(0xFF14001F), width: 1),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: const TextStyle(
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A061E), Color(0xFF77105D), Color(0xFF6D0D45)],
          stops: [0.1, 0.62, 1.0],
        ),
        border: Border.all(
          color: const Color(0xFFDE106B).withValues(alpha: 0.2),
          width: 0.9,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4D000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 4),
          child: SizedBox(
            height: 79,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  unselectedAsset: _NavAssets.homeUnselected,
                  selectedAsset: _NavAssets.homeSelected,
                  isSelected: currentIndex == 0,
                  onTap: () => onTap(0),
                  splashColor: _splashColor,
                ),
                _NavItem(
                  unselectedAsset: _NavAssets.searchUnselected,
                  selectedAsset: _NavAssets.searchSelected,
                  isSelected: currentIndex == 1,
                  onTap: () => onTap(1),
                  splashColor: _splashColor,
                ),
                _NavItem(
                  unselectedAsset: _NavAssets.addUnselected,
                  selectedAsset: _NavAssets.addSelected,
                  isSelected: currentIndex == 2,
                  onTap: () => onTap(2),
                  splashColor: _splashColor,
                ),
                _NavItem(
                  isSelected: currentIndex == 3,
                  onTap: () => onTap(3),
                  splashColor: _splashColor,
                  customChild: _buildNotificationIcon(currentIndex == 3),
                ),
                _buildNavTap(
                  onPressed: () => onTap(4),
                  child: _buildProfileIcon(currentIndex == 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    this.unselectedAsset,
    this.selectedAsset,
    required this.isSelected,
    required this.onTap,
    required this.splashColor,
    this.customChild,
  });

  final String? unselectedAsset;
  final String? selectedAsset;
  final bool isSelected;
  final VoidCallback onTap;
  final Color splashColor;
  final Widget? customChild;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 62,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onTap,
          containedInkWell: true,
          highlightShape: BoxShape.circle,
          radius: 26,
          splashColor: splashColor,
          highlightColor: splashColor.withValues(alpha: 0.6),
          child: Center(
            child:
                customChild ??
                Image.asset(
                  isSelected ? selectedAsset! : unselectedAsset!,
                  width: 25,
                  height: 25,
                  color: isSelected
                      ? AppBottomNavigation._activeIconColor
                      : AppBottomNavigation._inactiveIconColor,
                ),
          ),
        ),
      ),
    );
  }
}
