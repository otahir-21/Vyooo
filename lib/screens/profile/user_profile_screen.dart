import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:async';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_gradient_background.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/app_user_model.dart';
import '../../core/models/live_stream_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/utils/user_facing_errors.dart';
import '../content/live_stream_route.dart';
import '../content/post_feed_screen.dart';
import '../content/vr_detail_screen.dart';
import '../../features/subscription/creator_subscription_screen.dart';
import 'followers_following_screen.dart';

/// Data for displaying another user's profile (e.g. from search or followers list).
class UserProfilePayload {
  const UserProfilePayload({
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    this.isVerified = false,
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
  int? _liveFollowerCount;
  int? _liveFollowingCount;
  int? _livePostCount;
  StreamSubscription<int>? _followerCountSub;
  StreamSubscription<int>? _postCountSub;
  StreamSubscription<AppUserModel?>? _targetUserSub;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.payload.isFollowing;
    _isSubscribed = widget.payload.isSubscribed;
    _refreshFollowFromFirestore();
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
      _refreshFollowFromFirestore();
      _loadPublicCounts();
      _bindLiveCountStreams();
    }
  }

  @override
  void dispose() {
    _followerCountSub?.cancel();
    _postCountSub?.cancel();
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
    _targetUserSub = svc.userStream(id).listen((u) {
      if (!mounted) return;
      setState(() => _liveFollowingCount = u?.following.length ?? 0);
    });
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
    });
  }

  Future<void> _refreshFollowFromFirestore() async {
    final target = widget.payload.targetUserId;
    final me = AuthService().currentUser?.uid;
    if (target == null || target.isEmpty || me == null || me.isEmpty || me == target) {
      return;
    }
    final v = await UserService().isFollowingUser(currentUid: me, targetUid: target);
    if (mounted) setState(() => _isFollowing = v);
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
        if (mounted) setState(() => _isFollowing = false);
      } else {
        await svc.followUser(currentUid: me, targetUid: target);
        if (mounted) setState(() => _isFollowing = true);
      }
      if (mounted) await _loadPublicCounts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageForFirestore(e))),
        );
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

  @override
  Widget build(BuildContext context) {
    final p = widget.payload;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.profile,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
              ),
              title: Text(
                '@${p.username}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              centerTitle: false,
              actions: [
                IconButton(
                  onPressed: () => _showProfileMenu(context),
                  icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    _buildAvatar(p.avatarUrl),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          p.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (p.isVerified) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.check_circle_rounded, size: 20, color: AppColors.deleteRed),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _UserStatChip(label: 'Posts', value: _formatCount(_livePostCount ?? p.postCount)),
                        const SizedBox(width: AppSpacing.sm),
                        _UserStatChip(
                          label: 'Following',
                          value: _formatCount(_liveFollowingCount ?? p.followingCount),
                          onTap: () {
                            final id = p.targetUserId;
                            if (id == null || id.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Connect this profile to an account to view lists.')),
                              );
                              return;
                            }
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => FollowersFollowingScreen(
                                  initialTab: 1,
                                  profileUserId: id,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _UserStatChip(
                          label: 'Followers',
                          value: _formatCount(_liveFollowerCount ?? p.followerCount),
                          onTap: () {
                            final id = p.targetUserId;
                            if (id == null || id.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Connect this profile to an account to view lists.')),
                              );
                              return;
                            }
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => FollowersFollowingScreen(
                                  initialTab: 0,
                                  profileUserId: id,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    if (p.bio.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        p.bio,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _buildActionButtons(p),
                    const SizedBox(height: AppSpacing.xl),
                    _buildTabs(),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
            ..._buildContentSlivers(p),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String avatarUrl) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFDE106B), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDE106B).withValues(alpha: 0.35),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 52,
        backgroundColor: Colors.white.withValues(alpha: 0.2),
        backgroundImage: Uri.tryParse(avatarUrl)?.isAbsolute == true
            ? NetworkImage(avatarUrl)
            : null,
        child: Uri.tryParse(avatarUrl)?.isAbsolute != true
            ? Icon(Icons.person_rounded, size: 52, color: Colors.white.withValues(alpha: 0.6))
            : null,
      ),
    );
  }

  Widget _buildActionButtons(UserProfilePayload p) {
    return Row(
      children: [
        Expanded(
          child: _PinkButton(
            label: _followActionBusy
                ? '…'
                : (_isFollowing ? 'Following' : 'Follow'),
            onPressed: _followActionBusy ? () {} : _onFollowTap,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        if (p.isCreator) ...[
          Expanded(
            child: _GradientButton(
              label: _isSubscribed ? 'Subscribed' : 'Subscribe',
              icon: FontAwesomeIcons.crown,
              onPressed: () {
                if (!_isSubscribed) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CreatorSubscriptionScreen(
                        name: p.displayName,
                        handle: '@${p.username}',
                        avatarUrl: p.avatarUrl,
                        isVerified: p.isVerified,
                      ),
                    ),
                  );
                } else {
                  setState(() => _isSubscribed = false);
                }
              },
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Material(
          color: p.isCreator
              ? Colors.white.withValues(alpha: 0.15)
              : const Color(0xFF1a2e1a),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: IconButton(
            onPressed: () {},
            icon: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }

  void _showProfileMenu(BuildContext context) {
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
              ListTile(
                leading: Icon(Icons.notifications_outlined, color: Colors.white.withValues(alpha: 0.9)),
                title: Text(
                  'Notifications',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 16),
                ),
                trailing: Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.6)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showNotificationsSheet(context);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Notifications',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _NotificationOption(title: 'All', selected: true, onTap: () {}),
              _NotificationOption(title: 'None', selected: false, onTap: () {}),
              _NotificationOption(title: 'Unsubscribe', selected: false, onTap: () {}),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        ...List.generate(_tabs.length, (index) {
          final isSelected = index == _selectedTabIndex;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index < _tabs.length - 1 ? AppSpacing.xs : 0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _selectedTabIndex = index),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [Color(0xFFDE106B), Color(0xFFF81945)],
                            )
                          : null,
                      color: isSelected ? null : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Center(
                      child: Text(
                        _tabs[index],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(width: AppSpacing.sm),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _selectedTabIndex = _savedTabIndex),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                _selectedTabIndex == _savedTabIndex ? Icons.star_rounded : Icons.star_outline_rounded,
                color: _selectedTabIndex == _savedTabIndex
                    ? const Color(0xFFF81945)
                    : Colors.white.withValues(alpha: 0.8),
                size: 22,
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
        return [SliverFillRemaining(hasScrollBody: false, child: _buildEmptyTab())];
    }
  }

  List<Widget> _buildPostsSlivers(UserProfilePayload p) {
    if (p.postCount == 0) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline_rounded, size: 48, color: Colors.white.withValues(alpha: 0.5)),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No posts made yet',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PostFeedScreen(
                    payload: PostFeedPayload(
                      initialIndex: index,
                      creatorName: p.displayName,
                      creatorHandle: '@${p.username}',
                      avatarUrl: p.avatarUrl,
                      isVerified: p.isVerified,
                    ),
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(_userProfileMockPostUrls[index], fit: BoxFit.cover),
              ),
            ),
            childCount: _userProfileMockPostUrls.length,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildVRGridSlivers(UserProfilePayload p) {
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.65,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = _userProfileMockVRItems[index];
              return _UserProfileVRCard(
                item: item,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => VRDetailScreen(
                      payload: VRDetailPayload(
                        creatorName: item.creatorName,
                        creatorHandle: item.creatorHandle,
                        avatarUrl: item.avatarUrl,
                        thumbnailUrl: item.thumbnailUrl,
                        likeCount: item.viewCount * 1000,
                      ),
                    ),
                  ),
                ),
              );
            },
            childCount: _userProfileMockVRItems.length,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildStreamsListSlivers(UserProfilePayload p) {
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index.isOdd) return const SizedBox(height: AppSpacing.md);
              final itemIndex = index ~/ 2;
              final item = _userProfileMockStreamItems[itemIndex];
              return SizedBox(
                height: 200,
                child: _UserProfileStreamCard(
                  item: item,
                  onTap: () => openLiveStreamScreen(
                    context,
                    LiveStreamModel(
                      id: item.title,
                      hostId: '',
                      hostUsername: 'Host',
                      title: item.title,
                      description: item.subtitle,
                      status: LiveStreamStatus.live,
                      likeCount: item.viewCount,
                      agoraChannelName: item.title,
                      createdAt: Timestamp.now(),
                    ),
                  ),
                ),
              );
            },
            childCount: _userProfileMockStreamItems.length * 2 - 1,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildSavedGridSlivers() {
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(_userProfileMockSavedUrls[index], fit: BoxFit.cover),
            ),
            childCount: _userProfileMockSavedUrls.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildEmptyTab() {
    return Center(
      child: Text(
        'No content yet',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
      ),
    );
  }
}

