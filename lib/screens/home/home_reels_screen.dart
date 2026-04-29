import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_colors.dart';
import '../../core/controllers/reels_controller.dart';
import '../../core/models/story_model.dart';
import '../../core/navigation/app_route_observer.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/reels_service.dart';
import '../../core/services/story_service.dart';
import '../../core/services/user_service.dart';
import '../../core/subscription/subscription_controller.dart';
import '../../core/widgets/app_feed_header.dart';
import '../../core/widgets/app_interaction_button.dart';
import '../../features/comments/widgets/comments_bottom_sheet.dart';
import '../../features/home/widgets/following_header_stories.dart';
import '../../features/story/story_upload_screen.dart';
import '../../features/story/story_viewer_screen.dart';
import '../../features/reel/widgets/download_subscription_sheet.dart';
import '../../features/reel/widgets/manage_content_preferences_sheet.dart';
import '../../features/reel/widgets/not_interested_sheet.dart';
import '../../features/reel/widgets/playback_speed_sheet.dart';
import '../../features/reel/widgets/report_sheet.dart';
import '../../features/reel/widgets/reel_more_options_sheet.dart';
import '../../features/reel/widgets/video_quality_sheet.dart';
import '../../features/reel/widgets/why_seeing_this_sheet.dart';
import '../../features/share/widgets/share_bottom_sheet.dart';
import '../../features/vr/vr_screen.dart';
import '../profile/user_profile_screen.dart';
import '../../widgets/reel_item_widget.dart';

enum HomeTab { trending, vr, following, forYou }

class _ReelTarget {
  const _ReelTarget(this.tab, this.index);

  final HomeTab tab;
  final int index;
}

/// Main home screen: vertical reels feed with interactions.
/// Default tab: For You. Tab switch is internal state only (no new route).
class HomeReelsScreen extends StatefulWidget {
  const HomeReelsScreen({
    super.key,
    this.isActive = true,
    this.refreshToken = 0,
    this.deepLinkReelId,
    this.deepLinkNonce = 0,
  });

  /// Whether the Home tab is the currently visible bottom-nav tab.
  /// When false, reels should pause even if their page is selected.
  final bool isActive;

  /// Increment this from outside to trigger a feed reload (e.g. after upload).
  final int refreshToken;
  final String? deepLinkReelId;
  final int deepLinkNonce;

  @override
  State<HomeReelsScreen> createState() => _HomeReelsScreenState();
}

