import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';

import '../../core/config/deep_link_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/app_user_model.dart';
import '../../core/models/live_stream_model.dart';
import '../../core/models/story_highlight_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/live_stream_service.dart';
import '../../core/services/reels_service.dart';
import '../../core/services/story_service.dart';
import '../../core/services/user_service.dart';
import '../../core/services/creator_subscription_service.dart';
import '../../core/utils/verification_badge.dart';
import '../../core/utils/user_facing_errors.dart';
import '../../core/controllers/reels_controller.dart';
import '../../core/widgets/app_interaction_button.dart';
import '../../core/widgets/app_bottom_navigation.dart';
import '../../core/wrappers/main_nav_wrapper.dart';
import '../../features/chat/services/chat_service.dart';
import '../../features/chat/screens/chat_thread_screen.dart';
import '../../features/comments/widgets/comments_bottom_sheet.dart';
import '../../features/share/widgets/share_bottom_sheet.dart';
import '../../features/reel/widgets/not_interested_sheet.dart';
import '../../features/reel/widgets/report_sheet.dart';
import '../../features/reel/widgets/reel_more_options_sheet.dart';
import '../content/live_stream_route.dart';
import '../content/post_feed_screen.dart';
import '../content/vr_detail_screen.dart';
import '../../widgets/reel_item_widget.dart';
import '../../features/reel/widgets/block_user_sheet.dart';
import '../../features/story/highlight_viewer_screen.dart';
import '../../features/story/widgets/profile_highlight_album_tile.dart';
import '../../features/subscription/creator_subscription_screen.dart';

const Color _profileBgTop = Color(0xFF3B0B30);
const Color _profileBgMid = Color(0xFF190624);
const Color _profileBgGlow = Color(0xFFE81E57);
const Color _profileBgBottom = Color(0xFF33092C);
const Color _profileSurface = Color(0xFF1A0B1E);

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
    this.isCreator = true,
    this.isFollowing = false,
    this.isSubscribed = false,
    this.targetUserId,
  });

  /// When set, Follow/Following updates Firestore (users/{currentUser}.following).
  final String? targetUserId;
  final String username;
  final String displayName;
  final String avatarUrl;
  final bool isVerified;
  final String accountType;
  final bool vipVerified;
  final int postCount;
  final int followerCount;
  final int followingCount;
  final String bio;

  /// If true, show Follow + Subscribe + Share. If false, show Follow + Share only (standard user).
  final bool isCreator;
  final bool isFollowing;
  final bool isSubscribed;
}

