import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../subscription/subscription_controller.dart';
import '../widgets/app_bottom_navigation.dart';
import '../../screens/home/home_reels_screen.dart';
import '../../screens/search/search_screen.dart';
import '../../screens/upload/upload_screen.dart';
import '../../screens/notifications/notification_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../features/subscription/subscription_screen.dart';

/// Main app shell: IndexedStack (0 Home, 1 Search, 2 placeholder, 3 Notifications, 4 Profile) + single bottom nav.
/// Plus (index 2): subscribers → push Upload screen; standard users → push Membership screen.
class MainNavWrapper extends StatefulWidget {
  const MainNavWrapper({super.key});

  @override
  State<MainNavWrapper> createState() => _MainNavWrapperState();
}

class _MainNavWrapperState extends State<MainNavWrapper> {
  int _currentIndex = 0;
  int _feedRefreshToken = 0;

  void _onNavTap(BuildContext context, int index) {
    if (index == 2) {
      final canUpload = context.read<SubscriptionController>().canUploadContent;
      if (canUpload) {
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const UploadScreen()))
            .then((_) {
          // Refresh feed after returning from upload (whether posted or cancelled).
          setState(() {
            _currentIndex = 0;
            _feedRefreshToken++;
          });
        });
      } else {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen()),
        );
      }
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeReelsScreen(isActive: _currentIndex == 0, refreshToken: _feedRefreshToken),
      const SearchScreen(),
      const Placeholder(), // Plus opens Upload or Membership via push; no tab content.
      const NotificationScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) => _onNavTap(context, index),
        profileImageUrl: null,
      ),
    );
  }
}