// Mock data for other user profile (design only).
const List<String> _userProfileMockPostUrls = [
  'https://picsum.photos/400/400?random=u1',
  'https://picsum.photos/400/400?random=u2',
  'https://picsum.photos/400/400?random=u3',
  'https://picsum.photos/400/400?random=u4',
  'https://picsum.photos/400/400?random=u5',
  'https://picsum.photos/400/400?random=u6',
  'https://picsum.photos/400/400?random=u7',
  'https://picsum.photos/400/400?random=u8',
  'https://picsum.photos/400/400?random=u9',
];

const List<String> _userProfileMockSavedUrls = [
  'https://picsum.photos/400/400?random=us1',
  'https://picsum.photos/400/400?random=us2',
  'https://picsum.photos/400/400?random=us3',
  'https://picsum.photos/400/400?random=us4',
  'https://picsum.photos/400/400?random=us5',
  'https://picsum.photos/400/400?random=us6',
];

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

final List<_UserProfileVRItem> _userProfileMockVRItems = [
  _UserProfileVRItem(
    thumbnailUrl: 'https://picsum.photos/400/600?random=uvr1',
    creatorName: 'Sofia Vergara',
    creatorHandle: '@Soffv33',
    avatarUrl: 'https://i.pravatar.cc/80?img=32',
    viewCount: 100,
  ),
  _UserProfileVRItem(
    thumbnailUrl: 'https://picsum.photos/400/600?random=uvr2',
    creatorName: 'Selena Gomet',
    creatorHandle: '@GometnoComet',
    avatarUrl: 'https://i.pravatar.cc/80?img=28',
    viewCount: 102,
    isVerified: true,
  ),
];

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

