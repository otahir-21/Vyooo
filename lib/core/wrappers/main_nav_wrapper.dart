import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import '../navigation/home_feed_chrome_controller.dart';
import '../services/deep_link_service.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import '../widgets/app_bottom_navigation.dart';
import '../../screens/home/home_reels_screen.dart';
import '../navigation/search_tab_launcher.dart';
import '../../screens/search/search_screen.dart';
import '../../screens/broadcast/broadcast_tab_host.dart';
import '../../screens/upload/upload_screen.dart';
import '../../features/chat/screens/chat_inbox_screen.dart';
import '../../features/chat/services/chat_service.dart';
import '../../features/chat/services/chat_notification_service.dart';
import '../../features/chat/services/presence_service.dart';
import '../../screens/profile/profile_figma_tokens.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/profile/user_profile_screen.dart';

/// Main app shell: IndexedStack (0 Home, 1 Broadcast, 2 placeholder, 3 Messages, 4 Profile) + single bottom nav.
/// Plus (index 2): push Upload screen. Search opens as a pushed route from home / hashtags.
class MainNavWrapper extends StatefulWidget {
  const MainNavWrapper({super.key, this.initialIndex});

  final int? initialIndex;

  static final ValueNotifier<int?> tabNotifier = ValueNotifier<int?>(null);

  /// Same navigation path as tapping a bottom-nav item (except index 2 → Upload push).
  static void switchToTab(int index) {
    final safe = index.clamp(0, 4);
    if (tabNotifier.value == safe) {
      tabNotifier.value = null;
    }
    tabNotifier.value = safe;
  }

  /// Opens the Search tab (index 1) — identical to the bottom-nav search item.
  static void openSearchTab() => switchToTab(1);

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
  late final SearchTabLaunchCallback _searchTabLaunchHandler;
  final HomeFeedChromeController _homeFeedChrome = HomeFeedChromeController();
  final HomeFeedChromeController _broadcastFeedChrome = HomeFeedChromeController();

  void _onTabNotifierChanged() {
    final v = MainNavWrapper.tabNotifier.value;
    if (v != null && mounted) {
      MainNavWrapper.tabNotifier.value = null;
      if (v == 1) {
        _openSearchScreen();
        return;
      }
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
      _openSearchScreen(
        query: query,
        categoryTabIndex: categoryTabIndex,
      );
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
    _homeFeedChrome.dispose();
    _broadcastFeedChrome.dispose();
    super.dispose();
  }

  Future<void> _openProfileFromDeepLink(String profileRef) async {
    final ref = profileRef.trim();
    if (ref.isEmpty) return;
    final appUser =
        await _userService.getUser(ref) ??
        await _userService.getUserByUsername(ref);
    if (!mounted) return;
    if (appUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This profile is no longer available.')),
      );
      return;
    }
    final followerCount = await _userService.getFollowerCount(appUser.uid);
    final postCount = await _userService.getReelCountForUser(appUser.uid);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfileScreen(
          payload: UserProfilePayload.fromAppUser(
            appUser,
            postCount: postCount,
            followerCount: followerCount,
            followingCount: appUser.following.length,
          ),
        ),
      ),
    );
  }

  Future<void> _openSearchScreen({
    String query = '',
    int categoryTabIndex = 0,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SearchScreen(
          initialQuery: query.trim().isEmpty ? null : query.trim(),
          initialCategoryTabIndex: query.trim().isEmpty
              ? null
              : categoryTabIndex,
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
    if (index == 1) {
      setState(() {
        _currentIndex = 1;
        _lastSelectedIndex = 1;
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
        chromeController: _homeFeedChrome,
      ),
      BroadcastTabHost(
        isActive: _currentIndex == 1,
        onRequestHome: () => _onNavTap(0),
        chromeController: _broadcastFeedChrome,
      ),
      const Placeholder(), // Plus opens Upload or Membership via push; no tab content.
      const ChatInboxScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: ProfileFigmaTokens.screenBackground,
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: screens),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: StreamBuilder<int>(
              stream: NotificationService().watchUnreadCount(),
              builder: (context, unreadSnapshot) {
                final unreadCount = unreadSnapshot.data ?? 0;
                return StreamBuilder<int>(
                  stream: uid.isEmpty
                      ? null
                      : ChatService().watchTotalUnread(uid),
                  builder: (context, chatUnreadSnapshot) {
                    final chatUnread = chatUnreadSnapshot.data ?? 0;
                    return StreamBuilder(
                      stream: uid.isEmpty
                          ? null
                          : _userService.userStream(uid),
                      builder: (context, snapshot) {
                        final profileImageUrl = snapshot.data?.profileImage;
                        return ValueListenableBuilder<double?>(
                          valueListenable: _homeFeedChrome.progress,
                          builder: (context, homeProgress, child) {
                            return ValueListenableBuilder<double?>(
                              valueListenable: _broadcastFeedChrome.progress,
                              builder: (context, liveProgress, child) {
                                final showReelProgress =
                                    _currentIndex == 0 && homeProgress != null;
                                final showLiveProgress =
                                    _currentIndex == 1 && liveProgress != null;
                                return AppBottomNavigation(
                                  currentIndex: _currentIndex,
                                  onTap: _onNavTap,
                                  profileImageUrl: profileImageUrl,
                                  unreadNotificationCount: unreadCount,
                                  unreadChatCount: chatUnread,
                                  useFeedChrome:
                                      _currentIndex == 0 || _currentIndex == 1,
                                  feedReelProgress: showReelProgress
                                      ? _homeFeedChrome.progress
                                      : null,
                                  feedLiveProgress: showLiveProgress
                                      ? _broadcastFeedChrome.progress
                                      : null,
                                  onFeedReelSeekUpdate: (fraction) {
                                    _homeFeedChrome.progress.value = fraction;
                                    _homeFeedChrome.seekFraction.value =
                                        fraction;
                                  },
                                  onFeedLiveSeekUpdate: (fraction) {
                                    _broadcastFeedChrome.progress.value =
                                        fraction;
                                    _broadcastFeedChrome.seekFraction.value =
                                        fraction;
                                  },
                                  squareChromeBottomCorners:
                                      _currentIndex == 1,
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
