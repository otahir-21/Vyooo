import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:provider/provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/feed_interaction_assets.dart';
import '../../core/controllers/reels_controller.dart';
import '../../core/models/reel_count_privacy.dart';
import '../../core/models/reel_media_item.dart';
import '../../core/models/video_360_metadata.dart';
import '../../core/utils/engagement_counts.dart';
import '../../core/utils/reel_engagement.dart';
import '../../core/widgets/post_media_carousel.dart';
import '../../core/widgets/double_tap_like_overlay.dart';
import '../../core/models/story_model.dart';
import '../../core/navigation/app_route_observer.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/feed_offline_video_cache.dart';
import '../../core/services/feed_reels_cache_service.dart';
import '../../core/services/feed_warmup_service.dart';
import '../../core/services/reel_preload_service.dart';
import '../../core/services/reels_service.dart';
import '../../core/services/story_service.dart';
import '../../core/services/user_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/reel_download_service.dart';
import '../../core/subscription/subscription_controller.dart';
import '../../core/utils/internet_availability.dart';
import '../../core/utils/user_facing_errors.dart';
import '../../core/utils/verification_badge.dart';
import '../../core/theme/app_padding.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_bottom_navigation.dart';
import '../../core/wrappers/main_nav_wrapper.dart';
import '../../core/widgets/app_feed_header.dart';
import '../../core/widgets/app_feed_header_icon_button.dart';
import '../../core/widgets/app_feed_notification_button.dart';
import '../../screens/notifications/notification_screen.dart';
import '../../core/widgets/app_interaction_button.dart';
import '../../features/comments/widgets/comments_bottom_sheet.dart';
import '../../features/home/widgets/feed_reels_loading_skeleton.dart';
import '../../features/home/widgets/following_header_stories.dart';
import '../../features/home/widgets/following_stories_toggle.dart';
import '../../features/home/widgets/for_you_ai_verified_badge.dart';
import '../../features/story/story_upload_screen.dart';
import '../../features/story/story_viewer_screen.dart';
import '../../features/reel/widgets/download_subscription_sheet.dart';
import '../../features/reel/widgets/manage_content_preferences_sheet.dart';
import '../../features/reel/widgets/not_interested_sheet.dart';
import '../../features/reel/widgets/playback_speed_sheet.dart';
import '../../core/moderation/content_moderation.dart';
import '../../features/moderation/widgets/report_moderation_cover.dart';
import '../../features/reel/widgets/report_sheet.dart';
import '../../features/reel/widgets/report_status_bar.dart';
import '../../features/reel/widgets/reel_more_options_sheet.dart';
import '../../features/reel/widgets/video_quality_sheet.dart';
import '../../features/reel/widgets/why_seeing_this_sheet.dart';
import '../../features/share/widgets/share_bottom_sheet.dart';
import '../../features/vr/vr_screen.dart';
import '../profile/user_profile_screen.dart';
import '../../widgets/caption_with_hashtags.dart';
import '../../widgets/reel_item_widget.dart';

enum HomeTab { trending, vr, following, forYou }

class _ReelTarget {
  const _ReelTarget(this.tab, this.index);

  final HomeTab tab;
  final int index;
}

class _ReelAuthorFeedMeta {
  const _ReelAuthorFeedMeta({
    this.avatarUrl = '',
    this.isVerified = false,
    this.accountType = 'private',
    this.vipVerified = false,
  });

  final String avatarUrl;
  final bool isVerified;
  final String accountType;
  final bool vipVerified;
}

