import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import '../services/deep_link_service.dart';
import '../services/user_service.dart';
import '../subscription/subscription_controller.dart';
import '../widgets/app_bottom_navigation.dart';
import '../../screens/home/home_reels_screen.dart';
import '../../screens/search/search_screen.dart';
import '../../screens/upload/upload_screen.dart';
import '../../screens/notifications/notification_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/profile/user_profile_screen.dart';
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
  int _deepLinkNonce = 0;
  String? _deepLinkedReelId;
  final UserService _userService = UserService();
  StreamSubscription<String>? _reelDeepLinkSub;
  StreamSubscription<String>? _profileDeepLinkSub;

  @override
  void initState() {
    super.initState();
    final pending = DeepLinkService.instance.takePendingReelId();
    if (pending != null && pending.isNotEmpty) {
      _deepLinkedReelId = pending;
      _deepLinkNonce = 1;
      _currentIndex = 0;
    }
    _reelDeepLinkSub = DeepLinkService.instance.reelLinkStream.listen((reelId) {
      if (!mounted) return;
      setState(() {
        _currentIndex = 0;
        _deepLinkedReelId = reelId;
        _deepLinkNonce++;
      });
    });
    final pendingProfile = DeepLinkService.instance.takePendingProfileRef();
    if (pendingProfile != null && pendingProfile.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openProfileFromDeepLink(pendingProfile);
      });
    }
    _profileDeepLinkSub = DeepLinkService.instance.profileLinkStream.listen((
      profileRef,
    ) {
      if (!mounted) return;
      _openProfileFromDeepLink(profileRef);
    });
  }

  @override
  void dispose() {
    _reelDeepLinkSub?.cancel();
    _profileDeepLinkSub?.cancel();
    super.dispose();
  }

  Future<void> _openProfileFromDeepLink(String profileRef) async {
    final ref = profileRef.trim();
    if (ref.isEmpty) return;
    final appUser =
        await _userService.getUser(ref) ??
        await _userService.getUserByUsername(ref);
    if (!mounted || appUser == null) return;
    final followerCount = await _userService.getFollowerCount(appUser.uid);
    final postCount = await _userService.getReelCountForUser(appUser.uid);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfileScreen(
          payload: UserProfilePayload(
            username: appUser.username ?? '',
            displayName: appUser.displayName ?? appUser.username ?? 'User',
            avatarUrl: appUser.profileImage ?? '',
            isVerified: false,
            postCount: postCount,
            followerCount: followerCount,
            followingCount: appUser.following.length,
            bio: appUser.bio ?? '',
            isCreator: true,
            isFollowing: false,
            targetUserId: appUser.uid,
          ),
        ),
      ),
    );
  }

  Future<void> _onNavTap(int index) async {
    if (index == 2) {
      final subscriptionController = context.read<SubscriptionController>();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final canUpload = await subscriptionController.reconcilePaidStatus(
        firebaseUid: uid,
      );
      if (!mounted) return;
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
        if (!mounted) return;
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
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final screens = <Widget>[
      HomeReelsScreen(
        isActive: _currentIndex == 0,
        refreshToken: _feedRefreshToken,
        deepLinkReelId: _deepLinkedReelId,
        deepLinkNonce: _deepLinkNonce,
      ),
      const SearchScreen(),
      const Placeholder(), // Plus opens Upload or Membership via push; no tab content.
      const NotificationScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: StreamBuilder(
        stream: uid.isEmpty ? null : _userService.userStream(uid),
        builder: (context, snapshot) {
          final profileImageUrl = snapshot.data?.profileImage;
          return AppBottomNavigation(
            currentIndex: _currentIndex,
            onTap: _onNavTap,
            profileImageUrl: profileImageUrl,
          );
        },
      ),
    );
  }
}