final List<_UserProfileStreamItem> _userProfileMockStreamItems = [
  _UserProfileStreamItem(
    thumbnailUrl: 'https://picsum.photos/400/240?random=ulive1',
    title: 'Live Show @standupcomedy roasting our very...',
    subtitle: 'Streaming now',
    isLive: true,
    viewCount: 22500,
  ),
  _UserProfileStreamItem(
    thumbnailUrl: 'https://picsum.photos/400/240?random=ulive2',
    title: 'Q&A and behind the scenes',
    subtitle: 'Streamed 2 months ago',
    isLive: false,
    viewCount: 22500,
  ),
];

class _UserStatChip extends StatelessWidget {
  const _UserStatChip({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
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

class _NotificationOption extends StatelessWidget {
  const _NotificationOption({required this.title, required this.selected, required this.onTap});

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off_rounded,
                color: selected ? const Color(0xFFF81945) : Colors.white.withValues(alpha: 0.6),
                size: 24,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 16,
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
    return Material(
      color: label == 'Following'
          ? Colors.white.withValues(alpha: 0.2)
          : AppColors.pink,
      borderRadius: BorderRadius.circular(AppRadius.pill),
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
  final IconData icon;
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
                colors: [Color(0xFFE8C547), Color(0xFFD4A84B), Color(0xFFB8862E)],
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
                Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.95)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
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
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('VR', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatCount(item.viewCount),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11),
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
                    backgroundImage: NetworkImage(item.avatarUrl),
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
                              Icon(Icons.check_circle_rounded, size: 14, color: AppColors.deleteRed),
                            ],
                          ],
                        ),
                        Text(
                          item.creatorHandle,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
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
    return GestureDetector(
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.deleteRed,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility_outlined, size: 12, color: Colors.white.withValues(alpha: 0.9)),
                  const SizedBox(width: 2),
                  Text(
                    _formatCount(item.viewCount),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11),
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
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
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
