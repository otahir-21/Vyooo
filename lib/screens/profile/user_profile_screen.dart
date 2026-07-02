import 'dart:developer' as dev;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';

import '../../core/config/deep_link_config.dart';
import '../../core/profile/creator_monetization.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/feed_interaction_assets.dart';
import '../../core/constants/profile_assets.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/widgets/profile/profile_screen_background.dart';
import '../../core/widgets/profile/profile_grid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/app_user_model.dart';
import '../../core/models/live_stream_model.dart';
import '../../core/models/story_highlight_model.dart';
import '../../core/models/story_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/live_stream_service.dart';
import '../../core/services/reels_service.dart';
import '../../core/services/story_service.dart';
import '../../core/services/user_service.dart';
import '../../core/services/creator_subscription_service.dart';
import '../../core/utils/verification_badge.dart';
import '../../core/utils/user_facing_errors.dart';
import '../../core/controllers/reels_controller.dart';
import '../../core/models/reel_count_privacy.dart';
import '../../core/models/reel_media_item.dart';
import '../../core/models/video_360_metadata.dart';
import '../../core/utils/reel_engagement.dart';
import '../../core/widgets/post_media_carousel.dart';
import '../../core/widgets/app_interaction_button.dart';
import '../../core/widgets/app_bottom_navigation.dart';
import '../../core/widgets/live_avatar_ring.dart';
import '../../core/widgets/live_now_strip.dart';
import '../../core/wrappers/main_nav_wrapper.dart';
import '../../features/chat/services/chat_service.dart';
import '../../features/chat/screens/chat_thread_screen.dart';
import '../../features/comments/widgets/comments_bottom_sheet.dart';
import '../../features/share/widgets/share_bottom_sheet.dart';
import '../../features/reel/widgets/not_interested_sheet.dart';
import '../../features/reel/widgets/report_sheet.dart';
import '../../features/reel/widgets/reel_more_options_sheet.dart';
import '../content/live_stream_route.dart';
import 'followers_following_screen.dart';
import 'profile_figma_tokens.dart';
import 'profile_figma_widgets.dart';
import '../../widgets/reel_item_widget.dart';
import '../../features/reel/widgets/block_user_sheet.dart';
import '../../features/reel/widgets/report_user_sheet.dart';
import '../../features/story/highlight_viewer_screen.dart';
import '../../features/story/story_viewer_screen.dart';
import '../../features/story/widgets/profile_highlight_album_tile.dart';
import '../../features/subscription/creator_subscription_screen.dart';

const Color _profileAccentMagenta = ProfileFigmaTokens.accentMagenta;
const Color _profileTabTrack = ProfileFigmaTokens.tabTrack;
const Color _profileSurface = ProfileFigmaTokens.contentSurface;
const double _profileActionRadius = 52;
const double _profileOutlineWidth = 1.5;
const double _profileActionGroupMaxWidth = 360;

/// Data for displaying another user's profile (e.g. from search or followers list).
class UserProfilePayload {
  const UserProfilePayload({
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    this.isVerified = false,
    this.accountType = 'personal',
    this.vipVerified = false,
    this.postCount = 0,
    required this.followerCount,
    this.followingCount = 0,
    this.bio = '',
    this.profileMusic = '',
    this.monetizationEnabled = false,
    this.isFollowing = false,
    this.isSubscribed = false,
    this.targetUserId,
  });

  factory UserProfilePayload.fromAppUser(
    AppUserModel user, {
    int postCount = 0,
    int followerCount = 0,
    int followingCount = 0,
    bool isFollowing = false,
    bool isSubscribed = false,
  }) {
    final username = (user.username ?? '').trim();
    final handle = username.isNotEmpty
        ? username
        : (user.email.contains('@') ? user.email.split('@').first : user.uid);
    final displayName = (user.displayName ?? '').trim().isNotEmpty
        ? user.displayName!.trim()
        : handle;
    return UserProfilePayload(
      targetUserId: user.uid,
      username: handle,
      displayName: displayName,
      avatarUrl: user.profileImage ?? '',
      isVerified: user.isVerified,
      accountType: user.accountType,
      vipVerified: user.vipVerified,
      monetizationEnabled: user.monetizationEnabled,
      postCount: postCount,
      followerCount: followerCount,
      followingCount: followingCount,
      bio: user.bio ?? '',
      profileMusic: user.profileMusic ?? '',
      isFollowing: isFollowing,
      isSubscribed: isSubscribed,
    );
  }

  /// When set, Follow/Following updates Firestore (users/{currentUser}.following).
  final String? targetUserId;
  final String username;
  final String displayName;
  final String avatarUrl;
  final bool isVerified;
  final String accountType;
  final bool vipVerified;
  final bool monetizationEnabled;
  final int postCount;
  final int followerCount;
  final int followingCount;
  final String bio;
  final String profileMusic;
  final bool isFollowing;
  final bool isSubscribed;

  bool get showSubscribeFeatures => showProfileSubscribeFeatures(
        accountType: accountType,
        monetizationEnabled: monetizationEnabled,
      );
}

