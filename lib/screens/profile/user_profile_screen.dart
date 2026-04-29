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
import '../../core/services/auth_service.dart';
import '../../core/services/live_stream_service.dart';
import '../../core/services/reels_service.dart';
import '../../core/services/user_service.dart';
import '../../core/utils/verification_badge.dart';
import '../../core/utils/user_facing_errors.dart';
import '../content/live_stream_route.dart';
import '../content/vr_detail_screen.dart';
import '../../widgets/reel_item_widget.dart';
import '../../features/reel/widgets/block_user_sheet.dart';
import '../../features/subscription/creator_subscription_screen.dart';

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
  int? _liveFollowerCount;
  int? _liveFollowingCount;
  int? _livePostCount;
  bool? _liveIsVerified;
  String? _liveAccountType;
  bool? _liveVipVerified;
  StreamSubscription<int>? _followerCountSub;
  StreamSubscription<int>? _postCountSub;
  StreamSubscription<AppUserModel?>? _targetUserSub;
  final LiveStreamService _liveStreamService = LiveStreamService();

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
      _liveIsVerified = null;
      _liveAccountType = null;
      _liveVipVerified = null;
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
    if (target == null ||
        target.isEmpty ||
        me == null ||
        me.isEmpty ||
        me == target) {
      return;
    }
    final v = await UserService().isFollowingUser(
      currentUid: me,
      targetUid: target,
    );
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF14001F), Color(0xFF1A0022), Color(0xFF2A002E)],
          ),
        ),
        child: CustomScrollView(
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
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _UserStatChip(
                          label: 'Posts',
                          value: _formatCount(_livePostCount ?? p.postCount),
                        ),
                        const SizedBox(width: 12),
                        _UserStatChip(
                          label: 'Followers',
                          value: _formatCount(
                            _liveFollowerCount ?? p.followerCount,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _UserStatChip(
                          label: 'Following',
                          value: _formatCount(
                            _liveFollowingCount ?? p.followingCount,
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
                            fontWeight: FontWeight.w400,
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
                  color: Color(0xFF120015),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
      ),
    );
  }

  Widget _buildAvatar(String avatarUrl) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDE106B), Color(0xFFF81945)],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: Color(0xFF14001F),
          shape: BoxShape.circle,
        ),
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
                  : (_isFollowing ? 'Following' : 'Follow'),
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
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CreatorSubscriptionScreen(
                          name: p.displayName,
                          handle: '@${p.username}',
                          avatarUrl: p.avatarUrl,
                          creatorUserId: p.targetUserId,
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
            const SizedBox(width: 12),
          ],
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: IconButton(
              onPressed: _shareProfile,
              icon: const Icon(
                Icons.share_outlined,
                color: Colors.white,
                size: 20,
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          ...List.generate(_tabs.length, (index) {
            final isSelected = index == _selectedTabIndex;
            return Expanded(
              child: InkWell(
                onTap: () => setState(() => _selectedTabIndex = index),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xFFDE106B), Color(0xFFF81945)],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
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
            );
          }),
          Container(
            height: 20,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: Colors.white.withValues(alpha: 0.1),
          ),
          InkWell(
            onTap: () => setState(() => _selectedTabIndex = _savedTabIndex),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                _selectedTabIndex == _savedTabIndex
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: _selectedTabIndex == _savedTabIndex
                    ? const Color(0xFFF81945)
                    : Colors.white.withValues(alpha: 0.8),
                size: 20,
              ),
            ),
          ),
        ],
      ),
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
                  final mediaType =
                      ((reel['mediaType'] as String?) ?? '').toLowerCase();
                  final isVideo = mediaType != 'image';
                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _UserProfileReelFeedScreen(
                          reels: posts,
                          initialIndex: index,
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
    return [
      SliverToBoxAdapter(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: ReelsService().getReelsVR(limit: 120),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: Colors.white54)),
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
                    creatorName: creatorName.isNotEmpty ? creatorName : 'Creator',
                    creatorHandle: creatorHandle.isNotEmpty ? creatorHandle : '@creator',
                    avatarUrl: avatar,
                    viewCount: (item['views'] as num?)?.toInt() ?? 0,
                    isVerified: false,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => VRDetailScreen(
                        payload: VRDetailPayload(
                          creatorName: creatorName.isNotEmpty ? creatorName : 'Creator',
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
    return [
      SliverToBoxAdapter(
        child: StreamBuilder<List<LiveStreamModel>>(
          stream: _liveStreamService.savedStreams(targetUid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: Colors.white54)),
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
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
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
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
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
              child: Image.network(
                _userProfileMockSavedUrls[index],
                fit: BoxFit.cover,
              ),
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
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 16,
        ),
      ),
    );
  }
}

// Mock data for other user profile (design only).
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
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
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
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
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
        gradient: isFollowing
            ? null
            : const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFFDE106B), Color(0xFFF81945)],
              ),
        color: isFollowing ? Colors.white.withValues(alpha: 0.1) : null,
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

class _UserProfileReelFeedScreenState extends State<_UserProfileReelFeedScreen> {
  late final PageController _pageController;
  late int _currentIndex;

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
              final mediaType =
                  ((reel['mediaType'] as String?) ?? '').toLowerCase();
              if (mediaType == 'image') {
                final imageUrl = ((reel['imageUrl'] as String?) ?? '').trim();
                final thumbnailUrl =
                    ((reel['thumbnailUrl'] as String?) ?? '').trim();
                final displayUrl = imageUrl.isNotEmpty ? imageUrl : thumbnailUrl;
                if (displayUrl.isNotEmpty) {
                  return SizedBox.expand(
                    child: ColoredBox(
                      color: Colors.black,
                      child: Image.network(
                        displayUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
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
              return ReelItemWidget(
                videoUrl: videoUrl,
                isVisible: index == _currentIndex,
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
}