class _HomeReelsScreenState extends State<HomeReelsScreen>
    with AutomaticKeepAliveClientMixin, RouteAware, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;
  final PageController _pageController = PageController();
  final Map<HomeTab, List<List<int>>> _tabCycleOrders = {};
  final ReelsController _reelsController = ReelsController();
  final ReelsService _reelsService = ReelsService();

  int _currentIndex = 0;
  HomeTab currentTab = HomeTab.forYou;
  List<Map<String, dynamic>> _reelsForYou = [];
  List<Map<String, dynamic>> _reelsFollowing = [];
  List<Map<String, dynamic>> _reelsTrending = [];
  List<Map<String, dynamic>> _reelsVR = [];
  String? _selectedStoryId;

  // Stories
  List<StoryGroup> _storyGroups = [];
  List<StoryModel> _myStories = [];
  String _myAvatarUrl = '';

  /// True when Following tab has no followed feed but we show [For You] reels instead.
  bool get _followingUsesForYouFallback =>
      currentTab == HomeTab.following &&
      _reelsFollowing.isEmpty &&
      _reelsForYou.isNotEmpty;

  /// Reels for current tab. Rebuilt when currentTab changes; PageView uses this.
  List<Map<String, dynamic>> get _currentReels {
    switch (currentTab) {
      case HomeTab.trending:
        return _reelsTrending;
      case HomeTab.vr:
        return _reelsVR;
      case HomeTab.following:
        // No one followed (or no reels from them) → show For You so the tab isn't a black void.
        if (_reelsFollowing.isNotEmpty) return _reelsFollowing;
        return _reelsForYou;
      case HomeTab.forYou:
        return _reelsForYou;
    }
  }

  // State for likes/saves (optimistic UI)
  final Map<String, bool> _likedReels = {};
  final Map<String, bool> _savedReels = {};

  /// Cached for report / unfollow sheet (refreshed in [_loadReels]).
  List<String> _followingIds = [];

  // Playback and quality (from three-dots menu)
  String _playbackSpeedId = '1';
  String _playbackSpeedLabel = '1x (Normal)';
  String _qualityId = 'auto';
  String _qualityLabel = 'Auto (1080p HD)';
  bool _isRouteVisible = true;
  bool _isAppForeground = true;
  bool _isRouteObserverSubscribed = false;
  int _lastHandledDeepLinkNonce = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadReels();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isRouteObserverSubscribed) return;
    final route = ModalRoute.of(context);
    if (route is PageRoute<void>) {
      appRouteObserver.subscribe(this, route);
      _isRouteObserverSubscribed = true;
    }
  }

  @override
  void didUpdateWidget(HomeReelsScreen old) {
    super.didUpdateWidget(old);
    if (widget.refreshToken != old.refreshToken) {
      // Switch to For You tab and scroll to top so the new video is visible.
      _jumpPageControllerToStart();
      setState(() {
        currentTab = HomeTab.forYou;
        _currentIndex = 0;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _jumpPageControllerToStart();
        _ensurePageControllerMatchesFeed();
      });
      _loadReels();
    }
    if (widget.deepLinkNonce != old.deepLinkNonce) {
      _handleIncomingDeepLink();
    }
  }

  Future<void> _loadReels() async {
    final forYou = await _reelsService.getReelsForYou();
    final following = await _reelsService.getReelsFollowing();
    final trending = await _reelsService.getReelsTrending();
    final vr = await _reelsService.getReelsVR();
    final storyGroups = await StoryService().getActiveStoryGroups();
    final myStories = await StoryService().getMyStories();
    final uid = AuthService().currentUser?.uid ?? '';
    String avatarUrl = '';
    var followingIds = <String>[];
    var blockedIds = <String>[];
    if (uid.isNotEmpty) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        avatarUrl = userDoc.data()?['profileImage'] as String? ?? '';
      } catch (_) {}
      followingIds = await UserService().getFollowing(uid);
      blockedIds = await UserService().getBlockedUserIds(uid);
    }
    bool allowedByBlock(Map<String, dynamic> r) {
      final id = (r['userId'] as String?) ?? '';
      if (id.isEmpty) return true;
      return !blockedIds.contains(id);
    }

    final filteredForYou = forYou.where(allowedByBlock).toList();
    final filteredFollowing = following.where(allowedByBlock).toList();
    final filteredTrending = trending.where(allowedByBlock).toList();
    final filteredVr = vr.where(allowedByBlock).toList();
    final reelUserIds = <String>{
      ...filteredForYou.map((r) => (r['userId'] as String?) ?? ''),
      ...filteredFollowing.map((r) => (r['userId'] as String?) ?? ''),
      ...filteredTrending.map((r) => (r['userId'] as String?) ?? ''),
      ...filteredVr.map((r) => (r['userId'] as String?) ?? ''),
    }..removeWhere((id) => id.isEmpty);
    final latestAvatarByUid = await _fetchLatestProfileImages(reelUserIds);
    final filteredStories = storyGroups
        .where((g) => !blockedIds.contains(g.userId))
        .toList();
    final reelIds = <String>{
      ...filteredForYou.map((r) => (r['id'] as String?) ?? ''),
      ...filteredFollowing.map((r) => (r['id'] as String?) ?? ''),
      ...filteredTrending.map((r) => (r['id'] as String?) ?? ''),
      ...filteredVr.map((r) => (r['id'] as String?) ?? ''),
    }..removeWhere((id) => id.isEmpty);
    final likedIds = await _reelsController.getLikedReelIds(reelIds);
    final savedIds = await _reelsController.getSavedReelIds(reelIds);
    final saveCounts = await _reelsController.getSaveCountsByReelIds(reelIds);
    if (mounted) {
      setState(() {
        List<Map<String, dynamic>> withSaveCounts(List<Map<String, dynamic>> src) {
          return src.map((r) {
            final id = (r['id'] as String?) ?? '';
            if (id.isEmpty) return r;
            final remoteCount = saveCounts[id];
            final cloned = Map<String, dynamic>.from(r);
            final reelUid = (cloned['userId'] as String?) ?? '';
            final latestAvatar = latestAvatarByUid[reelUid];
            if (latestAvatar != null && latestAvatar.isNotEmpty) {
              cloned['avatarUrl'] = latestAvatar;
              cloned['profileImage'] = latestAvatar;
            }
            if (remoteCount != null) {
              cloned['saves'] = remoteCount;
            }
            return cloned;
          }).toList();
        }
        // Always assign so empty API results clear lists (avoids stale / black feed).
        _reelsForYou = withSaveCounts(filteredForYou);
        _reelsFollowing = withSaveCounts(filteredFollowing);
        if (filteredTrending.isNotEmpty) {
          _reelsTrending = withSaveCounts(filteredTrending);
        }
        if (filteredVr.isNotEmpty) _reelsVR = withSaveCounts(filteredVr);
        _storyGroups = filteredStories;
        _myStories = myStories;
        _myAvatarUrl = avatarUrl;
        _followingIds = followingIds;
        _tabCycleOrders.clear();
        _likedReels
          ..clear()
          ..addEntries(likedIds.map((id) => MapEntry(id, true)));
        _savedReels
          ..clear()
          ..addEntries(savedIds.map((id) => MapEntry(id, true)));
      });
      _handleIncomingDeepLink();
    }
  }

  Future<Map<String, String>> _fetchLatestProfileImages(Set<String> userIds) async {
    if (userIds.isEmpty) return const <String, String>{};
    final out = <String, String>{};
    final ids = userIds.toList(growable: false);
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, (i + 10) > ids.length ? ids.length : (i + 10));
      try {
        final q = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final d in q.docs) {
          final image = (d.data()['profileImage'] as String?)?.trim() ?? '';
          if (image.isNotEmpty) {
            out[d.id] = image;
          }
        }
      } catch (_) {
        // Ignore lookup failures and keep feed fallback avatars.
      }
    }
    return out;
  }

  Future<void> _handleIncomingDeepLink() async {
    if (_lastHandledDeepLinkNonce == widget.deepLinkNonce) return;
    final reelId = widget.deepLinkReelId;
    if (reelId == null || reelId.isEmpty) return;
    var target = _findReelTarget(reelId);
    if (target == null) {
      final fetched = await _reelsService.getReelById(reelId);
      if (!mounted) return;
      if (fetched != null) {
        setState(() {
          final exists = _reelsForYou.any((r) => r['id'] == reelId);
          if (!exists) {
            _reelsForYou = [fetched, ..._reelsForYou];
          }
        });
        target = _findReelTarget(reelId);
      }
    }
    _lastHandledDeepLinkNonce = widget.deepLinkNonce;
    if (target == null) return;
    final resolvedTarget = target;
    setState(() {
      currentTab = resolvedTarget.tab;
      _currentIndex = resolvedTarget.index;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(resolvedTarget.index);
      }
    });
  }

  _ReelTarget? _findReelTarget(String reelId) {
    int idx = _reelsForYou.indexWhere((r) => r['id'] == reelId);
    if (idx >= 0) return _ReelTarget(HomeTab.forYou, idx);

    idx = _reelsFollowing.indexWhere((r) => r['id'] == reelId);
    if (idx >= 0) return _ReelTarget(HomeTab.following, idx);

    idx = _reelsTrending.indexWhere((r) => r['id'] == reelId);
    if (idx >= 0) return _ReelTarget(HomeTab.trending, idx);

    idx = _reelsVR.indexWhere((r) => r['id'] == reelId);
    if (idx >= 0) return _ReelTarget(HomeTab.vr, idx);

    return null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_isRouteObserverSubscribed) {
      appRouteObserver.unsubscribe(this);
      _isRouteObserverSubscribed = false;
    }
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    if (!_isRouteVisible && mounted) return;
    if (mounted) setState(() => _isRouteVisible = false);
  }

  @override
  void didPopNext() {
    if (_isRouteVisible && mounted) return;
    if (mounted) setState(() => _isRouteVisible = true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _isAppForeground) return;
    if (mounted) {
      setState(() => _isAppForeground = foreground);
    } else {
      _isAppForeground = foreground;
    }
  }

  int _feedIndexForPage(int pageIndex, int reelCount) {
    if (reelCount <= 0) return 0;
    final cycle = pageIndex ~/ reelCount;
    final position = pageIndex % reelCount;
    final order = _cycleOrderForTab(currentTab, reelCount, cycle);
    return order[position];
  }

  List<int> _cycleOrderForTab(HomeTab tab, int reelCount, int cycle) {
    final cycles = _tabCycleOrders.putIfAbsent(tab, () => <List<int>>[]);
    while (cycles.length <= cycle) {
      if (cycles.isEmpty) {
        cycles.add(List<int>.generate(reelCount, (i) => i));
        continue;
      }
      final shuffled = List<int>.generate(reelCount, (i) => i)..shuffle();
      if (reelCount > 1) {
        final previousLast = cycles.last.last;
        if (shuffled.first == previousLast) {
          final swapIndex = shuffled.indexWhere((value) => value != previousLast);
          if (swapIndex > 0) {
            final tmp = shuffled[0];
            shuffled[0] = shuffled[swapIndex];
            shuffled[swapIndex] = tmp;
          }
        }
      }
      cycles.add(shuffled);
    }
    return cycles[cycle];
  }

  Map<String, dynamic>? _currentFeedReel() {
    final reels = _currentReels;
    if (reels.isEmpty) return null;
    return reels[_feedIndexForPage(_currentIndex, reels.length)];
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    if (_currentReels.isNotEmpty) {
      final feedIndex = _feedIndexForPage(index, _currentReels.length);
      _reelsController.incrementView(
        reelId: _currentReels[feedIndex]['id'] as String,
      );
    }
  }

  Future<void> _onLike(String reelId, bool currentlyLiked) async {
    final newState = await _reelsController.likeReel(
      reelId: reelId,
      currentlyLiked: currentlyLiked,
    );
    if (!mounted) return;
    final delta = newState == currentlyLiked ? 0 : (newState ? 1 : -1);
    setState(() {
      _likedReels[reelId] = newState;
      if (delta != 0) {
        _adjustReelStat(reelId, 'likes', delta);
      }
    });
  }

  Future<void> _onSave(String reelId, bool currentlySaved) async {
    final newState = await _reelsController.saveReel(
      reelId: reelId,
      currentlySaved: currentlySaved,
    );
    if (!mounted) return;
    final delta = newState == currentlySaved ? 0 : (newState ? 1 : -1);
    setState(() {
      _savedReels[reelId] = newState;
      if (delta != 0) {
        _adjustReelStat(reelId, 'saves', delta);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newState ? 'Saved to profile' : 'Removed from saved'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  void _onShare(String reelId) {
    final reel = _currentReels.isEmpty
        ? null
        : _currentReels[_feedIndexForPage(_currentIndex, _currentReels.length)];
    showShareBottomSheet(
      context,
      reelId: reelId,
      authorName: reel?['username'] as String?,
      thumbnailUrl: reel?['thumbnailUrl'] as String?,
      onShareViaNative: () => _reelsController.shareReel(reelId: reelId),
      onCopyLink: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Link copied to clipboard'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  void _onComment(String reelId) {
    showCommentsBottomSheet(
      context,
      reelId: reelId,
      onCommentCountChanged: (delta) => _bumpReelCommentCount(reelId, delta),
    );
  }

  void _bumpReelCommentCount(String reelId, int delta) {
    if (delta == 0 || !mounted) return;
    void bump(List<Map<String, dynamic>> list) {
      for (var i = 0; i < list.length; i++) {
        if (list[i]['id'] != reelId) continue;
        final cur = (list[i]['comments'] as num?)?.toInt() ?? 0;
        final next = (cur + delta).clamp(0, 999999999);
        list[i] = Map<String, dynamic>.from(list[i])..['comments'] = next;
        break;
      }
    }

    setState(() {
      bump(_reelsForYou);
      bump(_reelsFollowing);
      bump(_reelsTrending);
      bump(_reelsVR);
    });
  }

  void _adjustReelStat(String reelId, String key, int delta) {
    void bump(List<Map<String, dynamic>> list) {
      for (var i = 0; i < list.length; i++) {
        if (list[i]['id'] != reelId) continue;
        final cur = (list[i][key] as num?)?.toInt() ?? 0;
        final next = (cur + delta).clamp(0, 999999999);
        list[i] = Map<String, dynamic>.from(list[i])..[key] = next;
        break;
      }
    }

    bump(_reelsForYou);
    bump(_reelsFollowing);
    bump(_reelsTrending);
    bump(_reelsVR);
  }

  /// While the *previous* tab's [PageView] is still mounted, force page 0 so the
  /// controller index is never out of range on the next tab's [itemCount] (which
  /// caused a blank/black viewport when switching e.g. For You → Following).
  void _jumpPageControllerToStart() {
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  void _ensurePageControllerMatchesFeed() {
    if (!_pageController.hasClients) return;
    final len = _currentReels.length;
    if (len == 0) return;
    final raw = _pageController.page?.round() ?? _currentIndex;
    final safe = raw.clamp(0, len - 1);
    if (safe != raw) {
      _pageController.jumpToPage(safe);
      if (mounted) setState(() => _currentIndex = safe);
    }
  }

  void _onTabChanged(HomeTab tab) {
    if (tab == HomeTab.vr) {
      final hasVrAccess = context.read<SubscriptionController>().hasVRAccess;
      if (!hasVrAccess) {
        final bg = _currentFeedReel()?['thumbnailUrl'] as String?;
        showVrLockedOverlaySheet(context, backgroundImageUrl: bg);
        return;
      }
    }
    _jumpPageControllerToStart();
    setState(() {
      currentTab = tab;
      _currentIndex = 0;
    });
    if (tab != HomeTab.vr) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || currentTab != tab) return;
        _jumpPageControllerToStart();
        _ensurePageControllerMatchesFeed();
      });
    }
  }

  // void _onVideoTap() {
  //   // Controls are now handled internally by ReelItemWidget
  // }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isVrTab = currentTab == HomeTab.vr;
    final isFollowing = currentTab == HomeTab.following;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: (isFollowing || isVrTab)
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF49113B), // Dark magenta
                    Color(0xFF000000),
                  ],
                )
              : null,
        ),
        child: Stack(
          children: [
            if (isVrTab)
              Positioned.fill(
                top: 110, // Just below header
                child: _buildVrContent(),
              )
            else
              Positioned.fill(
                top: isFollowing ? 220 : 0, // Push video down for stories
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isFollowing ? 8 : 0,
                    vertical: isFollowing ? 8 : 0,
                  ),
                  child: _buildFeedClipArea(isFollowing),
                ),
              ),
            _buildHeader(),
            if (isFollowing) _buildStoryRow(),
            if (!isVrTab) ...[
              _buildInteractionButtons(),
              _buildBottomUserInfo(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVrContent() {
    return Consumer<SubscriptionController>(
      builder: (context, subscriptionController, _) {
        if (!subscriptionController.hasVRAccess) {
          return const VrLockedView();
        }
        return const VrGridView();
      },
    );
  }

  void _openStoryViewer(int groupIndex) {
    if (_storyGroups.isEmpty) return;
    final uid = AuthService().currentUser?.uid ?? '';
    final group = _storyGroups[groupIndex];
    final initialStoryIndex = uid.isEmpty
        ? 0
        : group.stories.indexWhere((s) => !s.isViewedBy(uid));
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => StoryViewerScreen(
          groups: _storyGroups,
          initialGroupIndex: groupIndex,
          initialStoryIndex: initialStoryIndex == -1 ? 0 : initialStoryIndex,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  Future<void> _openStoryUpload() async {
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const StoryUploadScreen()),
    );
    if (posted == true) _loadReels();
  }

  Future<void> _handleMyStoryTap() async {
    final uid = AuthService().currentUser?.uid ?? '';
    final myGroupIdx = _storyGroups.indexWhere((g) => g.userId == uid);
    if (myGroupIdx != -1) {
      _openStoryViewer(myGroupIdx);
      return;
    }
    await _openStoryUpload();
  }

  Widget _buildStoryRow() {
    final uid = AuthService().currentUser?.uid ?? '';
    final otherGroups = _storyGroups.where((g) => g.userId != uid).toList();

    final stories = otherGroups
        .map(
          (g) => {
            'id': g.userId,
            'profileImage': g.avatarUrl,
            'avatarUrl': g.avatarUrl,
            'username': g.username,
          },
        )
        .toList();

    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: FollowingHeaderStories(
        stories: stories,
        selectedId: _selectedStoryId,
        onStoryTap: (userId) {
          setState(() => _selectedStoryId = userId);
          final idx = _storyGroups.indexWhere((g) => g.userId == userId);
          if (idx != -1) _openStoryViewer(idx);
        },
        myAvatarUrl: _myAvatarUrl,
        myHasStory: _myStories.isNotEmpty,
        onAddStory: _handleMyStoryTap,
      ),
    );
  }

  /// Rounded feed; when Following has no followed content, a banner + [For You] fallback.
  Widget _buildFeedClipArea(bool isFollowingTab) {
    final radius = BorderRadius.circular(isFollowingTab ? 24 : 0);
    final feed = ClipRRect(borderRadius: radius, child: _buildReelsFeed());
    if (isFollowingTab && _followingUsesForYouFallback) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFollowingFallbackBanner(),
          const SizedBox(height: 8),
          Expanded(child: feed),
        ],
      );
    }
    return feed;
  }

  Widget _buildFollowingFallbackBanner() {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.people_outline_rounded,
              color: Colors.white.withValues(alpha: 0.85),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "You're not following anyone yet, or they have no reels. Showing For You for now.",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReelsFeed() {
    final reels = _currentReels;
    if (reels.isEmpty) {
      return _buildEmptyReelsPlaceholder();
    }
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      onPageChanged: _onPageChanged,
      itemCount: reels.length,
      itemBuilder: (context, index) {
        final feedIndex = index;
        final reel = reels[feedIndex];
        final mediaType =
            ((reel['mediaType'] as String?) ?? 'video').toLowerCase();
        if (mediaType == 'image') {
          final imageUrl = ((reel['imageUrl'] as String?) ?? '').trim();
          final thumbnailUrl = ((reel['thumbnailUrl'] as String?) ?? '').trim();
          final displayUrl = imageUrl.isNotEmpty ? imageUrl : thumbnailUrl;
          if (displayUrl.isEmpty) {
            return _buildMissingMediaPlaceholder('This reel has no image URL.');
          }
          return _buildImageReelItem(displayUrl);
        }
        final videoUrl = (reel['videoUrl'] as String?)?.trim() ?? '';
        if (videoUrl.isEmpty) {
          return _buildMissingMediaPlaceholder('This reel has no video URL.');
        }
        final thumbnailUrl = ((reel['thumbnailUrl'] as String?) ?? '').trim();
        final imageUrl = ((reel['imageUrl'] as String?) ?? '').trim();
        final loadingThumb = thumbnailUrl.isNotEmpty ? thumbnailUrl : imageUrl;
        return ReelItemWidget(
          key: ValueKey<String>((reel['id'] as String?) ?? videoUrl),
          videoUrl: videoUrl,
          thumbnailUrl: loadingThumb,
          // Only play when this page is visible AND the home tab is active.
          isVisible: widget.isActive &&
              _isRouteVisible &&
              _isAppForeground &&
              index == _currentIndex,
        );
      },
    );
  }

  Widget _buildImageReelItem(String imageUrl) {
    return SizedBox.expand(
      child: ColoredBox(
        color: Colors.black,
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 4.0,
          child: Center(
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return _buildMissingMediaPlaceholder(
                  'Failed to load image reel.',
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMissingMediaPlaceholder(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyReelsPlaceholder() {
    final (String title, String subtitle, IconData icon) = switch (currentTab) {
      HomeTab.following => (
        'Nothing here yet',
        _reelsForYou.isEmpty
            ? 'Follow creators to see their reels here. For You is empty too—check back after content is added.'
            : 'Follow creators to see their reels here. (For You will fill this tab until you do.)',
        Icons.people_outline_rounded,
      ),
      HomeTab.trending => (
        'No trending reels',
        'Check back soon or try For You.',
        Icons.trending_up_rounded,
      ),
      HomeTab.forYou => (
        'No reels to show',
        'Pull to refresh later or check your connection.',
        Icons.play_circle_outline_rounded,
      ),
      HomeTab.vr => ('No reels', '', Icons.video_library_outlined),
    };

    return SizedBox.expand(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: Colors.white.withValues(alpha: 0.35)),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ],
              if (currentTab == HomeTab.following) ...[
                const SizedBox(height: 24),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brandPink,
                  ),
                  onPressed: () => _onTabChanged(HomeTab.forYou),
                  child: const Text(
                    'Browse For You',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: AppFeedHeader(
          selectedIndex: currentTab.index,
          onTabSelected: (index) => _onTabChanged(HomeTab.values[index]),
        ),
      ),
    );
  }

  Widget _buildInteractionButtons() {
    final reel = _currentFeedReel();
    if (reel == null) return const SizedBox.shrink();
    final reelId = reel['id'] as String;
    final isLiked = _likedReels[reelId] ?? false;
    final isSaved = _savedReels[reelId] ?? false;
    final bottomSafeInset = MediaQuery.paddingOf(context).bottom;
    // Keep action stack clearly above the bottom nav bar.
    final interactionBottom = 84.0 + bottomSafeInset;

    return Positioned(
      right: 16,
      bottom: interactionBottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppInteractionButton(
            icon: Icons.visibility_outlined,
            count: _formatCount(reel['views'] as int),
            iconSize: 24,
            textSize: 10,
            spacing: 3,
          ),
          const SizedBox(height: 12),
          AppInteractionButton(
            icon: isLiked ? Icons.favorite : Icons.favorite_border,
            count: _formatCount(reel['likes'] as int),
            isActive: isLiked,
            activeColor: const Color(0xFFEF4444),
            onTap: () => _onLike(reelId, isLiked),
            iconSize: 24,
            textSize: 10,
            spacing: 3,
          ),
          const SizedBox(height: 12),
          AppInteractionButton(
            icon: Icons.chat_bubble_outline,
            count: _formatCount(reel['comments'] as int),
            onTap: () => _onComment(reelId),
            iconSize: 24,
            textSize: 10,
            spacing: 3,
          ),
          const SizedBox(height: 12),
          AppInteractionButton(
            icon: isSaved ? Icons.star : Icons.star_border,
            count: _formatCount(reel['saves'] as int),
            isActive: isSaved,
            activeColor: const Color(0xFFFFD700),
            onTap: () => _onSave(reelId, isSaved),
            iconSize: 24,
            textSize: 10,
            spacing: 3,
          ),
          const SizedBox(height: 12),
          AppInteractionButton(
            icon: Icons.reply,
            count: _formatCount(reel['shares'] as int),
            onTap: () => _onShare(reelId),
            iconSize: 24,
            textSize: 10,
            spacing: 3,
          ),
          const SizedBox(height: 12),
          AppInteractionButton(
            icon: Icons.more_horiz,
            count: '',
            onTap: () => _onMoreOptions(reelId), 
            iconSize: 24,
          ),
        ],
      ),
    );
  }

  void _onMoreOptions(String reelId) {
    final reel = _currentReels.firstWhere((r) => r['id'] == reelId);
    final authorId = reel['userId'] as String? ?? '';
    showReelMoreOptionsSheet(
      context,
      reelId: reelId,
      playbackSpeed: _playbackSpeedLabel,
      quality: _qualityLabel,
      onDownload: _onDownloadTapped,
      onReport: () => showReportSheet(
        context,
        username: reel['username'] as String,
        avatarUrl: reel['avatarUrl'] as String,
        targetUserId: authorId.isEmpty ? null : authorId,
        isFollowing: authorId.isNotEmpty && _followingIds.contains(authorId),
      ),
      onNotInterested: () => showNotInterestedSheet(context),
      onCaptions: () => _showSnackBar('Captions'),
      onPlaybackSpeed: _openPlaybackSpeedSheet,
      onQuality: _openVideoQualitySheet,
      onManagePreferences: () => showManageContentPreferencesSheet(context),
      onWhyThisPost: () => showWhySeeingThisSheet(context),
    );
  }

  void _onDownloadTapped() {
    final subscriptionController = context.read<SubscriptionController>();
    if (subscriptionController.isSubscriber ||
        subscriptionController.isCreator) {
      _showSnackBar('Download started');
    } else {
      showDownloadSubscriptionSheet(context);
    }
  }

  void _openPlaybackSpeedSheet() {
    showPlaybackSpeedSheet(
      context,
      selectedId: _playbackSpeedId,
      onSelected: (id, label) {
        setState(() {
          _playbackSpeedId = id;
          _playbackSpeedLabel = label;
        });
        _showSnackBar('Playback speed: $label');
      },
    );
  }

  void _openVideoQualitySheet() {
    showVideoQualitySheet(
      context,
      selectedId: _qualityId,
      onSelected: (id, label) {
        setState(() {
          _qualityId = id;
          _qualityLabel = id == 'auto' ? 'Auto (1080p HD)' : label;
        });
        _showSnackBar('Quality: $_qualityLabel');
      },
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Widget _buildBottomUserInfo() {
    final reel = _currentFeedReel();
    if (reel == null) return const SizedBox.shrink();

    return Positioned(
      left: 16,
      right: 80,
      bottom: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _openReelAuthorProfile(reel),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[900],
                    backgroundImage: _isValidNetworkUrl(
                            reel['avatarUrl'] as String?)
                        ? NetworkImage((reel['avatarUrl'] as String).trim())
                        : null,
                    onBackgroundImageError: (_, __) {},
                    child: !_isValidNetworkUrl(reel['avatarUrl'] as String?)
                        ? const Icon(Icons.person, color: Colors.white, size: 20)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _openReelAuthorProfile(reel),
                          child: Text(
                            reel['username'] as String,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => _openReelAuthorProfile(reel),
                      child: Text(
                        reel['handle'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CaptionWithSeeMore(
            text: reel['caption'] as String,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // bool _isVideoPlaying() {
  //   // Placeholder - check actual player state from ReelItemWidget if needed
  //   return true;
  // }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  bool _isValidNetworkUrl(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.isAbsolute || uri.host.isEmpty) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  void _openReelAuthorProfile(Map<String, dynamic> reel) {
    final rawHandle = (reel['handle'] as String? ?? '').trim();
    final normalizedUsername = rawHandle.replaceFirst('@', '').trim();
    final fallbackName = (reel['username'] as String? ?? '').trim();
    final avatar = (reel['avatarUrl'] as String? ?? '').trim();
    final targetUid = (reel['userId'] as String? ?? '').trim();
    final isFollowing = targetUid.isNotEmpty && _followingIds.contains(targetUid);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfileScreen(
          payload: UserProfilePayload(
            username: normalizedUsername.isNotEmpty ? normalizedUsername : fallbackName,
            displayName: fallbackName.isNotEmpty ? fallbackName : normalizedUsername,
            avatarUrl: avatar,
            isVerified: (reel['isVerified'] as bool?) ?? false,
            accountType: (reel['accountType'] as String?) ?? 'personal',
            vipVerified: (reel['vipVerified'] as bool?) ?? false,
            postCount: 0,
            followerCount: 0,
            followingCount: 0,
            bio: '',
            isCreator: true,
            isFollowing: isFollowing,
            targetUserId: targetUid.isNotEmpty ? targetUid : null,
          ),
        ),
      ),
    );
  }
}

class _CaptionWithSeeMore extends StatefulWidget {
  const _CaptionWithSeeMore({required this.text});

  final String text;

  @override
  State<_CaptionWithSeeMore> createState() => _CaptionWithSeeMoreState();
}

class _CaptionWithSeeMoreState extends State<_CaptionWithSeeMore> {
  bool _expanded = false;

  static const _captionStyle = TextStyle(
    fontSize: 15,
    color: Colors.white,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  bool _isOverflowing(String text, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _captionStyle),
      maxLines: 2,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final caption = widget.text.trim();
    if (caption.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasOverflow = _isOverflowing(caption, constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              caption,
              maxLines: _expanded ? null : 2,
              overflow: TextOverflow.clip,
              style: _captionStyle,
            ),
            if (hasOverflow && !_expanded) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => setState(() => _expanded = true),
                child: Text(
                  'See More',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