/// Other person's profile: same top (avatar, stats, buttons), Posts/VR/Clips/Tags + star, content by tab.
/// Design-only; backend integration later. Same flow for subscription creator or standard user.
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.payload});

  final UserProfilePayload payload;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  static const List<String> _tabs = ['Posts', 'VR', 'Clips', 'Tags'];
  static const int _savedTabIndex = 4;
  static const Map<String, String> _accountTypeLabels = <String, String>{
    'personal': 'Personal',
    'business': 'Business',
    'government': 'Government',
    'celebrity': 'Celebrity',
    'sports_celebrity': 'Sports Celebrity',
    'content_creator': 'Content Creator',
    'entrepreneur': 'Entrepreneur',
    'musician': 'Musician',
    'restricted': 'Restricted',
  };
  int _selectedTabIndex = 0;
  bool _highlightsExpanded = false;
  bool _highlightsAutoExpanded = false;
  late bool _isFollowing;
  late bool _isSubscribed;
  bool _followActionBusy = false;
  /// Pending follow request to this profile (private accounts).
  bool _pendingFollowRequest = false;
  StreamSubscription<bool>? _pendingFollowSub;
  /// Keeps [_isFollowing] in sync when the owner accepts (CF updates users/me.following).
  StreamSubscription<AppUserModel?>? _selfUserFollowSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _followEdgeSub;
  /// True once [follow_edges] has been active for this pair (detect delete → unfollow sync).
  bool _followEdgeHadActive = false;
  int? _liveFollowerCount;
  int? _liveFollowingCount;
  int? _livePostCount;
  bool? _liveIsVerified;
  String? _liveAccountType;
  String? _liveBio;
  String? _liveProfileMusic;
  String? _liveUsername;
  String? _liveDisplayName;
  String? _liveAvatarUrl;
  bool? _liveVipVerified;
  bool? _liveMonetizationEnabled;
  StreamSubscription<int>? _followerCountSub;
  StreamSubscription<int>? _postCountSub;
  StreamSubscription<AppUserModel?>? _targetUserSub;
  final LiveStreamService _liveStreamService = LiveStreamService();
  final CreatorSubscriptionService _creatorSubscriptionService =
      CreatorSubscriptionService();
  StreamSubscription<List<LiveStreamModel>>? _discoverLiveSub;
  LiveStreamModel? _hostActiveLive;
  String? _otherHighlightsStreamUid;
  Stream<List<StoryHighlightModel>>? _otherHighlightsStream;
  String? _activeStoriesStreamUid;
  Stream<List<StoryModel>>? _activeStoriesStream;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.payload.isFollowing;
    _isSubscribed = widget.payload.isSubscribed;
    unawaited(_refreshFollowFromFirestore(server: true));
    _bindPendingFollowRequest();
    _bindFollowEdgeDoc();
    _bindCurrentUserFollowingStream();
    _refreshCreatorSubscriptionFromFirestore();
    _loadPublicCounts();
    _bindLiveCountStreams();
    _bindHostLiveStatus();
  }

  @override
  void didUpdateWidget(UserProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.payload.username != widget.payload.username ||
        oldWidget.payload.targetUserId != widget.payload.targetUserId) {
      _isFollowing = widget.payload.isFollowing;
      _isSubscribed = widget.payload.isSubscribed;
      _liveFollowerCount = null;
      _liveFollowingCount = null;
      _livePostCount = null;
      _liveIsVerified = null;
      _liveAccountType = null;
      _liveBio = null;
      _liveUsername = null;
      _liveDisplayName = null;
      _liveAvatarUrl = null;
      _liveVipVerified = null;
      _liveMonetizationEnabled = null;
      _otherHighlightsStreamUid = null;
      _otherHighlightsStream = null;
      _activeStoriesStreamUid = null;
      _activeStoriesStream = null;
      _highlightsExpanded = false;
      _highlightsAutoExpanded = false;
      final nextUid = widget.payload.targetUserId?.trim() ?? '';
      if (nextUid.isNotEmpty) {
        ProfileCachedPostsGrid.invalidateCacheFor(nextUid);
      }
      unawaited(_refreshFollowFromFirestore(server: true));
      _bindPendingFollowRequest();
      _bindFollowEdgeDoc();
      _bindCurrentUserFollowingStream();
      _refreshCreatorSubscriptionFromFirestore();
      _loadPublicCounts();
      _bindLiveCountStreams();
      _bindHostLiveStatus();
    }
  }

  void _bindHostLiveStatus() {
    _discoverLiveSub?.cancel();
    _discoverLiveSub = null;
    final id = widget.payload.targetUserId?.trim() ?? '';
    if (id.isEmpty) {
      if (_hostActiveLive != null && mounted) {
        setState(() => _hostActiveLive = null);
      }
      return;
    }
    _discoverLiveSub = _liveStreamService.liveStreams().listen((streams) {
      if (!mounted) return;
      LiveStreamModel? match;
      for (final stream in streams) {
        if (stream.hostId == id) {
          match = stream;
          break;
        }
      }
      if (_hostActiveLive?.id == match?.id) return;
      setState(() => _hostActiveLive = match);
    });
  }

  @override
  void dispose() {
    _pendingFollowSub?.cancel();
    _followEdgeSub?.cancel();
    _selfUserFollowSub?.cancel();
    _followerCountSub?.cancel();
    _postCountSub?.cancel();
    _targetUserSub?.cancel();
    _discoverLiveSub?.cancel();
    super.dispose();
  }

  void _bindLiveCountStreams() {
    _followerCountSub?.cancel();
    _postCountSub?.cancel();
    _targetUserSub?.cancel();
    final id = widget.payload.targetUserId;
    if (id == null || id.isEmpty) return;
    final svc = UserService();
    _followerCountSub = svc.followerCountStream(id).listen((v) {
      if (!mounted) return;
      setState(() => _liveFollowerCount = v);
    });
    _postCountSub = svc.reelCountStream(id).listen((v) {
      if (!mounted) return;
      setState(() => _livePostCount = v);
    });
    _targetUserSub = svc.userStream(id).listen((u) {
      if (!mounted) return;
      setState(() {
        _liveFollowingCount = u?.following.length ?? 0;
        _liveIsVerified = u?.isVerified;
        _liveAccountType = u?.accountType;
        _liveBio = u?.bio;
        _liveProfileMusic = u?.profileMusic;
        _liveUsername = u?.username;
        _liveDisplayName = u?.displayName;
        _liveAvatarUrl = u?.profileImage;
        _liveVipVerified = u?.vipVerified;
        _liveMonetizationEnabled = u?.monetizationEnabled;
      });
    });
  }

  bool _showSubscribeFeatures(UserProfilePayload p) {
    return showProfileSubscribeFeatures(
      accountType: _liveAccountType ?? p.accountType,
      monetizationEnabled:
          _liveMonetizationEnabled ?? p.monetizationEnabled,
    );
  }

  Future<void> _loadPublicCounts() async {
    final id = widget.payload.targetUserId;
    if (id == null || id.isEmpty) return;
    final svc = UserService();
    final fc = await svc.getFollowerCount(id);
    final pc = await svc.getReelCountForUser(id);
    final u = await svc.getUser(id);
    if (!mounted) return;
    setState(() {
      _liveFollowerCount = fc;
      _liveFollowingCount = u?.following.length ?? 0;
      _livePostCount = pc;
      _liveBio = u?.bio;
      _liveProfileMusic = u?.profileMusic;
    });
  }

  static String _accountTypeLabel(String? raw) {
    final key = (raw ?? '').trim().toLowerCase();
    if (_accountTypeLabels.containsKey(key)) return _accountTypeLabels[key]!;
    if (key.isEmpty) return _accountTypeLabels['personal']!;
    return key
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _resolvedBio(UserProfilePayload p) {
    final live = (_liveBio ?? '').trim();
    if (live.isNotEmpty) return live;
    return p.bio.trim();
  }

  String _resolvedProfileMusic(UserProfilePayload p) {
    final live = (_liveProfileMusic ?? '').trim();
    if (live.isNotEmpty) return live;
    return p.profileMusic.trim();
  }

  String _resolvedUsername(UserProfilePayload p) {
    final live = (_liveUsername ?? '').trim();
    if (live.isNotEmpty) return live;
    return p.username.trim();
  }

  String _resolvedDisplayName(UserProfilePayload p) {
    final live = (_liveDisplayName ?? '').trim();
    if (live.isNotEmpty) return live;
    final fallback = p.displayName.trim();
    if (fallback.isNotEmpty) return fallback;
    return _resolvedUsername(p);
  }

  String _resolvedAvatarUrl(UserProfilePayload p) {
    final live = (_liveAvatarUrl ?? '').trim();
    if (live.isNotEmpty) return live;
    return p.avatarUrl.trim();
  }

  Future<void> _refreshFollowFromFirestore({bool server = false}) async {
    final target = widget.payload.targetUserId;
    final me = AuthService().currentUser?.uid;
    if (target == null ||
        target.isEmpty ||
        me == null ||
        me.isEmpty ||
        me == target) {
      return;
    }
    final svc = UserService();
    final v = await svc.isFollowingUser(
      currentUid: me,
      targetUid: target,
      server: server,
    );
    final edgeActive = await svc.isFollowEdgeActive(
      requesterUid: me,
      targetUid: target,
      server: server,
    );
    final pending = await svc.outgoingFollowRequestPending(
      requesterUid: me,
      targetUid: target,
      server: server,
    );
    if (mounted) {
      setState(() {
        final following = v || edgeActive;
        _isFollowing = following;
        // Do not show Follow while request is pending or accepted-but-CF-pending.
        _pendingFollowRequest = pending && !following;
      });
    }
  }

  /// After the owner accepts, the follow_request doc is deleted before
  /// `users/me.following` always reflects the new edge — re-read a few times
  /// so we do not briefly (or permanently) show Follow instead of Following.
  Future<void> _reconcileFollowAfterRequestResolved() async {
    // After accept, local cache can still omit the new following edge for a bit;
    // Source.server avoids showing Follow until the write is visible.
    for (var step = 0; step < 12; step++) {
      if (!mounted) return;
      if (step > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 280));
      }
      if (!mounted) return;
      await _refreshFollowFromFirestore(server: true);
      if (!mounted) return;
      if (_isFollowing) return;
    }
  }

  /// Server-written when a private follow is accepted; survives client cache races
  /// on `users/{me}.following` (see [UserService.followEdgesCollection]).
  void _bindFollowEdgeDoc() {
    _followEdgeSub?.cancel();
    _followEdgeSub = null;
    _followEdgeHadActive = false;
    final target = widget.payload.targetUserId;
    final me = AuthService().currentUser?.uid;
    if (target == null ||
        target.isEmpty ||
        me == null ||
        me.isEmpty ||
        me == target) {
      return;
    }
    _followEdgeSub = UserService()
        .watchFollowEdgeDoc(requesterUid: me, targetUid: target)
        .listen((DocumentSnapshot<Map<String, dynamic>> snap) {
      if (!mounted) return;
      final d = snap.data();
      final active = snap.exists && (d?['active'] as bool? ?? true);
      if (active) {
        _followEdgeHadActive = true;
        setState(() {
          _isFollowing = true;
          _pendingFollowRequest = false;
        });
        return;
      }
      if (_followEdgeHadActive) {
        _followEdgeHadActive = false;
        unawaited(_refreshFollowFromFirestore(server: true));
      }
    });
  }

  void _bindPendingFollowRequest() {
    _pendingFollowSub?.cancel();
    _pendingFollowSub = null;
    final target = widget.payload.targetUserId;
    final me = AuthService().currentUser?.uid;
    if (target == null ||
        target.isEmpty ||
        me == null ||
        me.isEmpty ||
        me == target) {
      return;
    }
    _pendingFollowSub = UserService()
        .watchOutgoingFollowRequestPending(requesterUid: me, targetUid: target)
        .listen((pending) {
      if (!mounted) return;
      final wasPending = _pendingFollowRequest;
      setState(() => _pendingFollowRequest = pending);
      if (wasPending && !pending) {
        unawaited(_refreshFollowFromFirestore(server: true));
        unawaited(_reconcileFollowAfterRequestResolved());
      }
    });
  }

  void _bindCurrentUserFollowingStream() {
    _selfUserFollowSub?.cancel();
    _selfUserFollowSub = null;
    final target = widget.payload.targetUserId;
    final me = AuthService().currentUser?.uid;
    if (target == null ||
        target.isEmpty ||
        me == null ||
        me.isEmpty ||
        me == target) {
      return;
    }
    _selfUserFollowSub = UserService().userStream(me).listen((u) {
      if (!mounted || u == null) return;
      final nowFollowing = u.following.contains(target);
      // Do not set _isFollowing to false from this stream: snapshots can briefly
      // lag the server after an accept, which would flip the button back to Follow.
      if (!nowFollowing) return;
      setState(() {
        _isFollowing = true;
        _pendingFollowRequest = false;
      });
    });
  }

  bool _targetRequiresFollowRequest(UserProfilePayload p) {
    return UserService.accountTypeRequiresFollowApproval(
      _liveAccountType ?? p.accountType,
    );
  }

  bool _isViewingOwnProfile(UserProfilePayload p) {
    final me = AuthService().currentUser?.uid;
    final tid = (p.targetUserId ?? '').trim();
    return me != null && tid.isNotEmpty && me == tid;
  }

  bool _locksContentForViewer(UserProfilePayload p) {
    if (_isViewingOwnProfile(p)) return false;
    return UserService.accountTypeRequiresFollowApproval(
      _liveAccountType ?? p.accountType,
    );
  }

  /// Followers/following lists: visible for public/business/government, or private
  /// once the viewer has an accepted follow (same rule as posts).
  bool _canViewFollowersFollowingLists(UserProfilePayload p) {
    final uid = (p.targetUserId ?? '').trim();
    if (uid.isEmpty) return false;
    if (_isViewingOwnProfile(p)) return true;
    if (!_locksContentForViewer(p)) return true;
    return _isFollowing;
  }

  void _openFollowersFollowing(UserProfilePayload p, int initialTab) {
    final uid = (p.targetUserId ?? '').trim();
    if (uid.isEmpty) return;
    if (!_canViewFollowersFollowingLists(p)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Follow this account to see their followers and following.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FollowersFollowingScreen(
          initialTab: initialTab.clamp(0, 2),
          profileUserId: uid,
        ),
      ),
    );
  }

  bool _canViewTheirHighlights(UserProfilePayload p) {
    final uid = (p.targetUserId ?? '').trim();
    if (uid.isEmpty) return false;
    final me = AuthService().currentUser?.uid;
    if (me == null || me.isEmpty) return false;
    if (me == uid) return true;
    if (_locksContentForViewer(p) && !_isFollowing) return false;
    return true;
  }

  bool _canViewTheirStories(UserProfilePayload p) => _canViewTheirHighlights(p);

  Stream<List<StoryModel>> _activeStoriesStreamFor(String uid) {
    if (_activeStoriesStreamUid != uid || _activeStoriesStream == null) {
      _activeStoriesStreamUid = uid;
      _activeStoriesStream = StoryService().watchActiveStoriesForUser(uid);
    }
    return _activeStoriesStream!;
  }

  Future<void> _openUserStoryViewer(
    UserProfilePayload p,
    List<StoryModel> stories,
  ) async {
    if (stories.isEmpty || !mounted) return;
    final userId = (p.targetUserId ?? '').trim();
    if (userId.isEmpty) return;
    final viewerUid = AuthService().currentUser?.uid ?? '';
    final initialStoryIndex = viewerUid.isEmpty
        ? 0
        : stories.indexWhere((s) => !s.isViewedBy(viewerUid));
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => StoryViewerScreen(
          groups: [
            StoryGroup(
              userId: userId,
              username: _resolvedUsername(p),
              avatarUrl: _resolvedAvatarUrl(p),
              stories: stories,
            ),
          ],
          initialGroupIndex: 0,
          initialStoryIndex: initialStoryIndex == -1 ? 0 : initialStoryIndex,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  Stream<List<StoryHighlightModel>> _otherUserHighlightsStream(String uid) {
    if (_otherHighlightsStreamUid != uid || _otherHighlightsStream == null) {
      _otherHighlightsStreamUid = uid;
      _otherHighlightsStream = StoryService().watchHighlightsForUser(uid);
    }
    return _otherHighlightsStream!;
  }

  Widget _buildOtherUserHighlightsArea(UserProfilePayload p) {
    if (!_canViewTheirHighlights(p)) return const SizedBox.shrink();
    final uid = (p.targetUserId ?? '').trim();
    if (uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<List<StoryHighlightModel>>(
      stream: _otherUserHighlightsStream(uid),
      builder: (context, snap) {
        if (snap.hasError) {
          dev.log(
            'UserProfileScreen highlights stream',
            error: snap.error,
          );
          return const SizedBox.shrink();
        }
        final highlights = snap.data ?? const <StoryHighlightModel>[];
        final loading =
            snap.connectionState == ConnectionState.waiting && !snap.hasData;
        if (!loading && highlights.isEmpty) return const SizedBox.shrink();

        if (highlights.isNotEmpty && !_highlightsAutoExpanded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _highlightsAutoExpanded) return;
            setState(() {
              _highlightsExpanded = true;
              _highlightsAutoExpanded = true;
            });
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_highlightsExpanded) ...[
              ProfileTabUnderFirstTab(
                tabCount: _tabs.length,
                showBookmarkAccessory: true,
                showStarAccessory: true,
                child: ProfileHighlightsToggleHandle(
                  expanded: false,
                  onTap: () => setState(() => _highlightsExpanded = true),
                ),
              ),
            ] else ...[
              const SizedBox(
                height: ProfileFigmaTokens.highlightsSectionTopGap,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _buildOtherUserHighlightsRow(
                  context,
                  uid: uid,
                  highlights: highlights,
                  loading: loading,
                ),
              ),
              const SizedBox(
                height: ProfileFigmaTokens.highlightsToggleTopGap,
              ),
              ProfileTabUnderFirstTab(
                tabCount: _tabs.length,
                showBookmarkAccessory: true,
                showStarAccessory: true,
                child: ProfileHighlightsToggleHandle(
                  expanded: true,
                  onTap: () => setState(() => _highlightsExpanded = false),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildOtherUserHighlightsRow(
    BuildContext context, {
    required String uid,
    required List<StoryHighlightModel> highlights,
    required bool loading,
  }) {
    return ProfileTabTrackRow(
      showBookmarkAccessory: true,
      showStarAccessory: true,
      alignWithPostsStart: true,
      child: SizedBox(
        height: ProfileFigmaTokens.highlightRowHeight,
        child: loading && highlights.isEmpty
            ? const Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ProfileFigmaTokens.tabSelectedFill,
                  ),
                ),
              )
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: highlights.length,
                separatorBuilder: (_, _) => const SizedBox(
                  width: ProfileFigmaTokens.highlightTileGap,
                ),
                itemBuilder: (_, i) {
                  final h = highlights[i];
                  return ProfileHighlightAlbumTile(
                    title: h.title,
                    coverMediaUrl: h.coverMediaUrl,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => HighlightViewerScreen(
                            userId: uid,
                            highlightId: h.id,
                            title: h.title,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  Widget _buildPrivateProfilePlaceholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 48,
            color: Colors.white.withValues(alpha: 0.45),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'This account is private',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Follow this account to see their posts, stories, and streams when they accept.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshCreatorSubscriptionFromFirestore() async {
    final creatorId = (widget.payload.targetUserId ?? '').trim();
    if (creatorId.isEmpty) return;
    final record = await _creatorSubscriptionService
        .getForCurrentSubscriberByCreator(creatorId);
    if (!mounted) return;
    setState(() => _isSubscribed = record?.isActive == true);
  }

  Future<void> _onFollowTap() async {
    final target = widget.payload.targetUserId;
    final me = AuthService().currentUser?.uid;
    if (target == null || target.isEmpty) {
      setState(() => _isFollowing = !_isFollowing);
      return;
    }
    if (me == null || me.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to follow people.')),
      );
      return;
    }
    if (me == target) return;
    if (_followActionBusy) return;
    setState(() => _followActionBusy = true);
    final svc = UserService();
    try {
      if (_isFollowing) {
        await svc.unfollowUser(currentUid: me, targetUid: target);
        if (mounted) {
          setState(() {
            _isFollowing = false;
            _pendingFollowRequest = false;
          });
        }
      } else if (_pendingFollowRequest) {
        await svc.cancelFollowRequest(requesterUid: me, targetUid: target);
        if (mounted) setState(() => _pendingFollowRequest = false);
      } else {
        await svc.followUser(currentUid: me, targetUid: target);
        if (mounted) {
          final nowFollowing = await svc.isFollowingUser(
            currentUid: me,
            targetUid: target,
          );
          final pending = nowFollowing
              ? false
              : await svc.outgoingFollowRequestPending(
                  requesterUid: me,
                  targetUid: target,
                );
          if (mounted) {
            setState(() {
              _isFollowing = nowFollowing;
              _pendingFollowRequest = pending;
            });
          }
        }
      }
      if (mounted) await _loadPublicCounts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messageForFirestore(e))));
      }
    } finally {
      if (mounted) setState(() => _followActionBusy = false);
    }
  }

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  bool _isValidNetworkUrl(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.isAbsolute || uri.host.isEmpty) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  Future<void> _shareProfile() async {
    final p = widget.payload;
    final username = _resolvedUsername(p);
    final ref = (p.targetUserId ?? username).trim();
    if (ref.isEmpty) return;
    final message = DeepLinkConfig.profileShareMessage(
      profileRef: ref,
      username: username,
    );
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? Rect.fromLTWH(0, 0, MediaQuery.sizeOf(context).width, 1)
        : box.localToGlobal(Offset.zero) & box.size;
    await Share.share(
      message,
      subject: 'Vyooo profile',
      sharePositionOrigin: origin,
    );
  }

  Future<void> _openChat() async {
    final target = widget.payload.targetUserId;
    final me = AuthService().currentUser;
    if (target == null || target.isEmpty || me == null || me.uid == target) {
      return;
    }
    try {
      final currentUser = await UserService().getUser(me.uid);
      final otherUser = await UserService().getUser(target);
      if (!mounted || currentUser == null || otherUser == null) return;

      final chatId = await ChatService().getOrCreateDirectChat(
        currentUser: currentUser,
        otherUser: otherUser,
      );
      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatThreadScreen(
            chatId: chatId,
            currentUser: currentUser,
            otherUser: otherUser,
          ),
        ),
      );
    } catch (e, st) {
      dev.log('UserProfileScreen._openChat failed', error: e, stackTrace: st);
      if (!mounted) return;
      final message = e is StateError
          ? e.message
          : 'Could not open chat';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payload;
    final username = _resolvedUsername(p);
    final displayName = _resolvedDisplayName(p);
    final avatarUrl = _resolvedAvatarUrl(p);
    final isVerified = _liveIsVerified ?? p.isVerified;
    final showCreatorMonetization = _showSubscribeFeatures(p);
    final badgeColor = showCreatorMonetization
        ? const Color(0xFFFACC15)
        : verificationBadgeColor(
            isVerified: isVerified,
            accountType: _liveAccountType ?? p.accountType,
            vipVerified: _liveVipVerified ?? p.vipVerified,
          );
    final showVerificationBadge = isVerified || showCreatorMonetization;
    final currentUid = AuthService().currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: ProfileFigmaTokens.screenBackground,
      bottomNavigationBar: StreamBuilder<AppUserModel?>(
        stream: currentUid.isEmpty ? null : UserService().userStream(currentUid),
        builder: (context, snapshot) {
          return AppBottomNavigation(
            currentIndex: -1,
            profileImageUrl: snapshot.data?.profileImage,
            onTap: (index) {
              MainNavWrapper.tabNotifier.value = index;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          );
        },
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: ProfileScreenBackground()),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: ProfileFigmaTokens.screenBackground,
                elevation: 0,
                centerTitle: true,
                titleSpacing: 0,
                leadingWidth: 44,
                leading: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: ProfileFigmaTokens.primaryText,
                    size: 20,
                  ),
                ),
                title: Text(
                  '@${ProfileFigmaTokens.displayUsername(username)}',
                  style: const TextStyle(
                    fontFamily: 'DM Sans',
                    color: ProfileFigmaTokens.primaryText,
                    fontSize: ProfileFigmaTokens.headerUsernameFontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: () => _showProfileMenu(context),
                    icon: const Icon(
                      Icons.menu_rounded,
                      color: ProfileFigmaTokens.primaryText,
                      size: 28,
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ProfileFigmaTokens.profileHeaderHorizontalPad,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      StreamBuilder<List<StoryModel>>(
                        stream: (p.targetUserId ?? '').trim().isEmpty
                            ? null
                            : _activeStoriesStreamFor(p.targetUserId!.trim()),
                        builder: (context, snap) {
                          final stories = snap.data ?? const <StoryModel>[];
                          final canView = _canViewTheirStories(p);
                          final hasStory = canView && stories.isNotEmpty;
                          return _buildAvatar(
                            avatarUrl,
                            isLive: _hostActiveLive != null,
                            hasStory: hasStory,
                            onTap: hasStory
                                ? () => _openUserStoryViewer(p, stories)
                                : null,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      ProfileFigmaDisplayNameRow(
                        displayName: displayName,
                        isVerified: showVerificationBadge,
                        badgeColor: badgeColor,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ProfileFigmaStatChip(
                            label: 'Posts',
                            value: _formatCount(_livePostCount ?? p.postCount),
                          ),
                          const SizedBox(
                            width: ProfileFigmaTokens.statChipGap,
                          ),
                          ProfileFigmaStatChip(
                            label: 'Followers',
                            value: _formatCount(
                              _liveFollowerCount ?? p.followerCount,
                            ),
                            onTap: () => _openFollowersFollowing(p, 0),
                          ),
                          const SizedBox(
                            width: ProfileFigmaTokens.statChipGap,
                          ),
                          ProfileFigmaStatChip(
                            label: 'Following',
                            value: _formatCount(
                              _liveFollowingCount ?? p.followingCount,
                            ),
                            onTap: () => _openFollowersFollowing(p, 1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildProfileInfoSection(p),
                      const SizedBox(height: 20),
                      if (_hostActiveLive != null) ...[
                        ProfileLiveJoinBanner(
                          streamTitle: _hostActiveLive!.title,
                          viewerCount: _hostActiveLive!.viewerCount,
                          thumbnailUrl: _hostActiveLive!.hostProfileImage?.trim().isNotEmpty == true
                              ? _hostActiveLive!.hostProfileImage!
                              : avatarUrl,
                          onJoinTap: () => openLiveStreamScreen(
                            context,
                            _hostActiveLive!,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildActionButtons(p),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              DecoratedSliver(
                decoration: const BoxDecoration(
                  color: _profileSurface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          ProfileFigmaTokens.profileHeaderHorizontalPad,
                          24,
                          ProfileFigmaTokens.profileHeaderHorizontalPad,
                          0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTabs(),
                            _buildOtherUserHighlightsArea(p),
                          ],
                        ),
                      ),
                    ),
                    ..._buildContentSlivers(p),
                  ],
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: AppBottomNavigation.totalHeightFor(context),
                ),
                sliver: const SliverToBoxAdapter(
                  child: SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(
    String avatarUrl, {
    required bool isLive,
    bool hasStory = false,
    VoidCallback? onTap,
  }) {
    final outer = ProfileFigmaTokens.avatarOuterSize;

    if (isLive) {
      return GestureDetector(
        onTap: onTap,
        child: LiveAvatarRing(
          size: outer,
          showLivePill: true,
          child: ProfileFigmaAvatar(
            imageUrl: avatarUrl,
            hasStory: false,
          ),
        ),
      );
    }

    return ProfileFigmaAvatar(
      imageUrl: avatarUrl,
      hasStory: hasStory,
      onTap: onTap,
    );
  }

  void _onSubscribeTap(UserProfilePayload p) {
    if (_isSubscribed) {
      _showSubscriptionNotificationsSheet(p);
      return;
    }
    Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CreatorSubscriptionScreen(
          name: _resolvedDisplayName(p),
          handle: ProfileFigmaTokens.displayUsername(_resolvedUsername(p)),
          avatarUrl: p.avatarUrl,
          creatorUserId: p.targetUserId,
          isVerified: p.isVerified,
        ),
      ),
    ).then((bool? subscribed) {
      if (!mounted) return;
      if (subscribed == true) {
        setState(() => _isSubscribed = true);
      }
    });
  }

  Future<void> _cancelCreatorSubscription(UserProfilePayload p) async {
    final creatorId = (p.targetUserId ?? '').trim();
    if (creatorId.isEmpty) {
      setState(() => _isSubscribed = false);
      return;
    }
    try {
      await _creatorSubscriptionService.cancelSubscription(creatorId: creatorId);
      if (!mounted) return;
      setState(() => _isSubscribed = false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to cancel subscription.')),
      );
    }
  }

  void _showSubscriptionNotificationsSheet(UserProfilePayload p) {
    var selected = 0;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      isScrollControlled: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A1B2E).withValues(alpha: 0.92),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        AppSpacing.lg,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Text(
                            'Notifications',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _SubscriptionNotifyOption(
                            icon: Icons.notifications_none_rounded,
                            label: 'All',
                            selected: selected == 0,
                            onTap: () => setSheetState(() => selected = 0),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _SubscriptionNotifyOption(
                            icon: Icons.notifications_off_outlined,
                            label: 'None',
                            selected: selected == 1,
                            onTap: () => setSheetState(() => selected = 1),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _SubscriptionNotifyOption(
                            icon: Icons.person_remove_alt_1_outlined,
                            label: 'Unsubscribe',
                            selected: selected == 2,
                            onTap: () async {
                              Navigator.pop(sheetCtx);
                              await _cancelCreatorSubscription(p);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProfileInfoSection(UserProfilePayload p) {
    final bio = _resolvedBio(p);
    final profileMusic = _resolvedProfileMusic(p);
    final accountLabel =
        _accountTypeLabel(_liveAccountType ?? p.accountType);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: ProfileFigmaTokens.cardBackground,
            borderRadius: BorderRadius.circular(_profileActionRadius),
          ),
          child: Text(
            accountLabel,
            style: const TextStyle(
              fontFamily: 'DM Sans',
              color: ProfileFigmaTokens.secondaryText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ProfileBioText(bio: bio),
          ),
        ],
        ProfileFigmaMusicLine(label: profileMusic),
      ],
    );
  }

  Widget _buildActionButtons(UserProfilePayload p) {
    final followLabel = _followActionBusy
        ? '…'
        : (_isFollowing
            ? 'Following'
            : (_targetRequiresFollowRequest(p) && _pendingFollowRequest
                ? 'Requested'
                : 'Follow'));
    final followOutlined = _isFollowing ||
        (_targetRequiresFollowRequest(p) && _pendingFollowRequest);

    final showChat = widget.payload.targetUserId != null &&
        widget.payload.targetUserId!.isNotEmpty &&
        widget.payload.targetUserId != AuthService().currentUser?.uid &&
        (!_locksContentForViewer(p) || _isFollowing);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: _profileActionGroupMaxWidth,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ProfileFollowButton(
                label: followLabel,
                outlined: followOutlined,
                onPressed: _followActionBusy ? () {} : _onFollowTap,
              ),
              if (_showSubscribeFeatures(p) && !_isViewingOwnProfile(p)) ...[
                const SizedBox(
                  width: ProfileFigmaTokens.actionButtonGap,
                ),
                _ProfileSubscribeButton(
                  label: _isSubscribed ? 'Subscribed' : 'Subscribe',
                  outlined: _isSubscribed,
                  onPressed: () => _onSubscribeTap(p),
                ),
              ],
              if (showChat) ...[
                const SizedBox(
                  width: ProfileFigmaTokens.actionButtonGap,
                ),
                ProfileFigmaIconActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  onPressed: _openChat,
                ),
              ],
              const SizedBox(
                width: ProfileFigmaTokens.actionButtonGap,
              ),
              ProfileFigmaIconActionButton(
                svgAssetPath: ProfileAssets.profileActionShare,
                onPressed: _shareProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
    final target = widget.payload.targetUserId;
    final me = AuthService().currentUser?.uid;
    final canModerate = target != null && target.isNotEmpty && target != me;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canModerate) ...[
                ListTile(
                  leading: Icon(
                    Icons.report_outlined,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  title: const Text(
                    'Report',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    showReportUserSheet(
                      context,
                      username: _resolvedUsername(widget.payload),
                      avatarUrl: _resolvedAvatarUrl(widget.payload),
                      targetUserId: target,
                      isFollowing: _isFollowing,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.block_flipped,
                    color: Color(0xFFEF4444),
                  ),
                  title: const Text(
                    'Block User',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    showBlockUserSheet(
                      context,
                      username: _resolvedDisplayName(widget.payload),
                      avatarUrl: _resolvedAvatarUrl(widget.payload),
                      targetUserId: target,
                    );
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return ProfileFigmaTabBar(
      tabs: _tabs,
      selectedIndex: _selectedTabIndex,
      onTabSelected: (i) => setState(() => _selectedTabIndex = i),
      savedTabIndex: _savedTabIndex,
      onSavedTap: () => setState(() => _selectedTabIndex = _savedTabIndex),
      onBookmarkTap: () => setState(() => _selectedTabIndex = _savedTabIndex),
    );
  }

  List<Widget> _buildContentSlivers(UserProfilePayload p) {
    if (_selectedTabIndex == _savedTabIndex) {
      return _buildSavedGridSlivers();
    }
    switch (_selectedTabIndex) {
      case 0:
        return _buildPostsSlivers(p);
      case 1:
        return _buildVRGridSlivers(p);
      case 2:
        return _buildClipsListSlivers(p);
      case 3:
        return _buildTagsGridSlivers(p);
      default:
        return [
          SliverToBoxAdapter(
            child: SizedBox(height: 280, child: _buildEmptyTab()),
          ),
        ];
    }
  }

  List<Widget> _buildPostsSlivers(UserProfilePayload p) {
    final targetUid = (p.targetUserId ?? '').trim();
    if (targetUid.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 280,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 48,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No posts made yet',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }
    if (_locksContentForViewer(p) && !_isFollowing) {
      return [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 280,
            child: _buildPrivateProfilePlaceholder(),
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: ProfileCachedPostsGrid(
          key: ValueKey('user-profile-posts-$targetUid'),
          userId: targetUid,
          padding: ProfileFigmaTokens.profileGridPadding,
          thumbnailFor: ProfileReelGridNavigation.thumbnailFromReel,
          onItemTap: (context, posts, index) =>
              ProfileReelGridNavigation.openPostFeed(
            context: context,
            posts: posts,
            index: index,
            fallbackDisplayName: _resolvedDisplayName(widget.payload),
            fallbackUsername: _resolvedUsername(widget.payload),
            fallbackAvatarUrl: _resolvedAvatarUrl(widget.payload),
            fallbackIsVerified: widget.payload.isVerified,
            liveIsVerified: _liveIsVerified,
          ),
          empty: SizedBox(
            height: 280,
            child: Center(
              child: Text(
                'No posts made yet',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildVRGridSlivers(UserProfilePayload p) {
    final targetUid = (p.targetUserId ?? '').trim();
    if (_locksContentForViewer(p) && !_isFollowing) {
      return [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 280,
            child: _buildPrivateProfilePlaceholder(),
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: ProfilePostsLoader.loadVrForUser(targetUid),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white54),
                ),
              );
            }
            final reels = (snapshot.data ?? const <Map<String, dynamic>>[])
                .where((r) => (r['userId']?.toString() ?? '') == targetUid)
                .toList(growable: false)
              ..sort(ProfileReelGridNavigation.sortReelsNewestFirst);
            if (reels.isEmpty) {
              return _buildEmptyTab();
            }
            return ProfileModularGrid(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              items: profileGridItemsFromReels(
                reels: reels,
                thumbnailFor: ProfileReelGridNavigation.thumbnailFromReel,
                showVrBadge: true,
              ),
              onItemTap: (index) => ProfileReelGridNavigation.openVRDetail(
                context: context,
                item: reels[index],
              ),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _buildTagsGridSlivers(UserProfilePayload p) {
    final targetUid = (p.targetUserId ?? '').trim();
    if (_locksContentForViewer(p) && !_isFollowing) {
      return [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 280,
            child: _buildPrivateProfilePlaceholder(),
          ),
        ),
      ];
    }
    if (targetUid.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: SizedBox(height: 280, child: _buildEmptyTagsTab()),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: ProfilePostsLoader.loadPostsForUser(targetUid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(
                    color: ProfileFigmaTokens.accentMagenta,
                  ),
                ),
              );
            }
            final tagged = (snapshot.data ?? const [])
                .where((post) {
                  final tags = post['tags'];
                  return tags is List && tags.isNotEmpty;
                })
                .toList(growable: false);
            if (tagged.isEmpty) {
              return SizedBox(height: 280, child: _buildEmptyTagsTab());
            }
            return ProfileModularGrid(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              items: profileGridItemsFromReels(
                reels: tagged,
                thumbnailFor: ProfileReelGridNavigation.thumbnailFromReel,
              ),
              onItemTap: (index) => ProfileReelGridNavigation.openPostFeed(
                context: context,
                posts: tagged,
                index: index,
                fallbackDisplayName: _resolvedDisplayName(p),
                fallbackUsername: _resolvedUsername(p),
                fallbackAvatarUrl: _resolvedAvatarUrl(p),
                fallbackIsVerified: p.isVerified,
                liveIsVerified: _liveIsVerified,
              ),
            );
          },
        ),
      ),
    ];
  }

  Widget _buildEmptyTagsTab() {
    return Center(
      child: Text(
        'No tagged posts yet',
        style: const TextStyle(
          fontFamily: 'DM Sans',
          color: ProfileFigmaTokens.secondaryText,
          fontSize: 16,
        ),
      ),
    );
  }

  List<Widget> _buildClipsListSlivers(UserProfilePayload p) {
    final targetUid = (p.targetUserId ?? '').trim();
    if (_locksContentForViewer(p) && !_isFollowing) {
      return [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 280,
            child: _buildPrivateProfilePlaceholder(),
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: StreamBuilder<List<LiveStreamModel>>(
          stream: _liveStreamService.savedStreams(targetUid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white54),
                ),
              );
            }
            var streams = snapshot.data ?? const <LiveStreamModel>[];
            final active = _hostActiveLive;
            if (active != null && !streams.any((s) => s.id == active.id)) {
              streams = [active, ...streams];
            }
            if (streams.isEmpty) return _buildEmptyTab();
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              itemCount: streams.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final stream = streams[index];
                return SizedBox(
                  height: 200,
                  child: _UserProfileStreamCard(
                    item: _UserProfileStreamItem(
                      thumbnailUrl: (stream.hostProfileImage ?? '').isNotEmpty
                          ? stream.hostProfileImage!
                          : 'https://i.pravatar.cc/240?u=${stream.hostId}',
                      title: stream.title,
                      subtitle: stream.status == LiveStreamStatus.live
                          ? 'Streaming now'
                          : 'Saved stream',
                      isLive: stream.status == LiveStreamStatus.live,
                      viewCount: stream.viewerCount,
                    ),
                    onTap: () => openLiveStreamScreen(context, stream),
                  ),
                );
              },
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _buildSavedGridSlivers() {
    final targetUid = (widget.payload.targetUserId ?? '').trim();
    if (targetUid.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: SizedBox(height: 280, child: _buildEmptyTab()),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: ReelsController().fetchFavoriteReelsForProfile(targetUid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white54),
                ),
              );
            }
            final savedReels = snapshot.data ?? <Map<String, dynamic>>[];
            if (savedReels.isEmpty) {
              return _buildEmptyTab();
            }
            return ProfileModularGrid(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              items: profileGridItemsFromReels(
                reels: savedReels,
                thumbnailFor: ProfileReelGridNavigation.thumbnailFromReel,
              ),
              onItemTap: (index) => ProfileReelGridNavigation.openPostFeed(
                context: context,
                posts: savedReels,
                index: index,
                fallbackDisplayName: _resolvedDisplayName(widget.payload),
                fallbackUsername: _resolvedUsername(widget.payload),
                fallbackAvatarUrl: _resolvedAvatarUrl(widget.payload),
                fallbackIsVerified: widget.payload.isVerified,
                liveIsVerified: _liveIsVerified,
              ),
            );
          },
        ),
      ),
    ];
  }

  Widget _buildEmptyTab() {
    return Center(
      child: Text(
        'No content yet',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 16,
        ),
      ),
    );
  }
}

class _UserProfileStreamItem {
  const _UserProfileStreamItem({
    required this.thumbnailUrl,
    required this.title,
    required this.subtitle,
    this.isLive = false,
    this.viewCount = 22500,
  });
  final String thumbnailUrl;
  final String title;
  final String subtitle;
  final bool isLive;
  final int viewCount;
}

class _ProfileFollowButton extends StatelessWidget {
  const _ProfileFollowButton({
    required this.label,
    required this.outlined,
    required this.onPressed,
  });

  final String label;
  final bool outlined;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(_profileActionRadius);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: radius,
        child: Ink(
          height: ProfileFigmaTokens.profileFollowButtonHeight,
          padding: const EdgeInsets.symmetric(
            horizontal: ProfileFigmaTokens.actionButtonPaddingH,
          ),
          decoration: BoxDecoration(
            color: outlined ? Colors.transparent : _profileAccentMagenta,
            borderRadius: radius,
            border: Border.all(
              color: outlined
                  ? ProfileFigmaTokens.profileFollowingBorder
                  : const Color(0xFFC4185A),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: outlined
                    ? ProfileFigmaTokens.primaryText
                    : Colors.white,
                fontSize: ProfileFigmaTokens.profileFollowLabelFontSize,
                fontWeight: outlined ? FontWeight.w500 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSubscribeButton extends StatelessWidget {
  const _ProfileSubscribeButton({
    required this.label,
    required this.outlined,
    required this.onPressed,
  });

  final String label;
  final bool outlined;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(_profileActionRadius);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: radius,
        child: Ink(
          height: ProfileFigmaTokens.actionButtonHeight,
          padding: const EdgeInsets.symmetric(
            horizontal: ProfileFigmaTokens.actionButtonPaddingH,
          ),
          decoration: BoxDecoration(
            gradient: outlined ? null : AppGradients.subscribeNowButtonGradient,
            color: outlined ? Colors.transparent : null,
            borderRadius: radius,
            border: outlined
                ? Border.all(
                    color: _profileAccentMagenta,
                    width: _profileOutlineWidth,
                  )
                : Border.all(
                    color: const Color(0xFFB8862E).withValues(alpha: 0.85),
                  ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: outlined
                    ? ProfileFigmaTokens.primaryText
                    : Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubscriptionNotifyOption extends StatelessWidget {
  const _SubscriptionNotifyOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? _profileAccentMagenta : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? _profileAccentMagenta
                        : Colors.white.withValues(alpha: 0.45),
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserProfileStreamCard extends StatelessWidget {
  const _UserProfileStreamCard({required this.item, this.onTap});

  final _UserProfileStreamItem item;
  final VoidCallback? onTap;

  static String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final thumbUri = Uri.tryParse(item.thumbnailUrl.trim());
    final hasValidThumb = thumbUri != null &&
        thumbUri.isAbsolute &&
        thumbUri.host.isNotEmpty &&
        (thumbUri.scheme == 'http' || thumbUri.scheme == 'https');
    final imageProvider = hasValidThumb ? NetworkImage(item.thumbnailUrl.trim()) : null;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageProvider != null)
              Image(
                image: imageProvider,
                fit: BoxFit.cover,
              )
            else
              Container(color: const Color(0xFF26172A)),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
            if (item.isLive)
              Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.sm,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.deleteRed,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    _formatCount(item.viewCount),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: AppSpacing.sm,
              right: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserProfileReelFeedScreen extends StatefulWidget {
  const _UserProfileReelFeedScreen({
    required this.reels,
    required this.initialIndex,
  });

  final List<Map<String, dynamic>> reels;
  final int initialIndex;

  @override
  State<_UserProfileReelFeedScreen> createState() =>
      _UserProfileReelFeedScreenState();
}

class _UserProfileReelFeedScreenState
    extends State<_UserProfileReelFeedScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  final ReelsController _reelsController = ReelsController();
  final Map<String, bool> _likedReels = {};
  final Set<String> _likeInFlight = {};
  final Map<String, bool> _favoriteReels = {};
  final Map<String, bool> _privateSavedReels = {};
  final Map<String, bool> _repostedSourceReels = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _warmInteractionState();
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _warmInteractionState() async {
    final engagementIds = <String>{
      for (final r in widget.reels) ReelEngagement.sourceReelId(r),
    }..removeWhere((id) => id.isEmpty);
    if (engagementIds.isEmpty) return;
    final likedIds = await _reelsController.getLikedReelIds(engagementIds);
    final favoriteIds = await _reelsController.getFavoriteReelIds(engagementIds);
    final privateIds =
        await _reelsController.getPrivateSavedReelIds(engagementIds);
    final repostedIds =
        await _reelsController.getRepostedSourceReelIds(engagementIds);
    if (!mounted) return;
    setState(() {
      for (final id in engagementIds) {
        _likedReels[id] = likedIds.contains(id);
        _favoriteReels[id] = favoriteIds.contains(id);
        _privateSavedReels[id] = privateIds.contains(id);
        _repostedSourceReels[id] = repostedIds.contains(id);
      }
    });
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static String _asString(dynamic value) => value?.toString() ?? '';

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  void _adjustReelStat(String engagementId, String key, int delta) {
    setState(() {
      for (var i = 0; i < widget.reels.length; i++) {
        if (ReelEngagement.sourceReelId(widget.reels[i]) != engagementId) {
          continue;
        }
        final current = _asInt(widget.reels[i][key]);
        final next = (current + delta).clamp(0, 1 << 30);
        widget.reels[i][key] = next;
        if (key == 'reposts' || key == 'shares') {
          widget.reels[i]['reposts'] = next;
          widget.reels[i]['shares'] = next;
        }
      }
    });
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
      if (!ok) return;
      setState(() {
        _repostedSourceReels[sourceId] = false;
        _adjustReelStat(sourceId, 'reposts', -1);
      });
      return;
    }
    final stubId = await _reelsController.repostReel(sourceReelId: sourceId);
    if (!mounted) return;
    if (stubId != null) {
      setState(() {
        _repostedSourceReels[sourceId] = true;
        _adjustReelStat(sourceId, 'reposts', 1);
      });
    }
  }

  Future<void> _onLike(String reelId, bool currentlyLiked) async {
    if (_likeInFlight.contains(reelId)) return;

    final wantLiked = !currentlyLiked;
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

    if (actual != wantLiked) {
      setState(() {
        _likedReels[reelId] = actual;
        _adjustReelStat(reelId, 'likes', wantLiked ? -1 : 1);
      });
    }
  }

  Future<void> _onFavorite(String reelId, bool currentlyFavorite) async {
    final newState = await _reelsController.toggleFavoriteReel(
      reelId: reelId,
      currentlyFavorite: currentlyFavorite,
    );
    if (!mounted) return;
    setState(() => _favoriteReels[reelId] = newState);
    _adjustReelStat(reelId, 'saves', newState ? 1 : -1);
  }

  Future<void> _onPrivateSave(String reelId) async {
    final currently = _privateSavedReels[reelId] ?? false;
    final newState = await _reelsController.togglePrivateSavedReel(
      reelId: reelId,
      currentlySaved: currently,
    );
    if (!mounted) return;
    setState(() => _privateSavedReels[reelId] = newState);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newState ? 'Saved privately' : 'Removed from private saves',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onShare(String reelId, Map<String, dynamic> reel) {
    final sourceId = ReelEngagement.sourceReelId(reel);
    final uid = AuthService().currentUser?.uid ?? '';
    showShareBottomSheet(
      context,
      reelId: sourceId,
      thumbnailUrl: ProfileReelGridNavigation.thumbnailFromReel(reel),
      authorName: _asString(reel['username']).isEmpty
          ? widget.reels[_currentIndex]['username']?.toString()
          : _asString(reel['username']),
      isOwnPost: _sourceOwnerId(reel) == uid,
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
    );
  }

  void _onComment(String reelId) {
    final reel = widget.reels.firstWhere(
      (r) => _asString(r['id']) == reelId,
      orElse: () => widget.reels[_currentIndex],
    );
    final engagementId = ReelEngagement.sourceReelId(reel);
    showCommentsBottomSheet(
      context,
      reelId: engagementId,
      onCommentCountChanged: (delta) =>
          _adjustReelStat(engagementId, 'comments', delta),
    );
  }

  void _onMoreOptions(String reelId, Map<String, dynamic> reel) {
    final authorId = _asString(reel['userId']).trim();
    showReelMoreOptionsSheet(
      context,
      reelId: reelId,
      playbackSpeed: 'Normal',
      quality: 'Auto (1080p HD)',
      onDownload: () {},
      onSavePrivately: () => _onPrivateSave(reelId),
      onReport: () => showReportSheet(
        context,
        username: _asString(reel['username']).isEmpty
            ? 'User'
            : _asString(reel['username']),
        avatarUrl: _asString(reel['avatarUrl']),
        targetUserId: authorId.isEmpty ? null : authorId,
        reelId: reelId,
        isFollowing: false,
      ),
      onNotInterested: () => showNotInterestedSheet(context),
      onCaptions: () {},
      onPlaybackSpeed: () {},
      onQuality: () {},
      onManagePreferences: () {},
      onWhyThisPost: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemCount: widget.reels.length,
            itemBuilder: (context, index) {
              final reel = widget.reels[index];
              final mediaItems = ReelMediaItem.listFromPost(reel);
              if (mediaItems.length > 1) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    PostMediaCarousel(
                      key: ValueKey<String>('carousel_${reel['id'] ?? index}'),
                      items: mediaItems,
                      video360: Video360Metadata.fromPost(reel),
                      imageFit: BoxFit.contain,
                      isVisible: index == _currentIndex,
                    ),
                    _buildActionButtons(index),
                  ],
                );
              }
              final mediaType = ((reel['mediaType'] as String?) ?? '')
                  .toLowerCase();
              if (mediaType == 'image') {
                final imageUrl = ((reel['imageUrl'] as String?) ?? '').trim();
                final thumbnailUrl = ((reel['thumbnailUrl'] as String?) ?? '')
                    .trim();
                final displayUrl = imageUrl.isNotEmpty
                    ? imageUrl
                    : thumbnailUrl;
                if (displayUrl.isNotEmpty) {
                  return SizedBox.expand(
                    child: ColoredBox(
                      color: Colors.black,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          displayUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                        ),
                        _buildActionButtons(index),
                      ],
                    ),
                    ),
                  );
                }
              }
              final videoUrl = (reel['videoUrl'] as String?)?.trim() ?? '';
              if (videoUrl.isEmpty) {
                return const SizedBox.expand(
                  child: ColoredBox(color: Colors.black),
                );
              }
              return Stack(
                fit: StackFit.expand,
                children: [
                  ReelItemWidget(
                    videoUrl: videoUrl,
                    video360: Video360Metadata.fromPost(reel),
                    isVisible: index == _currentIndex,
                  ),
                  _buildActionButtons(index),
                ],
              );
            },
          ),
          SafeArea(
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(int index) {
    final reel = widget.reels[index];
    final reelId = _asString(reel['id']).trim();
    if (reelId.isEmpty) return const SizedBox.shrink();
    final engagementId = ReelEngagement.sourceReelId(reel);
    final isLiked = _likedReels[engagementId] ?? false;
    final isFavorite = _favoriteReels[engagementId] ?? false;
    final privacy = ReelCountPrivacy.fromMap(reel);
    final uid = AuthService().currentUser?.uid ?? '';
    final canRepost =
        engagementId.isNotEmpty && _sourceOwnerId(reel) != uid;
    final isReposted = _repostedSourceReels[engagementId] ?? false;

    final bottomSafeInset = MediaQuery.paddingOf(context).bottom;
    final interactionBottom = 18.0 + bottomSafeInset;

    return Positioned(
      right: 16,
      bottom: interactionBottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppInteractionButton(
            icon: Icons.visibility_outlined,
            count: privacy.displayCount(
              ReelCountMetric.views,
              _asInt(reel['views']),
            ),
            iconSize: 24,
            textSize: 10,
            spacing: 3,
          ),
          const SizedBox(height: 12),
          AppInteractionButton(
            icon: isLiked ? Icons.favorite : Icons.favorite_border,
            count: privacy.displayCount(
              ReelCountMetric.likes,
              _asInt(reel['likes']),
            ),
            isActive: isLiked,
            activeColor: const Color(0xFFEF4444),
            countColor: Colors.white,
            onTap: () => _onLike(engagementId, isLiked),
            iconSize: 24,
            textSize: 10,
            spacing: 3,
          ),
          const SizedBox(height: 12),
          AppInteractionButton(
            icon: Icons.chat_bubble_outline,
            count: privacy.displayCount(
              ReelCountMetric.comments,
              _asInt(reel['comments']),
            ),
            onTap: () => _onComment(reelId),
            iconSize: 24,
            textSize: 10,
            spacing: 3,
          ),
          const SizedBox(height: 12),
          AppInteractionButton(
            iconAsset: FeedInteractionAssets.unsavePost,
            iconAssetActive: FeedInteractionAssets.savePost,
            count: privacy.displayCount(
              ReelCountMetric.saves,
              _asInt(reel['saves']),
            ),
            isActive: isFavorite,
            colorizeAsset: false,
            countColor: AppTheme.primary,
            onTap: () => _onFavorite(reelId, isFavorite),
            iconSize: 24,
            textSize: 10,
            spacing: 3,
          ),
          if (canRepost) ...[
            const SizedBox(height: 12),
            AppInteractionButton(
              icon: Icons.repeat_rounded,
              count: privacy.displayCount(
                ReelCountMetric.shares,
                ReelEngagement.repostCount(reel),
              ),
              isActive: isReposted,
              activeColor: AppTheme.primary,
              countColor: AppTheme.primary,
              onTap: () => _onRepostToggle(reel),
              iconSize: 24,
              textSize: 10,
              spacing: 3,
            ),
          ],
          const SizedBox(height: 12),
          AppInteractionButton(
            icon: Icons.ios_share_rounded,
            count: '',
            onTap: () => _onShare(reelId, reel),
            iconSize: 24,
            textSize: 10,
            spacing: 3,
          ),
          const SizedBox(height: 12),
          AppInteractionButton(
            icon: Icons.more_horiz,
            count: '',
            onTap: () => _onMoreOptions(reelId, reel),
            iconSize: 24,
          ),
        ],
      ),
    );
  }
}
