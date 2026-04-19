import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _NavAssets {
  static const _base = 'assets/vyooO_icons/Home/nav_bar_icons';
  static const homeSelected = '$_base/home.png';
  static const homeUnselected = 'assets/BottomNavBar/HomeUnSlected.png';
  static const searchSelected = '$_base/search_filled.png';
  static const searchUnselected = '$_base/search.png';
  static const addSelected = '$_base/create.png';
  static const addUnselected = '$_base/create.png';
  static const profileUnselected = '$_base/profile.png';
  static const settingsSelected = '$_base/notification_filled.png';
  static const settingsUnselected = '$_base/notifications.png';
}

/// Standard BottomNavigationBar wrapper.
/// Index: 0 Home, 1 Search, 2 Create (+), 3 Settings (as Notifications), 4 Profile.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.profileImageUrl,
  });

  final int currentIndex;
  final void Function(int) onTap;
  final String? profileImageUrl;

  static const double _iconSize = 24;

  Widget _buildIcon(String asset, IconData fallback, bool isSelected) {
    return SizedBox(
      width: _iconSize,
      height: _iconSize,
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
        errorBuilder: (ctx, err, stack) => Icon(
          fallback,
          size: _iconSize,
          color: isSelected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildProfileIcon(bool isSelected) {
    return Container(
      width: _iconSize + 2,
      height: _iconSize + 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: isSelected ? Border.all(color: Colors.white, width: 1.5) : null,
      ),
      child: Center(
        child: _buildIcon(
          _NavAssets.profileUnselected,
          Icons.person_rounded,
          isSelected,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                unselectedAsset: _NavAssets.homeUnselected,
                selectedAsset: _NavAssets.homeSelected,
                isSelected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                unselectedAsset: _NavAssets.searchUnselected,
                selectedAsset: _NavAssets.searchSelected,
                isSelected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                unselectedAsset: _NavAssets.addUnselected,
                selectedAsset: _NavAssets.addSelected,
                isSelected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                unselectedAsset: _NavAssets.settingsUnselected,
                selectedAsset: _NavAssets.settingsSelected,
                isSelected: currentIndex == 3,
                onTap: () => onTap(3),
              ),
              GestureDetector(
                onTap: () => onTap(4),
                child: _buildProfileIcon(currentIndex == 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.unselectedAsset,
    required this.selectedAsset,
    required this.isSelected,
    required this.onTap,
  });

  final String unselectedAsset;
  final String selectedAsset;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        height: 60,
        child: Center(
          child: Image.asset(
            isSelected ? selectedAsset : unselectedAsset,
            width: 24,
            height: 24,
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
