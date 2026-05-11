import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import '../services/deep_link_service.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import '../widgets/app_bottom_navigation.dart';
import '../../screens/home/home_reels_screen.dart';
import '../navigation/search_tab_launcher.dart';
import '../../screens/search/search_screen.dart';
import '../../screens/upload/upload_screen.dart';
import '../../features/chat/screens/chat_inbox_screen.dart';
import '../../features/chat/services/chat_service.dart';
import '../../features/chat/services/chat_notification_service.dart';
import '../../features/chat/services/presence_service.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/profile/user_profile_screen.dart';

/// Main app shell: IndexedStack (0 Home, 1 Search, 2 placeholder, 3 Notifications, 4 Profile) + single bottom nav.
/// Plus (index 2): subscribers → push Upload screen; standard users → push Membership screen.
class MainNavWrapper extends StatefulWidget {
  const MainNavWrapper({super.key, this.initialIndex});

  final int? initialIndex;

  static final ValueNotifier<int?> tabNotifier = ValueNotifier<int?>(null);

  @override
  State<MainNavWrapper> createState() => _MainNavWrapperState();
}

class _MainNavWrapperState extends State<MainNavWrapper> {
  static int _lastSelectedIndex = 0;
  int _currentIndex = _lastSelectedIndex;
  int _feedRefreshToken = 0;
  int _deepLinkNonce = 0;
  String? _deepLinkedReelId;
  final UserService _userService = UserService();
  StreamSubscription<String>? _reelDeepLinkSub;
  StreamSubscription<String>? _profileDeepLinkSub;
  final GlobalKey<SearchScreenState> _searchScreenKey =
      GlobalKey<SearchScreenState>();
  late final SearchTabLaunchCallback _searchTabLaunchHandler;

  void _onTabNotifierChanged() {
    final v = MainNavWrapper.tabNotifier.value;
    if (v != null && mounted) {
      MainNavWrapper.tabNotifier.value = null;
      _onNavTap(v);
    }
  }

  @override
  void initState() {
    super.initState();
    MainNavWrapper.tabNotifier.addListener(_onTabNotifierChanged);
    if (widget.initialIndex != null) {
      final safe = widget.initialIndex!.clamp(0, 4);
      _currentIndex = safe;
      _lastSelectedIndex = safe;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      ChatNotificationService.instance.startForUser(uid);
      PresenceService.instance.start(uid);
    }

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
        _lastSelectedIndex = 0;
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

    _searchTabLaunchHandler = (String query, int categoryTabIndex) {
      if (!mounted) return;
      setState(() {
        _currentIndex = 1;
        _lastSelectedIndex = 1;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _searchScreenKey.currentState?.applyExternalQuery(
          query,
          categoryTabIndex,
        );
      });
    };
    SearchTabLauncher.instance.register(_searchTabLaunchHandler);
  }

  @override
  void dispose() {
    MainNavWrapper.tabNotifier.removeListener(_onTabNotifierChanged);
    SearchTabLauncher.instance.unregister(_searchTabLaunchHandler);
    _reelDeepLinkSub?.cancel();
    _profileDeepLinkSub?.cancel();
    PresenceService.instance.stop();
    ChatNotificationService.instance.stop();
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
            isVerified: appUser.isVerified,
            accountType: appUser.accountType,
            vipVerified: appUser.vipVerified,
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
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const UploadScreen()))
          .then((_) {
            if (!mounted) return;
            setState(() {
              _currentIndex = 0;
              _lastSelectedIndex = 0;
              _feedRefreshToken++;
            });
          });
      return;
    }
    setState(() {
      _currentIndex = index;
      _lastSelectedIndex = index;
    });
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
      SearchScreen(key: _searchScreenKey),
      const Placeholder(), // Plus opens Upload or Membership via push; no tab content.
      const ChatInboxScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: StreamBuilder<int>(
        stream: NotificationService().watchUnreadCount(),
        builder: (context, unreadSnapshot) {
          final unreadCount = unreadSnapshot.data ?? 0;
          return StreamBuilder<int>(
            stream: uid.isEmpty ? null : ChatService().watchTotalUnread(uid),
            builder: (context, chatUnreadSnapshot) {
              final chatUnread = chatUnreadSnapshot.data ?? 0;
              return StreamBuilder(
                stream: uid.isEmpty ? null : _userService.userStream(uid),
                builder: (context, snapshot) {
                  final profileImageUrl = snapshot.data?.profileImage;
                  return AppBottomNavigation(
                    currentIndex: _currentIndex,
                    onTap: _onNavTap,
                    profileImageUrl: profileImageUrl,
                    unreadNotificationCount: unreadCount,
                    unreadChatCount: chatUnread,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