/// Main home screen: vertical reels feed with interactions.
/// Default tab: Trending. Tab switch is internal state only (no new route).
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
    with
        AutomaticKeepAliveClientMixin,
        RouteAware,
        WidgetsBindingObserver,
        SingleTickerProviderStateMixin {
  static const HomeTab _defaultHomeTab = HomeTab.trending;

  @override
  bool get wantKeepAlive => true;
  final PageController _pageController = PageController();
  final Map<HomeTab, List<List<int>>> _tabCycleOrders = {};
  final ReelsController _reelsController = ReelsController();
  final ReelsService _reelsService = ReelsService();

  int _currentIndex = 0;
  HomeTab currentTab = _defaultHomeTab;
  List<Map<String, dynamic>> _reelsForYou = [];
  List<Map<String, dynamic>> _reelsFollowing = [];
  List<Map<String, dynamic>> _reelsTrending = [];
  List<Map<String, dynamic>> _reelsVR = [];
  String? _selectedStoryId;

  // Stories
  List<StoryGroup> _storyGroups = [];
  List<StoryModel> _myStories = [];
  String _myAvatarUrl = '';

  /// Reels for current tab. Rebuilt when currentTab changes; PageView uses this.
  List<Map<String, dynamic>> get _currentReels {
    switch (currentTab) {
      case HomeTab.trending:
        return _reelsTrending;
      case HomeTab.vr:
        return _reelsVR;
      case HomeTab.following:
        return _followingFeedReels;
      case HomeTab.forYou:
        return _reelsForYou;
    }
  }

  List<Map<String, dynamic>> get _followingFeedReels {
    if (_reelsFollowing.isNotEmpty) return _reelsFollowing;
    // No reels from followed accounts — surface discovery content instead of blank.
    if (_reelsTrending.isNotEmpty) return _reelsTrending;
    if (_reelsForYou.isNotEmpty) return _reelsForYou;
    return _reelsFollowing;
  }

  // State for likes / public favorites / private saves (optimistic UI)
  final Map<String, bool> _likedReels = {};
  final Set<String> _likeInFlight = {};
  final Map<String, bool> _favoriteReels = {};
  final Map<String, bool> _privateSavedReels = {};
  final Map<String, bool> _repostedSourceReels = {};

  /// Cached for report / unfollow sheet (refreshed in [_loadReels]).
  List<String> _followingIds = [];

  /// Author UID while a follow / unfollow request is in flight.
  String? _followBusyAuthorId;

  // Playback and quality (from three-dots menu)
  String _playbackSpeedId = '1';
  String _playbackSpeedLabel = '1x (Normal)';
  String _qualityId = 'auto';
  String _qualityLabel = 'Auto (1080p HD)';
  bool _isRouteVisible = true;
  bool _isAppForeground = true;
  bool _isRouteObserverSubscribed = false;
  int _lastHandledDeepLinkNonce = -1;
  late final AnimationController _followingStoriesCollapse;

  /// Set when the feed cannot load (e.g. offline); cleared on successful refresh.
  String? _reelsLoadError;

  /// True from [_loadReels] start until [_loadReelsSupplement] finishes.
  bool _feedRefreshInProgress = false;

  /// Bumps to ignore stale async completions after a newer [_loadReels] starts.
  int _loadGeneration = 0;

  bool _autoScrollEnabled = true;
  bool _userHoldingToPause = false;
  bool _isBottomSheetOpen = false;
  bool _showForYouAiVerifiedTooltip = false;
  bool _videoCompletedForCurrentItem = false;
  bool _videoStartedForCurrentItem = false;
  Timer? _autoScrollTimer;

  /// How long a video reel may sit without ever starting playback (slow
  /// network, Cloudflare still processing, load failure) before auto-scroll
  /// skips past it instead of stalling the feed forever.
  static const Duration _videoStuckSkipTimeout = Duration(seconds: 20);
  int _activePointerCount = 0;

  @override
  void initState() {
    super.initState();
    final hasReelDeepLink =
        widget.deepLinkReelId != null && widget.deepLinkReelId!.isNotEmpty;
    if (!hasReelDeepLink) {
      currentTab = _defaultHomeTab;
      _currentIndex = 0;
    }
    WidgetsBinding.instance.addObserver(this);
    _followingStoriesCollapse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _followingStoriesCollapse.addListener(() {
      if (mounted) setState(() {});
    });
    _loadAutoScrollPref();
    unawaited(_bootstrapFeed());
  }

  Future<void> _bootstrapFeed() async {
    final reelsService = ReelsService();
    final cachedTrending = await FeedReelsCacheService.instance.loadTrending();
    if (!mounted) return;
    if (cachedTrending.isNotEmpty) {
      final filteredTrending =
          await reelsService.filterDiscoveryAudience(cachedTrending);
      if (!mounted) return;
      setState(() {
        _reelsTrending = filteredTrending;
        _feedRefreshInProgress = false;
        _reelsLoadError = null;
      });
      _preloadUpcomingReel();
      _scheduleAutoScroll();
    }

    final cachedForYou = await FeedReelsCacheService.instance.loadForYou();
    if (!mounted) return;
    if (cachedForYou.isNotEmpty) {
      final filteredForYou =
          await reelsService.filterDiscoveryAudience(cachedForYou);
      if (!mounted) return;
      setState(() => _reelsForYou = filteredForYou);
    }

    await _loadReels();
  }

  void _applyTrendingFeedReady(List<Map<String, dynamic>> hydratedTrending) {
    if (hydratedTrending.isEmpty) return;
    unawaited(FeedReelsCacheService.instance.saveTrending(hydratedTrending));
    unawaited(FeedOfflineVideoCache.instance.syncForFeed(hydratedTrending));
    _preloadUpcomingReel();
    if (_autoScrollTimer == null) {
      _scheduleAutoScroll();
    }
  }

  Future<void> _loadAutoScrollPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool('auto_scroll_enabled');
      if (saved != null && mounted) {
        setState(() => _autoScrollEnabled = saved);
      }
    } catch (_) {}
  }

  Future<void> _saveAutoScrollPref(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_scroll_enabled', value);
    } catch (_) {}
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
      _cancelAutoScrollTimer();
      _videoCompletedForCurrentItem = false;
      _videoStartedForCurrentItem = false;
      _jumpPageControllerToStart();
      setState(() {
        currentTab = _defaultHomeTab;
        _currentIndex = 0;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _jumpPageControllerToStart();
        _ensurePageControllerMatchesFeed();
        _scheduleAutoScroll();
      });
      _loadReels();
    }
    if (widget.deepLinkNonce != old.deepLinkNonce) {
      _handleIncomingDeepLink();
    }
  }

  Future<void> _loadReels() async {
    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _reelsLoadError = null;
        _feedRefreshInProgress = true;
      });
    }

    if (!await hasInternetAccess()) {
      if (!mounted || generation != _loadGeneration) return;
      if (_currentReels.isNotEmpty) {
        setState(() => _feedRefreshInProgress = false);
        return;
      }
      setState(() {
        _reelsLoadError = kNoInternetUserMessage;
        _feedRefreshInProgress = false;
      });
      return;
    }

    try {
      final uid = AuthService().currentUser?.uid ?? '';
      // Use the Trending feed warmed up during the splash video when available
      // so the default tab paints without another round-trip.
      final warm = await FeedWarmupService.instance.consume();
      List<String> blockedIds = warm?.blockedIds ?? const [];
      if (warm == null && uid.isNotEmpty) {
        blockedIds = await UserService().getBlockedUserIds(uid);
      }
      if (!mounted || generation != _loadGeneration) return;

      bool allowedByBlock(Map<String, dynamic> r) =>
          _isReelAllowedByBlock(r, blockedIds);

      List<Map<String, dynamic>> hydratedTrending;
      if (warm != null) {
        hydratedTrending = warm.trending;
      } else {
        final trendingRaw = await _reelsService.getReelsTrending();
        if (!mounted || generation != _loadGeneration) return;

        final filteredTrending = trendingRaw.where(allowedByBlock).toList();
        hydratedTrending =
            await _reelsService.hydrateRepostEngagementStats(filteredTrending);
        if (!mounted || generation != _loadGeneration) return;
      }

      setState(() {
        _reelsLoadError = null;
        _reelsTrending = hydratedTrending;
        _tabCycleOrders.clear();
      });
      _applyTrendingFeedReady(hydratedTrending);

      final forYouRaw = await _reelsService.getReelsForYou();
      if (!mounted || generation != _loadGeneration) return;

      final filteredForYou = forYouRaw.where(allowedByBlock).toList();
      final hydratedForYou =
          await _reelsService.hydrateRepostEngagementStats(filteredForYou);
      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        _reelsForYou = hydratedForYou;
      });
      if (hydratedForYou.isNotEmpty) {
        unawaited(FeedReelsCacheService.instance.saveForYou(hydratedForYou));
      }
      _handleIncomingDeepLink();

      await _loadReelsSupplement(
        generation: generation,
        uid: uid,
        blockedIds: blockedIds,
        allowedByBlock: allowedByBlock,
      );
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      if (_currentReels.isNotEmpty) {
        setState(() => _feedRefreshInProgress = false);
        return;
      }
      setState(() {
        _reelsLoadError = messageForFirestore(e);
        _feedRefreshInProgress = false;
      });
    }
  }

  static bool _isReelAllowedByBlock(
    Map<String, dynamic> r,
    List<String> blockedIds,
  ) {
    final id = (r['userId'] as String?) ?? '';
    if (id.isEmpty) return true;
    return !blockedIds.contains(id);
  }

  Future<void> _loadReelsSupplement({
    required int generation,
    required String uid,
    required List<String> blockedIds,
    required bool Function(Map<String, dynamic> r) allowedByBlock,
  }) async {
    try {
      final followingFuture = _reelsService.getReelsFollowing();
      final trendingFuture = _reelsService.getReelsTrending();
      final vrFuture = _reelsService.getReelsVR();
      final storyGroupsFuture = StoryService().getActiveStoryGroups();
      final myStoriesFuture = StoryService().getMyStories();

      if (uid.isNotEmpty) {
        try {
          await _reelsController.migrateLegacyUserSavesIfNeeded();
        } catch (_) {}
      }

      final following = await followingFuture;
      final trending = await trendingFuture;
      final vr = await vrFuture;
      final storyGroups = await storyGroupsFuture;
      final myStories = await myStoriesFuture;

      if (!mounted || generation != _loadGeneration) return;

      String avatarUrl = '';
      var followingIds = <String>[];
      if (uid.isNotEmpty) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          avatarUrl = userDoc.data()?['profileImage'] as String? ?? '';
        } catch (_) {}
        followingIds = await UserService().getFollowing(uid);
      }
      if (!mounted || generation != _loadGeneration) return;

      final filteredFollowing = following.where(allowedByBlock).toList();
      final filteredTrending = trending.where(allowedByBlock).toList();
      final filteredVr = vr.where(allowedByBlock).toList();
      final reelUserIds = <String>{
        ..._reelsForYou.map((r) => (r['userId'] as String?) ?? ''),
        ...filteredFollowing.map((r) => (r['userId'] as String?) ?? ''),
        ...filteredTrending.map((r) => (r['userId'] as String?) ?? ''),
        ...filteredVr.map((r) => (r['userId'] as String?) ?? ''),
      }..removeWhere((id) => id.isEmpty);
      final authorMetaByUid = await _fetchLatestAuthorFeedMeta(reelUserIds);
      if (!mounted || generation != _loadGeneration) return;

      final followingSet = followingIds.toSet();
      final filteredStories = storyGroups.where((g) {
        if (blockedIds.contains(g.userId)) return false;
        if (uid.isEmpty) return false;
        if (g.userId == uid) return true;
        return followingSet.contains(g.userId);
      }).toList();

      final engagementIds = <String>{
        for (final r in [
          ..._reelsForYou,
          ...filteredFollowing,
          ...filteredTrending,
          ...filteredVr,
        ])
          ReelEngagement.sourceReelId(r),
      }..removeWhere((id) => id.isEmpty);

      final likedIds = await _reelsController.getLikedReelIds(engagementIds);
      final favoriteIds =
          await _reelsController.getFavoriteReelIds(engagementIds);
      final privateIds =
          await _reelsController.getPrivateSavedReelIds(engagementIds);
      final repostedIds =
          await _reelsController.getRepostedSourceReelIds(engagementIds);

      final hydratedFollowing = await _reelsService.hydrateRepostEngagementStats(
        filteredFollowing,
      );
      final hydratedTrending =
          await _reelsService.hydrateRepostEngagementStats(filteredTrending);
      final hydratedVr =
          await _reelsService.hydrateRepostEngagementStats(filteredVr);
      final hydratedForYou =
          await _reelsService.hydrateRepostEngagementStats(_reelsForYou);

      if (!mounted || generation != _loadGeneration) return;

      final inFlightLikes = Set<String>.from(_likeInFlight);
      final optimisticLiked = Map<String, bool>.from(_likedReels);
      debugPrint(
        '[Vyooo][Like][UI] supplement reload liked=${likedIds.length} '
        'inFlight=${inFlightLikes.length}',
      );

      setState(() {
        _reelsLoadError = null;
        _feedRefreshInProgress = false;
        _reelsForYou = _withLatestAuthorMeta(hydratedForYou, authorMetaByUid);
        _reelsFollowing =
            _withLatestAuthorMeta(hydratedFollowing, authorMetaByUid);
        if (hydratedTrending.isNotEmpty) {
          _reelsTrending =
              _withLatestAuthorMeta(hydratedTrending, authorMetaByUid);
        }
        if (hydratedVr.isNotEmpty) {
          _reelsVR = _withLatestAuthorMeta(hydratedVr, authorMetaByUid);
        }
        _storyGroups = filteredStories;
        _myStories = myStories;
        _myAvatarUrl = avatarUrl;
        _followingIds = followingIds;
        _mergeLikedStateFromServer(likedIds);
        for (final id in inFlightLikes) {
          final want = optimisticLiked[id];
          if (want == true && !likedIds.contains(id)) {
            _adjustReelStat(id, 'likes', 1);
            debugPrint(
              '[Vyooo][Like][UI] supplement re-apply +1 likes id=$id',
            );
          } else if (want == false && likedIds.contains(id)) {
            _adjustReelStat(id, 'likes', -1);
            debugPrint(
              '[Vyooo][Like][UI] supplement re-apply -1 likes id=$id',
            );
          }
        }
        _favoriteReels
          ..clear()
          ..addEntries(favoriteIds.map((id) => MapEntry(id, true)));
        _privateSavedReels
          ..clear()
          ..addEntries(privateIds.map((id) => MapEntry(id, true)));
        _repostedSourceReels
          ..clear()
          ..addEntries(repostedIds.map((id) => MapEntry(id, true)));
      });
      if (_reelsTrending.isNotEmpty) {
        unawaited(FeedReelsCacheService.instance.saveTrending(_reelsTrending));
        unawaited(FeedOfflineVideoCache.instance.syncForFeed(_reelsTrending));
      }
      if (_reelsForYou.isNotEmpty) {
        unawaited(FeedReelsCacheService.instance.saveForYou(_reelsForYou));
      }
      _handleIncomingDeepLink();
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      debugPrint('Feed supplement load failed: $e');
      setState(() => _feedRefreshInProgress = false);
    }
  }

  List<Map<String, dynamic>> _withLatestAuthorMeta(
    List<Map<String, dynamic>> src,
    Map<String, _ReelAuthorFeedMeta> metaByUid,
  ) {
    return src.map((r) {
      final cloned = Map<String, dynamic>.from(r);
      final reelUid = (cloned['userId'] as String?) ?? '';
      final meta = metaByUid[reelUid];
      if (meta == null) return cloned;
      if (meta.avatarUrl.isNotEmpty) {
        cloned['avatarUrl'] = meta.avatarUrl;
        cloned['profileImage'] = meta.avatarUrl;
      }
      cloned['isVerified'] = meta.isVerified;
      cloned['accountType'] = meta.accountType;
      cloned['vipVerified'] = meta.vipVerified;
      return cloned;
    }).toList();
  }

  Future<Map<String, _ReelAuthorFeedMeta>> _fetchLatestAuthorFeedMeta(
    Set<String> userIds,
  ) async {
    if (userIds.isEmpty) return const <String, _ReelAuthorFeedMeta>{};
    final out = <String, _ReelAuthorFeedMeta>{};
    final ids = userIds.toList(growable: false);
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(
        i,
        (i + 10) > ids.length ? ids.length : (i + 10),
      );
      try {
        final q = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final d in q.docs) {
          final data = d.data();
          out[d.id] = _ReelAuthorFeedMeta(
            avatarUrl: (data['profileImage'] as String?)?.trim() ?? '',
            isVerified: data['isVerified'] == true,
            accountType: (data['accountType'] as String?) ?? 'private',
            vipVerified: data['vipVerified'] == true,
          );
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
          final exists = _reelsForYou.any((r) => _asString(r['id']) == reelId);
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
    int idx = _reelsTrending.indexWhere((r) => _asString(r['id']) == reelId);
    if (idx >= 0) return _ReelTarget(HomeTab.trending, idx);

    idx = _reelsForYou.indexWhere((r) => _asString(r['id']) == reelId);
    if (idx >= 0) return _ReelTarget(HomeTab.forYou, idx);

    idx = _reelsFollowing.indexWhere((r) => _asString(r['id']) == reelId);
    if (idx >= 0) return _ReelTarget(HomeTab.following, idx);

    idx = _reelsVR.indexWhere((r) => _asString(r['id']) == reelId);
    if (idx >= 0) return _ReelTarget(HomeTab.vr, idx);

    return null;
  }

  @override
  void dispose() {
    _cancelAutoScrollTimer();
    WidgetsBinding.instance.removeObserver(this);
    if (_isRouteObserverSubscribed) {
      appRouteObserver.unsubscribe(this);
      _isRouteObserverSubscribed = false;
    }
    _followingStoriesCollapse.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    if (!_isRouteVisible && mounted) return;
    _cancelAutoScrollTimer();
    if (mounted) setState(() => _isRouteVisible = false);
  }

  @override
  void didPopNext() {
    if (_isRouteVisible && mounted) return;
    if (mounted) {
      setState(() => _isRouteVisible = true);
      // Refresh follow/story state after returning from profile/search screens.
      _loadReels();
      _scheduleAutoScroll();
    }
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
    if (foreground) {
      _scheduleAutoScroll();
    } else {
      _cancelAutoScrollTimer();
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
          final swapIndex = shuffled.indexWhere(
            (value) => value != previousLast,
          );
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

  void _toggleFollowingStories() {
    if (currentTab != HomeTab.following) return;
    if (_followingStoriesCollapse.value > 0.5) {
      _followingStoriesCollapse.reverse();
    } else {
      _followingStoriesCollapse.forward();
    }
  }

  void _onPageChanged(int index) {
    final previous = _currentIndex;
    setState(() {
      _currentIndex = index;
      _showForYouAiVerifiedTooltip = false;
    });
    if (currentTab == HomeTab.following) {
      if (index > previous) {
        _followingStoriesCollapse.forward();
      } else if (index < previous) {
        _followingStoriesCollapse.reverse();
      }
    }
    if (_currentReels.isNotEmpty) {
      final feedIndex = _feedIndexForPage(index, _currentReels.length);
      final viewId = ReelEngagement.sourceReelId(_currentReels[feedIndex]);
      if (viewId.isEmpty) return;
      _reelsController.incrementView(reelId: viewId);
    }
    _cancelAutoScrollTimer();
    _videoCompletedForCurrentItem = false;
    _videoStartedForCurrentItem = false;
    _scheduleAutoScroll();
    _preloadUpcomingReel();
  }

  /// Pre-initializes the next reel's video controller so the upcoming swipe
  /// plays instantly instead of showing the loading spinner.
  void _preloadUpcomingReel() {
    final reels = _currentReels;
    if (reels.isEmpty) return;
    // Wraps so that the first reel is warmed up while the last one plays
    // (auto-scroll loops back to the start of the feed).
    final nextPage = (_currentIndex + 1) % reels.length;
    if (nextPage == _currentIndex) return;
    // PageView's itemBuilder maps page index -> reels[index] directly.
    final reel = reels[nextPage];
    final mediaType = ((reel['mediaType'] as String?) ?? 'video').toLowerCase();
    if (mediaType != 'video') return;
    final videoUrl = ((reel['videoUrl'] as String?) ?? '').trim();
    if (videoUrl.isEmpty) return;
    ReelPreloadService.instance.preload(videoUrl);
  }

  void _cancelAutoScrollTimer() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  bool get _canAutoScroll =>
      _autoScrollEnabled &&
      !_userHoldingToPause &&
      !_isBottomSheetOpen &&
      _isRouteVisible &&
      _isAppForeground &&
      widget.isActive &&
      mounted;

  String _currentItemMediaType() {
    final reels = _currentReels;
    if (reels.isEmpty) return 'video';
    final reel = reels[_feedIndexForPage(_currentIndex, reels.length)];
    return ((reel['mediaType'] as String?) ?? 'video').toLowerCase();
  }

  void _scheduleAutoScroll() {
    _cancelAutoScrollTimer();
    if (!_canAutoScroll) return;
    final mediaType = _currentItemMediaType();
    if (mediaType == 'image') {
      _autoScrollTimer = Timer(const Duration(seconds: 5), _performAutoScroll);
      return;
    }
    if (_videoCompletedForCurrentItem) {
      // Video already finished (e.g. while a sheet was open or the user was
      // holding): resume the normal post-completion advance.
      _autoScrollTimer = Timer(const Duration(seconds: 2), _performAutoScroll);
      return;
    }
    // Fallback: a video that never starts never reports completion, which
    // would stall auto-scroll forever. Skip ahead if playback hasn't begun
    // within the timeout.
    _autoScrollTimer = Timer(_videoStuckSkipTimeout, _performAutoScrollIfVideoStuck);
  }

  void _onVideoCompletedForAutoScroll() {
    if (!mounted) return;
    _videoCompletedForCurrentItem = true;
    if (!_canAutoScroll) return;
    _cancelAutoScrollTimer();
    _autoScrollTimer = Timer(const Duration(seconds: 2), _performAutoScroll);
  }

  void _onVideoPlaybackStartedForAutoScroll() {
    _videoStartedForCurrentItem = true;
  }

  void _performAutoScrollIfVideoStuck() {
    if (_videoStartedForCurrentItem || _videoCompletedForCurrentItem) return;
    _performAutoScroll();
  }

  void _performAutoScroll() {
    if (!_canAutoScroll) return;
    final reels = _currentReels;
    if (reels.isEmpty) return;
    if (!_pageController.hasClients) return;
    final nextPage = _currentIndex + 1;
    if (nextPage < reels.length) {
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      return;
    }
    // Last reel finished: loop the feed back to the first one. Jump instead
    // of animating so we don't fly backwards through every page in between.
    if (reels.length <= 1) return;
    _pageController.jumpToPage(0);
  }

  void _onAutoScrollToggled(bool value) {
    setState(() => _autoScrollEnabled = value);
    _saveAutoScrollPref(value);
    if (value) {
      _videoCompletedForCurrentItem = false;
      _scheduleAutoScroll();
    } else {
      _cancelAutoScrollTimer();
    }
  }

  Future<void> _onLike(String reelId, bool currentlyLiked) async {
    if (reelId.isEmpty) return;

    final uid = AuthService().currentUser?.uid ?? '';
    if (uid.isEmpty) {
      _showSnackBar('Sign in to like posts');
      return;
    }

    if (_likeInFlight.contains(reelId)) {
      debugPrint('[Vyooo][Like][UI] skip — already in flight reelId=$reelId');
      return;
    }

    final wantLiked = !currentlyLiked;
    debugPrint(
      '[Vyooo][Like][UI] tap reelId=$reelId currentlyLiked=$currentlyLiked '
      'wantLiked=$wantLiked',
    );
    _likeInFlight.add(reelId);
    setState(() {
      _likedReels[reelId] = wantLiked;
      _adjustReelStat(reelId, 'likes', wantLiked ? 1 : -1);
    });

    final actual = await _reelsController.likeReel(
      reelId: reelId,
      like: wantLiked,
    );
    _likeInFlight.remove(reelId);
    if (!mounted) return;

    debugPrint(
      '[Vyooo][Like][UI] result reelId=$reelId wantLiked=$wantLiked actual=$actual',
    );

    if (actual != wantLiked) {
      debugPrint('[Vyooo][Like][UI] ROLLBACK reelId=$reelId');
      setState(() {
        _likedReels[reelId] = actual;
        _adjustReelStat(reelId, 'likes', wantLiked ? -1 : 1);
      });
      return;
    }

    await _syncReelEngagementFromServer(reelId);
  }

  void _onDoubleTapLike(int feedIndex) {
    final reels = _currentReels;
    if (reels.isEmpty) return;
    final reel = reels[_feedIndexForPage(feedIndex, reels.length)];
    final engagementId = ReelEngagement.sourceReelId(reel);
    if (engagementId.isEmpty) return;
    if (_likeInFlight.contains(engagementId)) return;
    final alreadyLiked = _likedReels[engagementId] ?? false;
    if (!alreadyLiked) {
      _onLike(engagementId, false);
    }
  }

  Future<void> _onFavorite(String reelId, bool currentlyFavorite) async {
    final newState = await _reelsController.toggleFavoriteReel(
      reelId: reelId,
      currentlyFavorite: currentlyFavorite,
    );
    if (!mounted) return;
    final changed = newState != currentlyFavorite;
    final delta = changed ? (newState ? 1 : -1) : 0;
    setState(() {
      _favoriteReels[reelId] = newState;
      if (delta != 0) {
        _adjustReelStat(reelId, 'saves', delta);
      }
    });
    if (!mounted) return;
    if (!changed) {
      debugPrint(
        '[HomeReels._onFavorite] toggle had no effect reelId=$reelId '
        '(check terminal for [Vyooo][toggleFavoriteReel] — often Firestore rules or network)',
      );
      _showSnackBar('Could not update favorites. Try again.');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newState ? 'Added to favorites (public on profile)' : 'Removed from favorites',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  Future<void> _onPrivateSaveFromSheet(String reelId) async {
    final currently = _privateSavedReels[reelId] ?? false;
    final newState = await _reelsController.togglePrivateSavedReel(
      reelId: reelId,
      currentlySaved: currently,
    );
    if (!mounted) return;
    setState(() => _privateSavedReels[reelId] = newState);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newState ? 'Saved privately (only you can see this list)' : 'Removed from private saves',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  String _sourceOwnerId(Map<String, dynamic> reel) {
    if (ReelEngagement.isRepostStub(reel)) {
      return _asString(reel['repostOfUserId']).trim();
    }
    return _asString(reel['userId']).trim();
  }

  Future<void> _onRepostToggle(Map<String, dynamic> reel) async {
    final sourceId = ReelEngagement.sourceReelId(reel);
    if (sourceId.isEmpty) return;
    final wasReposted = _repostedSourceReels[sourceId] ?? false;
    if (wasReposted) {
      final ok = await _reelsController.unrepostReel(sourceReelId: sourceId);
      if (!mounted) return;
      if (!ok) {
        _showSnackBar('Could not remove repost. Try again.');
        return;
      }
      setState(() {
        _repostedSourceReels[sourceId] = false;
        _adjustReelStat(sourceId, 'reposts', -1);
      });
      _showSnackBar('Removed from your profile');
      return;
    }
    final stubId = await _reelsController.repostReel(sourceReelId: sourceId);
    if (!mounted) return;
    if (stubId == null) {
      _showSnackBar('Could not repost. Try again.');
      return;
    }
    setState(() {
      _repostedSourceReels[sourceId] = true;
      _adjustReelStat(sourceId, 'reposts', 1);
    });
    _showSnackBar('Reposted to your profile');
  }

  void _onShare(String reelId) {
    final reel = _currentReels.isEmpty
        ? null
        : _currentReels[_feedIndexForPage(_currentIndex, _currentReels.length)];
    if (reel == null) return;
    final sourceId = ReelEngagement.sourceReelId(reel);
    final uid = AuthService().currentUser?.uid ?? '';
    final isOwnPost = _sourceOwnerId(reel) == uid;
    _isBottomSheetOpen = true;
    _cancelAutoScrollTimer();
    showShareBottomSheet(
      context,
      reelId: sourceId,
      authorName: reel['username'] as String?,
      thumbnailUrl: reel['thumbnailUrl'] as String?,
      isOwnPost: isOwnPost,
      isReposted: _repostedSourceReels[sourceId] ?? false,
      onRepost: () => _onRepostToggle(reel),
      onRemoveRepost: () => _onRepostToggle(reel),
      onShareViaNative: () => _reelsController.shareReel(reelId: sourceId),
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
    ).then((_) {
      if (!mounted) return;
      _isBottomSheetOpen = false;
      _scheduleAutoScroll();
    });
  }

  void _onComment(String reelId) {
    _isBottomSheetOpen = true;
    _cancelAutoScrollTimer();
    showCommentsBottomSheet(
      context,
      reelId: reelId,
      onCommentCountChanged: (delta) => _bumpReelCommentCount(reelId, delta),
    ).then((_) {
      if (!mounted) return;
      _isBottomSheetOpen = false;
      _scheduleAutoScroll();
    });
  }

  void _bumpReelCommentCount(String reelId, int delta) {
    if (delta == 0 || !mounted) return;
    void bump(List<Map<String, dynamic>> list) {
      for (var i = 0; i < list.length; i++) {
        if (_asString(list[i]['id']) != reelId) continue;
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
        final matchesDoc = _asString(list[i]['id']) == reelId;
        final matchesSource =
            ReelEngagement.sourceReelId(list[i]) == reelId;
        if (!matchesDoc && !matchesSource) continue;
        final cur = (list[i][key] as num?)?.toInt() ?? 0;
        final next = (cur + delta).clamp(0, 999999999);
        list[i] = Map<String, dynamic>.from(list[i])..[key] = next;
        if (key == 'reposts' || key == 'shares') {
          list[i]['reposts'] = next;
          list[i]['shares'] = next;
        }
      }
    }

    bump(_reelsForYou);
    bump(_reelsFollowing);
    bump(_reelsTrending);
    bump(_reelsVR);
  }

  /// Keeps optimistic/in-flight likes when the feed supplement reloads from Firestore.
  void _mergeLikedStateFromServer(Set<String> serverLikedIds) {
    final inFlight = Set<String>.from(_likeInFlight);
    final optimisticLiked = Map<String, bool>.from(_likedReels);

    debugPrint(
      '[Vyooo][Like][UI] mergeLiked server=${serverLikedIds.length} '
      'inFlight=${inFlight.length} local=${optimisticLiked.length}',
    );

    _likedReels
      ..clear()
      ..addEntries(serverLikedIds.map((id) => MapEntry(id, true)));

    for (final id in inFlight) {
      final want = optimisticLiked[id];
      if (want != null) {
        _likedReels[id] = want;
        debugPrint(
          '[Vyooo][Like][UI] mergeLiked preserve in-flight id=$id want=$want',
        );
      }
    }
  }

  /// After a successful like/unlike, patch feed maps from the reel document so a
  /// concurrent feed refresh cannot overwrite counts with stale data.
  Future<void> _syncReelEngagementFromServer(String reelId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('reels')
          .doc(reelId)
          .get();
      if (!mounted || !doc.exists) {
        debugPrint(
          '[Vyooo][Like][UI] sync skip — reel doc missing reelId=$reelId',
        );
        return;
      }
      final data = doc.data() ?? {};
      final likes = (data['likes'] as num?)?.toInt() ?? 0;
      if (likes < 0) {
        ReelsService().repairCorruptedLikeCount(
          reelId,
          currentLikes: likes,
        );
      }
      debugPrint(
        '[Vyooo][Like][UI] sync patch reelId=$reelId likes=$likes',
      );
      if (!mounted) return;
      setState(
        () => _applyEngagementPatch(
          reelId,
          {
            'likes': EngagementCounts.sanitize(likes),
            'comments': (data['comments'] as num?)?.toInt() ?? 0,
            'saves': (data['saves'] as num?)?.toInt() ?? 0,
            'views':
                (data['views'] as num?)?.toInt() ??
                (data['viewsCount'] as num?)?.toInt() ??
                0,
            'reposts': (data['reposts'] as num?)?.toInt() ??
                (data['shares'] as num?)?.toInt() ??
                0,
            'shares': (data['shares'] as num?)?.toInt() ?? 0,
          },
        ),
      );
    } catch (e) {
      debugPrint(
        '[Vyooo][Like][UI] sync FAILED reelId=$reelId error=$e',
      );
    }
  }

  void _applyEngagementPatch(String reelId, Map<String, dynamic> fresh) {
    void patch(List<Map<String, dynamic>> list) {
      for (var i = 0; i < list.length; i++) {
        final matchesDoc = _asString(list[i]['id']) == reelId;
        final matchesSource = ReelEngagement.sourceReelId(list[i]) == reelId;
        if (!matchesDoc && !matchesSource) continue;
        list[i] = Map<String, dynamic>.from(list[i])
          ..['likes'] = (fresh['likes'] as num?)?.toInt() ?? 0
          ..['comments'] = (fresh['comments'] as num?)?.toInt() ?? 0
          ..['saves'] = (fresh['saves'] as num?)?.toInt() ?? 0
          ..['views'] =
              (fresh['views'] as num?)?.toInt() ??
              (fresh['viewsCount'] as num?)?.toInt() ??
              0
          ..['reposts'] = (fresh['reposts'] as num?)?.toInt() ??
              (fresh['shares'] as num?)?.toInt() ??
              0
          ..['shares'] = (fresh['shares'] as num?)?.toInt() ?? 0;
      }
    }

    patch(_reelsForYou);
    patch(_reelsFollowing);
    patch(_reelsTrending);
    patch(_reelsVR);
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
    _jumpPageControllerToStart();
    _cancelAutoScrollTimer();
    _videoCompletedForCurrentItem = false;
    _videoStartedForCurrentItem = false;
    setState(() {
      currentTab = tab;
      _currentIndex = 0;
      if (tab != HomeTab.forYou) {
        _showForYouAiVerifiedTooltip = false;
      }
    });
    if (tab == HomeTab.following) {
      // Ensure "Following" tab reflects latest follows immediately.
      _loadReels();
    }
    // Following status row starts collapsed; tap the chevron to open.
    _followingStoriesCollapse.value = 1.0;
    if (tab != HomeTab.vr) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || currentTab != tab) return;
        _jumpPageControllerToStart();
        _ensurePageControllerMatchesFeed();
        _scheduleAutoScroll();
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

    final headerEstimate = AppFeedHeader.layoutHeight();
    final topPadding = MediaQuery.paddingOf(context).top;
    final headerBottom = topPadding + headerEstimate;

    final followingStoriesTop = headerBottom + AppSpacing.sm;
    final collapseT = isFollowing ? _followingStoriesCollapse.value : 0.0;
    final storiesCollapsedTop =
        headerBottom - AppSizes.followingStoriesCollapsedOverlap;

    final animatedStoriesTop =
        lerpDouble(followingStoriesTop, storiesCollapsedTop, collapseT) ??
        followingStoriesTop;

    final feedChromeBottom = AppBottomNavigation.totalHeightFor(context);
    final feedBottomInset = feedChromeBottom + AppSpacing.feedPostNavGap;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: _homeFeedBackgroundDecoration(isVrTab: isVrTab),
        child: Stack(
          children: [
            if (isVrTab)
              Positioned.fill(
                top: topPadding + headerEstimate + 8,
                child: _buildVrContent(),
              )
            else
              Positioned.fill(
                top: 0,
                bottom: feedBottomInset,
                child: _buildFeedClipArea(),
              ),
            _buildHeader(isFollowing: isFollowing, collapseT: collapseT),
            if (isFollowing)
              if (collapseT < 0.999)
                _buildStoryRow(
                  topOffset: animatedStoriesTop,
                  opacity: 1 - collapseT,
                  ignorePointer: collapseT > 0.95,
                ),
            if (currentTab == HomeTab.forYou && _showForYouAiVerifiedTooltip)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => setState(() => _showForYouAiVerifiedTooltip = false),
                  child: const SizedBox.expand(),
                ),
              ),
            if (currentTab == HomeTab.forYou && !isVrTab)
              Positioned(
                top: topPadding + headerEstimate + AppSpacing.sm,
                right: AppSpacing.md,
                left: AppSpacing.md,
                child: Align(
                  alignment: Alignment.topRight,
                  child: ForYouAiVerifiedBadge(
                    showTooltip: _showForYouAiVerifiedTooltip,
                    onIconTap: () =>
                        setState(() => _showForYouAiVerifiedTooltip = true),
                  ),
                ),
              ),
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
    return const VrComingSoonView();
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
          onStoriesModified: _loadReels,
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

  Widget _buildStoryRow({
    required double topOffset,
    double opacity = 1,
    bool ignorePointer = false,
  }) {
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
      top: topOffset,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: ignorePointer,
        child: Opacity(
          opacity: opacity.clamp(0, 1),
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
        ),
      ),
    );
  }

  Widget _buildFeedClipArea() {
    final radius = AppRadius.feedPostBottomRadius;
    return ClipRRect(
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: radius,
        ),
        child: _buildReelsFeed(),
      ),
    );
  }

  Widget _buildReelsFeed() {
    final reels = _currentReels;
    if (_feedRefreshInProgress && reels.isEmpty && _reelsLoadError == null) {
      return FeedReelsLoadingSkeleton(
        borderRadius: AppRadius.feedPostBottomRadius,
      );
    }
    if (_reelsLoadError != null && reels.isEmpty) {
      return _buildFeedLoadErrorPlaceholder(_reelsLoadError!);
    }
    if (reels.isEmpty) {
      return _buildEmptyReelsPlaceholder();
    }
    return Listener(
      onPointerDown: (_) {
        _activePointerCount++;
        _userHoldingToPause = true;
        _cancelAutoScrollTimer();
      },
      onPointerUp: (_) {
        _activePointerCount = (_activePointerCount - 1).clamp(0, 99);
        if (_activePointerCount > 0) return;
        _userHoldingToPause = false;
        if (_videoCompletedForCurrentItem &&
            _currentItemMediaType() != 'image') {
          _onVideoCompletedForAutoScroll();
        } else {
          _scheduleAutoScroll();
        }
      },
      onPointerCancel: (_) {
        _activePointerCount = (_activePointerCount - 1).clamp(0, 99);
        if (_activePointerCount > 0) return;
        _userHoldingToPause = false;
        if (_videoCompletedForCurrentItem &&
            _currentItemMediaType() != 'image') {
          _onVideoCompletedForAutoScroll();
        } else {
          _scheduleAutoScroll();
        }
      },
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPageChanged,
        itemCount: reels.length,
        itemBuilder: (context, index) {
          final feedIndex = index;
          final reel = reels[feedIndex];
          final mediaItems = ReelMediaItem.listFromPost(reel);
          if (mediaItems.length > 1) {
            // Carousel post: horizontal pager inside the vertical feed.
            return PostMediaCarousel(
              key: ValueKey<String>(
                'carousel_${_asString(reel['id'], fallback: '$feedIndex')}',
              ),
              items: mediaItems,
              video360: Video360Metadata.fromPost(reel),
              imageFit: BoxFit.contain,
              isVisible:
                  widget.isActive &&
                  _isRouteVisible &&
                  _isAppForeground &&
                  index == _currentIndex,
              onDoubleTap: () => _onDoubleTapLike(feedIndex),
              onActiveVideoCompleted: index == _currentIndex
                  ? _onVideoCompletedForAutoScroll
                  : null,
              onActiveVideoPlaybackStarted: index == _currentIndex
                  ? _onVideoPlaybackStartedForAutoScroll
                  : null,
            );
          }
          final mediaType = ((reel['mediaType'] as String?) ?? 'video')
              .toLowerCase();
          if (mediaType == 'image') {
            final imageUrl = ((reel['imageUrl'] as String?) ?? '').trim();
            final thumbnailUrl = ((reel['thumbnailUrl'] as String?) ?? '')
                .trim();
            final displayUrl = imageUrl.isNotEmpty ? imageUrl : thumbnailUrl;
            if (displayUrl.isEmpty) {
              return _buildMissingMediaPlaceholder(
                'This reel has no image URL.',
              );
            }
            return _wrapModeratedReel(
              reel,
              _buildImageReelItem(displayUrl, feedIndex),
            );
          }
          final videoUrl = (reel['videoUrl'] as String?)?.trim() ?? '';
          if (videoUrl.isEmpty) {
            return _buildMissingMediaPlaceholder('This reel has no video URL.');
          }
          final thumbnailUrl = ((reel['thumbnailUrl'] as String?) ?? '').trim();
          final imageUrl = ((reel['imageUrl'] as String?) ?? '').trim();
          final loadingThumb = thumbnailUrl.isNotEmpty
              ? thumbnailUrl
              : imageUrl;
          return _wrapModeratedReel(
            reel,
            ReelItemWidget(
              key: ValueKey<String>(_asString(reel['id'], fallback: videoUrl)),
              videoUrl: videoUrl,
              thumbnailUrl: loadingThumb,
              video360: Video360Metadata.fromPost(reel),
              // Only play when this page is visible AND the home tab is active.
              isVisible:
                  widget.isActive &&
                  _isRouteVisible &&
                  _isAppForeground &&
                  index == _currentIndex,
              onVideoCompleted: index == _currentIndex
                  ? _onVideoCompletedForAutoScroll
                  : null,
              onVideoPlaybackStarted: index == _currentIndex
                  ? _onVideoPlaybackStartedForAutoScroll
                  : null,
              onDoubleTap: () => _onDoubleTapLike(feedIndex),
            ),
          );
        },
      ),
    );
  }

  Widget _wrapModeratedReel(Map<String, dynamic> reel, Widget child) {
    final rawModeration = reel['moderation'];
    final moderation = rawModeration is Map
        ? Map<String, dynamic>.from(rawModeration)
        : null;
    return ModeratedContentWrapper(
      contentId: _asString(reel['id']),
      contentKind: ContentModeration.kindFromReel(reel),
      ownerId: _asString(reel['userId']),
      moderation: moderation,
      child: child,
    );
  }

  Widget _buildImageReelItem(String imageUrl, int feedIndex) {
    // Cap decode size at 2x physical screen width: keeps pinch-zoom usable
    // while preventing full-resolution photos (tens of MB decoded each) from
    // accumulating in memory as the user scrolls the feed.
    final mq = MediaQuery.of(context);
    final cacheWidth = (mq.size.width * mq.devicePixelRatio * 2).round();
    return DoubleTapLikeOverlay(
      onDoubleTap: () => _onDoubleTapLike(feedIndex),
      child: SizedBox.expand(
        child: ColoredBox(
          color: Colors.black,
          child: InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            panEnabled: false,
            child: Center(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                cacheWidth: cacheWidth,
                errorBuilder: (context, error, stackTrace) {
                  return _buildMissingMediaPlaceholder(
                    'Failed to load image reel.',
                  );
                },
              ),
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

  Widget _buildFeedLoadErrorPlaceholder(String message) {
    return SizedBox.expand(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 56,
                color: Colors.white.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 16,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brandPink,
                ),
                onPressed: _loadReels,
                child: const Text(
                  'Retry',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyReelsPlaceholder() {
    final (String title, String subtitle, IconData icon) = switch (currentTab) {
      HomeTab.following => (
        'Nothing here yet',
        _followingIds.isEmpty
            ? 'Follow creators to see their reels and stories here.'
            : 'No new reels from people you follow yet. Check back soon.',
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

  Widget _buildHeader({required bool isFollowing, required double collapseT}) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: AppFeedHeader(
          selectedIndex: currentTab.index,
          onTabSelected: (index) => _onTabChanged(HomeTab.values[index]),
          trailing: _buildHeaderActions(),
          tabRowTrailing: isFollowing
              ? FollowingStoriesToggle(
                  isExpanded: collapseT < 0.5,
                  onTap: _toggleFollowingStories,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildHeaderActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppFeedHeaderIconButton.search(onTap: _openSearchTab),
        SizedBox(width: AppSpacing.xs),
        _buildHeaderNotificationIcon(),
      ],
    );
  }

  void _openSearchTab() {
    MainNavWrapper.openSearchTab();
  }

  Widget _buildHeaderNotificationIcon() {
    return StreamBuilder<int>(
      stream: NotificationService().watchUnreadCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        final showBadge = count > 0;
        final label = count > 99 ? '99+' : '$count';
        return AppFeedNotificationButton(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationScreen(),
              ),
            );
          },
          badge: showBadge
              ? Container(
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF2D55),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: const Color(0xFF14001F),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildInteractionButtons() {
    final reel = _currentFeedReel();
    if (reel == null) return const SizedBox.shrink();
    final reelId = _asString(reel['id']);
    if (reelId.isEmpty) return const SizedBox.shrink();
    final engagementId = ReelEngagement.sourceReelId(reel);
    final isLiked = _likedReels[engagementId] ?? false;
    final isFavorite = _favoriteReels[engagementId] ?? false;
    final privacy = ReelCountPrivacy.fromMap(reel);
    final isFollowingTab = currentTab == HomeTab.following;
    final interactionBottom =
        AppBottomNavigation.totalHeightFor(context) +
        AppSpacing.reelActionColumnNavGap;

    return Positioned(
      right: AppSpacing.md,
      bottom: interactionBottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isFollowingTab) ...[
            AppInteractionButton(
              iconAsset: FeedInteractionAssets.crown,
              count: '',
              colorizeAsset: false,
              iconColor: AppColors.lightGold,
              onTap: () => _onCrownTap(reel),
            ),
            SizedBox(height: AppSpacing.md),
          ],
          AppInteractionButton(
            iconAsset: FeedInteractionAssets.heart,
            count: privacy.displayCount(
              ReelCountMetric.likes,
              _asInt(reel['likes']),
            ),
            isActive: isLiked,
            activeColor: AppColors.feedLikeActive,
            defaultColor: Colors.white,
            countColor: Colors.white,
            colorizeAsset: true,
            onTap: () => _onLike(engagementId, isLiked),
            iconSize: AppSizes.feedLikeIcon,
            countTextStyle: AppTypography.feedReelMetric,
            spacing: AppSpacing.xs,
          ),
          SizedBox(height: AppSpacing.md),
          AppInteractionButton(
            iconAsset: FeedInteractionAssets.comments,
            count: privacy.displayCount(
              ReelCountMetric.comments,
              _asInt(reel['comments']),
            ),
            colorizeAsset: false,
            countColor: Colors.white,
            onTap: () => _onComment(engagementId),
            countTextStyle: AppTypography.feedReelMetric,
            spacing: AppSpacing.xs,
          ),
          SizedBox(height: AppSpacing.md),
          AppInteractionButton(
            iconAsset: isFavorite
                ? FeedInteractionAssets.savePost
                : FeedInteractionAssets.save,
            label: 'Save',
            colorizeAsset: false,
            isActive: isFavorite,
            activeColor: AppColors.brandPink,
            countColor: Colors.white,
            onTap: () => _onFavorite(engagementId, isFavorite),
            countTextStyle: AppTypography.feedReelActionLabel,
            spacing: AppSpacing.xs,
          ),
          SizedBox(height: AppSpacing.md),
          AppInteractionButton(
            iconAsset: FeedInteractionAssets.share,
            label: 'Share',
            colorizeAsset: false,
            countColor: Colors.white,
            onTap: () => _onShare(reelId),
            countTextStyle: AppTypography.feedReelActionLabel,
            spacing: AppSpacing.xs,
          ),
          SizedBox(height: AppSpacing.md),
          AppInteractionButton(
            iconAsset: FeedInteractionAssets.more,
            count: '',
            colorizeAsset: false,
            onTap: () => _onMoreOptions(reelId),
          ),
        ],
      ),
    );
  }

  void _onCrownTap(Map<String, dynamic> reel) {
    final authorId = _sourceOwnerId(reel);
    if (authorId.isEmpty) return;
    if (reel['vipVerified'] == true || reel['monetizationEnabled'] == true) {
      _openReelAuthorProfile(reel);
      return;
    }
    _showSnackBar('Creator subscriptions coming soon');
  }

  Future<void> _onFollowAuthor(Map<String, dynamic> reel) async {
    final me = AuthService().currentUser?.uid ?? '';
    final target = _sourceOwnerId(reel);
    if (me.isEmpty || target.isEmpty || me == target) return;
    if (_followBusyAuthorId == target) return;

    final isFollowing = _followingIds.contains(target);
    setState(() => _followBusyAuthorId = target);
    try {
      final svc = UserService();
      if (isFollowing) {
        await svc.unfollowUser(currentUid: me, targetUid: target);
        if (!mounted) return;
        setState(() {
          _followingIds = _followingIds.where((id) => id != target).toList();
        });
      } else {
        await svc.followUser(currentUid: me, targetUid: target);
        if (!mounted) return;
        final nowFollowing = await svc.isFollowingUser(
          currentUid: me,
          targetUid: target,
        );
        if (!mounted) return;
        if (nowFollowing && !_followingIds.contains(target)) {
          setState(() => _followingIds = [..._followingIds, target]);
        }
      }
    } catch (_) {
      if (mounted) _showSnackBar('Could not update follow. Try again.');
    } finally {
      if (mounted) setState(() => _followBusyAuthorId = null);
    }
  }

  void _onMoreOptions(String reelId) {
    final reel = _currentReels.firstWhere((r) => _asString(r['id']) == reelId);
    final authorId = _asString(reel['userId']);
    _isBottomSheetOpen = true;
    _cancelAutoScrollTimer();
    showReelMoreOptionsSheet(
      context,
      reelId: reelId,
      playbackSpeed: _playbackSpeedLabel,
      quality: _qualityLabel,
      autoScrollEnabled: _autoScrollEnabled,
      onDownload: _onDownloadTapped,
      onSavePrivately: () => _onPrivateSaveFromSheet(reelId),
      onReport: () => showReportSheet(
        context,
        username: _asString(reel['username'], fallback: 'User'),
        avatarUrl: _asString(reel['avatarUrl']),
        targetUserId: authorId.isEmpty ? null : authorId,
        reelId: reelId,
        isFollowing: authorId.isNotEmpty && _followingIds.contains(authorId),
      ),
      onNotInterested: () => showNotInterestedSheet(context),
      onCaptions: () => _showSnackBar('Captions'),
      onPlaybackSpeed: _openPlaybackSpeedSheet,
      onQuality: _openVideoQualitySheet,
      onManagePreferences: () => showManageContentPreferencesSheet(context),
      onWhyThisPost: () => showWhySeeingThisSheet(context),
      onAutoScrollChanged: _onAutoScrollToggled,
    ).then((_) {
      if (!mounted) return;
      _isBottomSheetOpen = false;
      _scheduleAutoScroll();
    });
  }

  Future<void> _onDownloadTapped() async {
    final subscriptionController = context.read<SubscriptionController>();
    if (!subscriptionController.isSubscriber &&
        !subscriptionController.isCreator) {
      showDownloadSubscriptionSheet(context);
      return;
    }
    final reel = _currentFeedReel();
    if (reel == null) return;
    final reelId = _asString(reel['id']);
    final videoUrl = _asString(reel['videoUrl']);
    final thumb = _asString(reel['thumbnailUrl']);
    if (reelId.isEmpty || videoUrl.isEmpty) {
      _showSnackBar('Download unavailable for this post');
      return;
    }
    _showSnackBar('Downloading…');
    final ok = await ReelDownloadService.instance.downloadVideo(
      reelId: reelId,
      videoUrl: videoUrl,
      thumbnailUrl: thumb,
    );
    if (!mounted) return;
    _showSnackBar(
      ok ? 'Saved under Settings → Downloaded Videos' : 'Download failed',
    );
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

    final authorId = _sourceOwnerId(reel);
    final me = AuthService().currentUser?.uid ?? '';
    final showFollow = authorId.isNotEmpty && authorId != me;
    final isFollowing = showFollow && _followingIds.contains(authorId);
    final followBusy = _followBusyAuthorId == authorId;
    final overlayBottom =
        AppBottomNavigation.totalHeightFor(context) + AppSpacing.xs;

    return Positioned(
      left: AppSpacing.md,
      right: 88,
      bottom: overlayBottom,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _openReelAuthorProfile(reel),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primary, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: AppSizes.feedReelAvatarRadius,
                    backgroundColor: Colors.grey[900],
                    backgroundImage:
                        _isValidNetworkUrl(_asString(reel['avatarUrl']))
                        ? NetworkImage(_asString(reel['avatarUrl']))
                        : null,
                    onBackgroundImageError:
                        _isValidNetworkUrl(_asString(reel['avatarUrl']))
                        ? (_, _) {}
                        : null,
                    child: !_isValidNetworkUrl(_asString(reel['avatarUrl']))
                        ? const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 18,
                          )
                        : null,
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: () => _openReelAuthorProfile(reel),
                        child: Text(
                          _reelHandle(reel),
                          style: AppTypography.feedReelUsername,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (reel['isVerified'] == true) ...[
                      SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: verificationBadgeColor(
                            isVerified: true,
                            accountType:
                                (reel['accountType'] as String?) ??
                                    'private',
                            vipVerified: reel['vipVerified'] == true,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ],
                    if (showFollow) ...[
                      SizedBox(width: AppSpacing.sm),
                      GestureDetector(
                        onTap: followBusy ? null : () => _onFollowAuthor(reel),
                        child: Container(
                          padding: AppPadding.feedReelFollowChip,
                          decoration: BoxDecoration(
                            color: isFollowing
                                ? White24.value
                                : AppColors.feedFollowButton,
                            borderRadius: AppRadius.pillRadius,
                          ),
                          child: followBusy
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  isFollowing ? 'Following' : '+ Follow',
                                  style: AppTypography.feedReelFollowChip,
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (ReportStatusThresholds.severityFor(_asInt(reel['reportCount'])) !=
              ReportSeverity.none) ...[
            SizedBox(height: AppSpacing.sm),
            ReportStatusBar.fromReel(reel),
          ],
          SizedBox(height: AppSpacing.sm),
          _buildReelCaption(reel),
          _buildReelMusicLine(reel),
          SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Widget _buildReelMusicLine(Map<String, dynamic> reel) {
    final music = _reelMusicLabel(reel);
    if (music.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(
            Icons.music_note_rounded,
            color: AppTheme.primary,
            size: AppTypography.feedReelMusicSize,
          ),
          SizedBox(width: AppSpacing.reelMusicIconGap),
          Expanded(
            child: Text(
              music,
              style: AppTypography.feedReelMusic,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _reelMusicLabel(Map<String, dynamic> reel) {
    final explicit = _asString(reel['music']).trim();
    if (explicit.isNotEmpty) return explicit;
    final profileMusic = _asString(reel['profileMusic']).trim();
    if (profileMusic.isNotEmpty) return profileMusic;
    final handle = _reelHandle(reel).replaceFirst('@', '');
    if (handle.isEmpty) return '';
    return 'Original Sound - $handle';
  }

  Widget _buildReelCaption(Map<String, dynamic> reel) {
    final title = _asString(reel['title']);
    final description = _asString(reel['description']);
    final tagsList = reel['tags'] as List? ?? [];
    final locationMap = reel['location'] as Map<String, dynamic>?;
    final locationName = (locationMap?['name'] as String?)?.trim() ?? '';
    final locationAddress = (locationMap?['address'] as String?)?.trim() ?? '';

    if (title.isEmpty && description.isEmpty && tagsList.isEmpty) {
      // Fallback for old reels that only have the 'caption' field
      return _CaptionWithSeeMore(
        text: _asString(reel['caption']),
        locationName: locationName,
        locationAddress: locationAddress,
      );
    }

    final buffer = StringBuffer();
    if (title.isNotEmpty) {
      buffer.write(title);
    }
    if (description.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write(description);
    }
    if (tagsList.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write(tagsList.map((t) => '#${t.toString().trim()}').join(' '));
    }

    // If description was added, we might want to distinguish the title.
    // However, CaptionWithHashtags takes a single string.
    // For now, let's just ensure it's all passed.
    return _CaptionWithSeeMore(
      text: buffer.toString(),
      locationName: locationName,
      locationAddress: locationAddress,
    );
  }

  // bool _isVideoPlaying() {
  //   // Placeholder - check actual player state from ReelItemWidget if needed
  //   return true;
  // }


  String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }


  String _reelHandle(Map<String, dynamic> reel) {
    final handle = _asString(reel['handle']);
    if (handle.isNotEmpty) return handle.startsWith('@') ? handle : '@$handle';
    final username = _asString(reel['username'])
        .replaceAll(' ', '_')
        .toLowerCase();
    return username.isNotEmpty ? '@$username' : '@user';
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
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
    final isFollowing =
        targetUid.isNotEmpty && _followingIds.contains(targetUid);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfileScreen(
          payload: UserProfilePayload(
            username: normalizedUsername.isNotEmpty
                ? normalizedUsername
                : fallbackName,
            displayName: fallbackName.isNotEmpty
                ? fallbackName
                : normalizedUsername,
            avatarUrl: avatar,
            isVerified: (reel['isVerified'] as bool?) ?? false,
            accountType: (reel['accountType'] as String?) ?? 'personal',
            vipVerified: (reel['vipVerified'] as bool?) ?? false,
            monetizationEnabled:
                (reel['monetizationEnabled'] as bool?) ?? false,
            postCount: 0,
            followerCount: 0,
            followingCount: 0,
            bio: '',
            isFollowing: isFollowing,
            targetUserId: targetUid.isNotEmpty ? targetUid : null,
          ),
        ),
      ),
    );
  }
}

BoxDecoration? _homeFeedBackgroundDecoration({required bool isVrTab}) {
  if (isVrTab) {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF49113B), Color(0xFF000000)],
      ),
    );
  }
  return null;
}

class _CaptionWithSeeMore extends StatefulWidget {
  const _CaptionWithSeeMore({
    required this.text,
    this.locationName = '',
    this.locationAddress = '',
  });

  final String text;
  final String locationName;
  final String locationAddress;

  @override
  State<_CaptionWithSeeMore> createState() => _CaptionWithSeeMoreState();
}

class _CaptionWithSeeMoreState extends State<_CaptionWithSeeMore> {
  bool _expanded = false;

  static const _captionStyle = AppTypography.feedReelCaption;

  bool _isOverflowing(String text, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _captionStyle),
      maxLines: 3,
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
            CaptionWithHashtags(
              text: caption,
              style: _captionStyle,
              hashtagStyle: AppTypography.feedReelHashtag,
              maxLines: _expanded ? null : 3,
              overflow: _expanded ? TextOverflow.clip : TextOverflow.ellipsis,
            ),
            if (hasOverflow && !_expanded) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => setState(() => _expanded = true),
                child: const Text(
                  'See More',
                  style: AppTypography.feedReelCaptionSeeMore,
                ),
              ),
            ],
            if (_expanded && widget.locationName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.white70, size: 16),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      widget.locationName,
                      style: AppTypography.feedReelLocation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (widget.locationAddress.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text(
                    widget.locationAddress,
                    style: AppTypography.feedReelHandle.copyWith(
                      color: White54.value,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}