/// Other person's profile: same top (avatar, stats, buttons), Posts/VR/Streams + star, content by tab.
/// Design-only; backend integration later. Same flow for subscription creator or standard user.
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.payload});

  final UserProfilePayload payload;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  static const List<String> _tabs = ['Posts', 'VR', 'Streams'];
  static const int _savedTabIndex = 3;
  int _selectedTabIndex = 0;
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
  int? _liveSubscriberCount;
  bool? _liveIsVerified;
  String? _liveAccountType;
  bool? _liveVipVerified;
  StreamSubscription<int>? _followerCountSub;
  StreamSubscription<int>? _postCountSub;
  StreamSubscription<int>? _subscriberCountSub;
  StreamSubscription<AppUserModel?>? _targetUserSub;
  final LiveStreamService _liveStreamService = LiveStreamService();
  final CreatorSubscriptionService _creatorSubscriptionService =
      CreatorSubscriptionService();
  String? _otherHighlightsStreamUid;
  Stream<List<StoryHighlightModel>>? _otherHighlightsStream;

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
      _liveSubscriberCount = null;
      _liveIsVerified = null;
      _liveAccountType = null;
      _liveVipVerified = null;
      _otherHighlightsStreamUid = null;
      _otherHighlightsStream = null;
      unawaited(_refreshFollowFromFirestore(server: true));
      _bindPendingFollowRequest();
      _bindFollowEdgeDoc();
      _bindCurrentUserFollowingStream();
      _refreshCreatorSubscriptionFromFirestore();
      _loadPublicCounts();
      _bindLiveCountStreams();
    }
  }

  @override
  void dispose() {
    _pendingFollowSub?.cancel();
    _followEdgeSub?.cancel();
    _selfUserFollowSub?.cancel();
    _followerCountSub?.cancel();
    _postCountSub?.cancel();
    _subscriberCountSub?.cancel();
    _targetUserSub?.cancel();
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
    // creatorSubscriptions list reads are only allowed for the creator (Firestore rules).
    final me = AuthService().currentUser?.uid;
    if (me != null && me.isNotEmpty && me == id) {
      _subscriberCountSub =
          _creatorSubscriptionService.subscriberCountStream(id).listen((v) {
        if (!mounted) return;
        setState(() => _liveSubscriberCount = v);
      });
    }
    _targetUserSub = svc.userStream(id).listen((u) {
      if (!mounted) return;
      setState(() {
        _liveFollowingCount = u?.following.length ?? 0;
        _liveIsVerified = u?.isVerified;
        _liveAccountType = u?.accountType;
        _liveVipVerified = u?.vipVerified;
      });
    });
  }

  Future<void> _loadPublicCounts() async {
    final id = widget.payload.targetUserId;
    if (id == null || id.isEmpty) return;
    final svc = UserService();
    final fc = await svc.getFollowerCount(id);
    final pc = await svc.getReelCountForUser(id);
    final me = AuthService().currentUser?.uid;
    final sc = (me != null && me.isNotEmpty && me == id)
        ? await _creatorSubscriptionService.getSubscriberCount(id)
        : 0;
    final u = await svc.getUser(id);
    if (!mounted) return;
    setState(() {
      _liveFollowerCount = fc;
      _liveFollowingCount = u?.following.length ?? 0;
      _livePostCount = pc;
      _liveSubscriberCount = sc;
    });
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

  bool _canViewTheirHighlights(UserProfilePayload p) {
    final uid = (p.targetUserId ?? '').trim();
    if (uid.isEmpty) return false;
    final me = AuthService().currentUser?.uid;
    if (me == null || me.isEmpty) return false;
    if (me == uid) return true;
    if (_locksContentForViewer(p) && !_isFollowing) return false;
    return true;
  }

  Stream<List<StoryHighlightModel>> _otherUserHighlightsStream(String uid) {
    if (_otherHighlightsStreamUid != uid || _otherHighlightsStream == null) {
      _otherHighlightsStreamUid = uid;
      _otherHighlightsStream = StoryService().watchHighlightsForUser(uid);
    }
    return _otherHighlightsStream!;
  }

  Widget _buildOtherUserHighlightsBar(
    BuildContext context,
    UserProfilePayload p,
  ) {
    if (!_canViewTheirHighlights(p)) return const SizedBox.shrink();
    final uid = (p.targetUserId ?? '').trim();
    return Material(
      color: _profileSurface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          10,
          AppSpacing.md,
          10,
        ),
        child: StreamBuilder<List<StoryHighlightModel>>(
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
            if (highlights.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Highlights',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: highlights.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final h = highlights[i];
                      return ProfileHighlightAlbumTile(
                        title: h.title,
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
              ],
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
    final ref = (p.targetUserId ?? p.username).trim();
    if (ref.isEmpty) return;
    final link = DeepLinkConfig.profileWebUri(ref).toString();
    final message = 'Check out @${p.username} on Vyooo:\n$link';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open chat')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payload;
    final isVerified = _liveIsVerified ?? p.isVerified;
    final badgeColor = verificationBadgeColor(
      isVerified: isVerified,
      accountType: _liveAccountType ?? p.accountType,
      vipVerified: _liveVipVerified ?? p.vipVerified,
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOtherUserHighlightsBar(context, p),
          AppBottomNavigation(
            currentIndex: -1,
            onTap: (index) {
              MainNavWrapper.tabNotifier.value = index;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_profileBgTop, _profileBgMid, _profileBgBottom],
                  stops: [0.0, 0.58, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.8, -0.2),
                    radius: 1.0,
                    colors: [
                      _profileBgGlow.withValues(alpha: 0.4),
                      _profileBgGlow.withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(
                  '@${p.username}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    onPressed: () => _showProfileMenu(context),
                    icon: const Icon(
                      Icons.menu_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildAvatar(p.avatarUrl),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            p.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: badgeColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _UserStatChip(
                              label: 'Posts',
                              value: _formatCount(_livePostCount ?? p.postCount),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _UserStatChip(
                              label: 'Followers',
                              value: _formatCount(
                                _liveFollowerCount ?? p.followerCount,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _UserStatChip(
                              label: 'Following',
                              value: _formatCount(
                                _liveFollowingCount ?? p.followingCount,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _UserStatChip(
                              label: 'Subscriptions',
                              value: _formatCount(_liveSubscriberCount ?? 0),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (p.bio.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            p.bio,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.35,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 24),
                      _buildActionButtons(p),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: true,
                child: Container(
                  decoration: const BoxDecoration(
                    color: _profileSurface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: _buildTabs(),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: CustomScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          slivers: _buildContentSlivers(p),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String avatarUrl) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE81E57), width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: CircleAvatar(
          radius: 56,
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          backgroundImage: _isValidNetworkUrl(avatarUrl)
              ? NetworkImage(avatarUrl)
              : null,
          child: !_isValidNetworkUrl(avatarUrl)
              ? Icon(
                  Icons.person_rounded,
                  size: 56,
                  color: Colors.white.withValues(alpha: 0.4),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildActionButtons(UserProfilePayload p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: _PinkButton(
              label: _followActionBusy
                  ? '…'
                  : (_isFollowing
                      ? 'Following'
                      : (_targetRequiresFollowRequest(p) && _pendingFollowRequest
                          ? 'Requested'
                          : 'Follow')),
              onPressed: _followActionBusy ? () {} : _onFollowTap,
            ),
          ),
          const SizedBox(width: 12),
          if (p.isCreator) ...[
            Expanded(
              child: _GradientButton(
                label: _isSubscribed ? 'Subscribed' : 'Subscribe',
                icon: FontAwesomeIcons.crown,
                onPressed: () {
                  if (!_isSubscribed) {
                    Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (_) => CreatorSubscriptionScreen(
                          name: p.displayName,
                          handle: '@${p.username}',
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
                  } else {
                    final creatorId = (p.targetUserId ?? '').trim();
                    if (creatorId.isEmpty) {
                      setState(() => _isSubscribed = false);
                      return;
                    }
                    _creatorSubscriptionService
                        .cancelSubscription(creatorId: creatorId)
                        .then((_) {
                      if (!mounted) return;
                      setState(() => _isSubscribed = false);
                    }).catchError((_) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to cancel subscription.'),
                        ),
                      );
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
          ],
          if (widget.payload.targetUserId != null &&
              widget.payload.targetUserId!.isNotEmpty &&
              widget.payload.targetUserId != AuthService().currentUser?.uid) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openChat,
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE81E57),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _shareProfile,
              borderRadius: BorderRadius.circular(50),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFE81E57),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.share_outlined,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
    final target = widget.payload.targetUserId;
    final me = AuthService().currentUser?.uid;
    final canBlock = target != null && target.isNotEmpty && target != me;
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
              if (canBlock)
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
                      username: widget.payload.displayName,
                      avatarUrl: widget.payload.avatarUrl,
                      targetUserId: target,
                    );
                  },
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF2B1C2D),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              children: List.generate(_tabs.length, (index) {
                final isSelected = index == _selectedTabIndex;
                return Expanded(
                  child: Row(
                    children: [
                      if (index > 0 &&
                          !isSelected &&
                          index - 1 != _selectedTabIndex)
                        Container(
                          width: 1,
                          height: 16,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () =>
                                setState(() => _selectedTabIndex = index),
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFF1E5E)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.card,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _tabs[index],
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.6),
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _selectedTabIndex = _savedTabIndex),
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2B1C2D),
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Icon(
                _selectedTabIndex == _savedTabIndex
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: _selectedTabIndex == _savedTabIndex
                    ? const Color(0xFFFF1E5E)
                    : Colors.white.withValues(alpha: 0.8),
                size: 20,
              ),
            ),
          ),
        ),
      ],
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
        return _buildStreamsListSlivers(p);
      default:
        return [
          SliverFillRemaining(hasScrollBody: false, child: _buildEmptyTab()),
        ];
    }
  }

  List<Widget> _buildPostsSlivers(UserProfilePayload p) {
    final targetUid = (p.targetUserId ?? '').trim();
    if (targetUid.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
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
      ];
    }
    if (_locksContentForViewer(p) && !_isFollowing) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildPrivateProfilePlaceholder(),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('reels')
              .where('userId', isEqualTo: targetUid)
              .get()
              .then((q) {
                final docs = q.docs.map((d) {
                  final data = d.data();
                  return {
                    'id': d.id,
                    'videoUrl': data['videoUrl'] as String? ?? '',
                    'imageUrl': data['imageUrl'] as String? ?? '',
                    'thumbnailUrl': data['thumbnailUrl'] as String? ?? '',
                    'mediaType': data['mediaType'] as String? ?? '',
                    'caption': data['caption'] as String? ?? '',
                    'likes': (data['likes'] as num?)?.toInt() ?? 0,
                    'comments': (data['comments'] as num?)?.toInt() ?? 0,
                    'shares': (data['shares'] as num?)?.toInt() ?? 0,
                    'saves': (data['saves'] as num?)?.toInt() ?? 0,
                    'views': (data['views'] as num?)?.toInt() ?? 0,
                    'createdAt': data['createdAt'],
                  };
                }).toList();
                docs.sort((a, b) {
                  final aTs = a['createdAt'] as Timestamp?;
                  final bTs = b['createdAt'] as Timestamp?;
                  if (aTs == null && bTs == null) return 0;
                  if (aTs == null) return 1;
                  if (bTs == null) return -1;
                  return bTs.compareTo(aTs);
                });
                return docs;
              }),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white54),
                ),
              );
            }
            final posts = snapshot.data ?? <Map<String, dynamic>>[];
            if (posts.isEmpty) {
              return SizedBox(
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
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 1,
                ),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final reel = posts[index];
                  final thumb = _thumbnailFromReel(reel);
                  final mediaType = ((reel['mediaType'] as String?) ?? '')
                      .toLowerCase();
                  final isVideo = mediaType != 'image';
                  final username = (reel['username'] as String? ?? '').trim();
                  final avatarUrl = (reel['avatarUrl'] as String? ?? '').trim();
                  final creatorName = username.isNotEmpty
                      ? username
                      : widget.payload.displayName;
                  final handle = username.isNotEmpty
                      ? '@${username.replaceAll('@', '')}'
                      : '@${widget.payload.username.replaceAll('@', '')}';
                  final isVerified = reel['isVerified'] == true ||
                      _liveIsVerified == true ||
                      widget.payload.isVerified;
                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PostFeedScreen(
                          payload: PostFeedPayload(
                            posts: posts,
                            initialIndex: index,
                            creatorName: creatorName,
                            creatorHandle: handle,
                            avatarUrl: avatarUrl.isNotEmpty
                                ? avatarUrl
                                : widget.payload.avatarUrl,
                            isVerified: isVerified,
                          ),
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: Colors.grey[900]),
                          if (thumb.isNotEmpty)
                            Image.network(
                              thumb,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox.shrink(),
                            ),
                          if (isVideo)
                            const Align(
                              alignment: Alignment.bottomRight,
                              child: Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ];
  }

  static String _thumbnailFromReel(Map<String, dynamic> reel) {
    final mediaType = ((reel['mediaType'] as String?) ?? '').toLowerCase();
    final imageUrl = (reel['imageUrl'] as String?)?.trim() ?? '';
    final explicitThumb = (reel['thumbnailUrl'] as String?)?.trim() ?? '';
    final videoUrl = (reel['videoUrl'] as String?)?.trim() ?? '';
    if (mediaType == 'image') {
      if (imageUrl.isNotEmpty) return imageUrl;
      if (explicitThumb.isNotEmpty) return explicitThumb;
      return '';
    }
    if (explicitThumb.isNotEmpty) return explicitThumb;
    if (imageUrl.isNotEmpty) return imageUrl;
    if (videoUrl.isEmpty) return '';
    try {
      final uri = Uri.parse(videoUrl);
      final videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      if (videoId.isEmpty) return '';
      return 'https://videodelivery.net/$videoId/thumbnails/thumbnail.jpg';
    } catch (_) {
      return '';
    }
  }

  List<Widget> _buildVRGridSlivers(UserProfilePayload p) {
    final targetUid = (p.targetUserId ?? '').trim();
    if (_locksContentForViewer(p) && !_isFollowing) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildPrivateProfilePlaceholder(),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: ReelsService().getReelsVR(limit: 120),
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
                .toList(growable: false);
            if (reels.isEmpty) {
              return _buildEmptyTab();
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.65,
              ),
              itemCount: reels.length,
              itemBuilder: (context, index) {
                final item = reels[index];
                final creatorName = (item['username']?.toString() ?? '').trim();
                final creatorHandle = (item['handle']?.toString() ?? '').trim();
                final avatar = (item['avatarUrl']?.toString() ?? '').trim();
                final thumb = _thumbnailFromReel(item);
                return _UserProfileVRCard(
                  item: _UserProfileVRItem(
                    thumbnailUrl: thumb,
                    creatorName: creatorName.isNotEmpty
                        ? creatorName
                        : 'Creator',
                    creatorHandle: creatorHandle.isNotEmpty
                        ? creatorHandle
                        : '@creator',
                    avatarUrl: avatar,
                    viewCount: (item['views'] as num?)?.toInt() ?? 0,
                    isVerified: false,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => VRDetailScreen(
                        payload: VRDetailPayload(
                          creatorName: creatorName.isNotEmpty
                              ? creatorName
                              : 'Creator',
                          creatorHandle: creatorHandle.isNotEmpty
                              ? creatorHandle
                              : '@creator',
                          avatarUrl: avatar,
                          thumbnailUrl: thumb,
                          likeCount: (item['likes'] as num?)?.toInt() ?? 0,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _buildStreamsListSlivers(UserProfilePayload p) {
    final targetUid = (p.targetUserId ?? '').trim();
    if (_locksContentForViewer(p) && !_isFollowing) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildPrivateProfilePlaceholder(),
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
            final streams = snapshot.data ?? const <LiveStreamModel>[];
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
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildEmptyTab(),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchSavedReels(targetUid),
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
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 1,
                ),
                itemCount: savedReels.length,
                itemBuilder: (context, index) {
                  final reel = savedReels[index];
                  final thumb = _thumbnailFromReel(reel);
                  final mediaType = ((reel['mediaType'] as String?) ?? '')
                      .toLowerCase();
                  final isVideo = mediaType != 'image';
                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PostFeedScreen(
                          payload: PostFeedPayload(
                            posts: savedReels,
                            initialIndex: index,
                            creatorName: (reel['username'] as String? ?? '')
                                    .trim()
                                    .isNotEmpty
                                ? (reel['username'] as String).trim()
                                : widget.payload.displayName,
                            creatorHandle:
                                '@${((reel['username'] as String?) ?? widget.payload.username).replaceAll('@', '')}',
                            avatarUrl:
                                (reel['avatarUrl'] as String? ?? '').trim(),
                            isVerified: reel['isVerified'] == true,
                          ),
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: Colors.grey[900]),
                          if (thumb.isNotEmpty)
                            Image.network(
                              thumb,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                          if (isVideo)
                            const Align(
                              alignment: Alignment.bottomRight,
                              child: Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ];
  }

  Future<List<Map<String, dynamic>>> _fetchSavedReels(String uid) async {
    try {
      final savesSnap = await FirebaseFirestore.instance
          .collection('userSaves')
          .where('userId', isEqualTo: uid)
          .get();
      if (savesSnap.docs.isEmpty) return <Map<String, dynamic>>[];

      final saveMeta = <String, int>{};
      final reelIds = <String>[];
      for (final d in savesSnap.docs) {
        final data = d.data();
        final reelId = (data['reelId'] as String?)?.trim() ?? '';
        if (reelId.isEmpty) continue;
        final ts = data['savedAt'];
        final epoch = ts is Timestamp ? ts.millisecondsSinceEpoch : 0;
        saveMeta[reelId] = epoch;
        reelIds.add(reelId);
      }
      if (reelIds.isEmpty) return <Map<String, dynamic>>[];

      final reelsById = <String, Map<String, dynamic>>{};
      for (var i = 0; i < reelIds.length; i += 10) {
        final chunk = reelIds.sublist(
          i,
          (i + 10) > reelIds.length ? reelIds.length : (i + 10),
        );
        final q = await FirebaseFirestore.instance
            .collection('reels')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in q.docs) {
          final data = doc.data();
          reelsById[doc.id] = {
            'id': doc.id,
            'videoUrl': data['videoUrl'] as String? ?? '',
            'caption': data['caption'] as String? ?? '',
            'thumbnailUrl': data['thumbnailUrl'] as String? ?? '',
            'imageUrl': data['imageUrl'] as String? ?? '',
            'mediaType': data['mediaType'] as String? ?? '',
            'username': data['username'] as String? ?? '',
            'avatarUrl': data['profileImage'] as String? ??
                data['avatarUrl'] as String? ??
                '',
            'isVerified': data['isVerified'] == true,
            'createdAt': data['createdAt'],
          };
        }
      }

      final out = <Map<String, dynamic>>[];
      for (final id in reelIds) {
        final reel = reelsById[id];
        if (reel != null) out.add(reel);
      }
      out.sort((a, b) {
        final aTs = saveMeta[a['id']] ?? 0;
        final bTs = saveMeta[b['id']] ?? 0;
        return bTs.compareTo(aTs);
      });
      return out;
    } catch (e) {
      dev.log('Failed to fetch user profile saved reels', error: e);
      return <Map<String, dynamic>>[];
    }
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

class _UserProfileVRItem {
  const _UserProfileVRItem({
    required this.thumbnailUrl,
    required this.creatorName,
    required this.creatorHandle,
    required this.avatarUrl,
    this.viewCount = 102,
    this.isVerified = false,
  });
  final String thumbnailUrl;
  final String creatorName;
  final String creatorHandle;
  final String avatarUrl;
  final int viewCount;
  final bool isVerified;
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

class _UserStatChip extends StatelessWidget {
  const _UserStatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF4A1538),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinkButton extends StatelessWidget {
  const _PinkButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isFollowing = label == 'Following';
    return Container(
      decoration: BoxDecoration(
        color: isFollowing
            ? Colors.white.withValues(alpha: 0.1)
            : const Color(0xFFE81E57),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
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

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final Object icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: label == 'Subscribed'
            ? null
            : const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFFE8C547),
                  Color(0xFFD4A84B),
                  Color(0xFFB8862E),
                ],
              ),
        color: label == 'Subscribed' ? const Color(0xFFD4A84B) : null,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon is FaIconData
                    ? FaIcon(icon as FaIconData, size: 14, color: Colors.black)
                    : Icon(icon as IconData, size: 14, color: Colors.black),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserProfileVRCard extends StatelessWidget {
  const _UserProfileVRCard({required this.item, this.onTap});

  final _UserProfileVRItem item;
  final VoidCallback? onTap;

  static String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final avatarUri = Uri.tryParse(item.avatarUrl.trim());
    final hasValidAvatar = avatarUri != null &&
        avatarUri.isAbsolute &&
        avatarUri.host.isNotEmpty &&
        (avatarUri.scheme == 'http' || avatarUri.scheme == 'https');
    final avatarProvider = hasValidAvatar ? NetworkImage(item.avatarUrl.trim()) : null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(item.thumbnailUrl, fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.35, 1.0],
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'VR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
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
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.grey.shade700,
                    backgroundImage: avatarProvider,
                    child: avatarProvider == null
                        ? const Icon(
                            Icons.person_rounded,
                            size: 14,
                            color: Colors.white70,
                          )
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.creatorName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            if (item.isVerified) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: AppColors.deleteRed,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          item.creatorHandle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
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
  final Map<String, bool> _savedReels = {};

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
    final reelIds = widget.reels
        .map((r) => (r['id'] as String? ?? '').trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (reelIds.isEmpty) return;
    final likedIds = await _reelsController.getLikedReelIds(reelIds);
    final savedIds = await _reelsController.getSavedReelIds(reelIds);
    if (!mounted) return;
    setState(() {
      for (final id in reelIds) {
        _likedReels[id] = likedIds.contains(id);
        _savedReels[id] = savedIds.contains(id);
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

  void _adjustReelStat(String reelId, String key, int delta) {
    final i = widget.reels.indexWhere((r) => _asString(r['id']) == reelId);
    if (i < 0) return;
    final current = _asInt(widget.reels[i][key]);
    setState(() {
      widget.reels[i][key] = (current + delta).clamp(0, 1 << 30);
    });
  }

  Future<void> _onLike(String reelId, bool currentlyLiked) async {
    final newState = await _reelsController.likeReel(
      reelId: reelId,
      currentlyLiked: currentlyLiked,
    );
    if (!mounted || newState == null) return;
    setState(() => _likedReels[reelId] = newState);
    _adjustReelStat(reelId, 'likes', newState ? 1 : -1);
  }

  Future<void> _onSave(String reelId, bool currentlySaved) async {
    final newState = await _reelsController.saveReel(
      reelId: reelId,
      currentlySaved: currentlySaved,
    );
    if (!mounted || newState == null) return;
    setState(() => _savedReels[reelId] = newState);
    _adjustReelStat(reelId, 'saves', newState ? 1 : -1);
  }

  void _onShare(String reelId, Map<String, dynamic> reel) {
    showShareBottomSheet(
      context,
      reelId: reelId,
      thumbnailUrl: _UserProfileScreenState._thumbnailFromReel(reel),
      authorName: _asString(reel['username']).isEmpty
          ? widget.reels[_currentIndex]['username']?.toString()
          : _asString(reel['username']),
      onShareViaNative: () => _reelsController.shareReel(reelId: reelId),
      onCopyLink: () {},
    );
  }

  void _onComment(String reelId) {
    showCommentsBottomSheet(
      context,
      reelId: reelId,
      onCommentCountChanged: (delta) => _adjustReelStat(reelId, 'comments', delta),
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
      onReport: () => showReportSheet(
        context,
        username: _asString(reel['username']).isEmpty
            ? 'User'
            : _asString(reel['username']),
        avatarUrl: _asString(reel['avatarUrl']),
        targetUserId: authorId.isEmpty ? null : authorId,
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
    final isLiked = _likedReels[reelId] ?? false;
    final isSaved = _savedReels[reelId] ?? false;

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
            count: _formatCount(_asInt(reel['views'])),
            iconSize: 24,
            textSize: 10,
            spacing: 3,
          ),
          const SizedBox(height: 12),
          AppInteractionButton(
            icon: isLiked ? Icons.favorite : Icons.favorite_border,
            count: _formatCount(_asInt(reel['likes'])),
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
            count: _formatCount(_asInt(reel['comments'])),
            onTap: () => _onComment(reelId),
            iconSize: 24,
            textSize: 10,
            spacing: 3,
          ),
          const SizedBox(height: 12),
          AppInteractionButton(
            icon: isSaved ? Icons.star : Icons.star_border,
            count: _formatCount(_asInt(reel['saves'])),
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
            count: _formatCount(_asInt(reel['shares'])),
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
