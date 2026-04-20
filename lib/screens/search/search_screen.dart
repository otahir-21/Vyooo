import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/app_user_model.dart';
import '../../core/models/live_stream_model.dart';
import '../../core/services/live_stream_service.dart';
import '../../core/services/user_service.dart';
import '../../core/subscription/subscription_controller.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/vr/vr_screen.dart';
import '../../features/vr/vr_player_screen.dart';
import '../content/live_stream_route.dart';
import '../profile/user_profile_screen.dart';

/// Search tab: search bar, Live/VR/Camera tabs, Ongoing Now & Recommended sections.
/// Matches Figma: search field + # button, pink gradient active tab, live cards.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _selectedTabIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchActive = false;

  // ── Live streams from Firestore ───────────────────────────────────────────
  final _liveService = LiveStreamService();
  List<LiveStreamModel> _liveStreams = [];
  StreamSubscription<List<LiveStreamModel>>? _liveStreamsSub;
  Map<String, AppUserModel> _liveHostProfiles = const {};
  final UserService _userService = UserService();
  final List<_UserSearchItem> _allUsers = [];
  bool _usersLoading = false;
  String? _usersError;
  Set<String> _myFollowingIds = <String>{};
  bool _usersLoadAttempted = false;
  List<String> _recentSearches = const [
    'Live concerts happening',
    'Cricket match IND vs AUS',
    'Best VR experiences on the internet',
    'Dance videos',
    'Travel vlogs',
  ].toList();

  static const List<String> _tabs = ['Live', 'VR', 'Users'];

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onSearchFocusChange);
    _searchController.addListener(_onSearchTextChange);
    _liveStreamsSub = _liveService.liveStreams().listen((streams) {
      if (mounted) {
        setState(() => _liveStreams = streams);
      }
      _refreshLiveHostProfiles(streams);
    });
    // Keep Live as the default tab (matches new segmented control design).
    _selectedTabIndex = 0;
    _loadUsers();
  }

  Future<void> _refreshLiveHostProfiles(List<LiveStreamModel> streams) async {
    final hostIds = streams
        .map((s) => s.hostId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (hostIds.isEmpty) {
      if (!mounted) return;
      if (mounted) setState(() => _liveHostProfiles = const {});
      return;
    }
    try {
      final users = await _userService.getUsersByIds(hostIds);
      final map = <String, AppUserModel>{for (final u in users) u.uid: u};
      if (!mounted) return;
      setState(() => _liveHostProfiles = map);
    } catch (_) {
      // Keep current card design/content even if profile enrichment fails.
    }
  }

  Future<void> _loadUsers() async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null || me.isEmpty) return;
    _usersLoadAttempted = true;
    if (mounted) {
      setState(() {
        _usersLoading = true;
        _usersError = null;
      });
    }
    try {
      final items = await _userService.discoverUserItems(
        currentUid: me,
        limit: 120,
      );
      final users = items
          .map(
            (i) => _UserSearchItem(
              uid: i.uid,
              username: i.username,
              fullName: i.displayName,
              followerCount: i.followerCount,
              avatarUrl: i.avatarUrl,
              isVerified: false,
              isFollowing: i.isFollowing,
            ),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _allUsers
          ..clear()
          ..addAll(users);
        _myFollowingIds = users
            .where((u) => u.isFollowing)
            .map((u) => u.uid)
            .toSet();
        _usersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usersLoading = false;
        _usersError = e.toString();
      });
    }
  }

  void _ensureUsersLoaded() {
    if (_usersLoading || _allUsers.isNotEmpty) return;
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null || me.isEmpty) return;
    if (_usersLoadAttempted && _usersError != null) return;
    _loadUsers();
  }

  List<_UserSearchItem> get _filteredUsers {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _allUsers;
    return _allUsers
        .where(
          (u) =>
              u.username.toLowerCase().contains(q) ||
              u.fullName.toLowerCase().contains(q),
        )
        .toList();
  }

  List<_LiveCardItem> get _dynamicLiveItems =>
      _liveStreams.map(_toLiveCardItem).toList(growable: false);

  List<_LiveCardItem> get _dynamicRecommendedItems {
    final items = List<_LiveCardItem>.from(_dynamicLiveItems);
    items.sort((a, b) => b.viewerCount.compareTo(a.viewerCount));
    return items.take(6).toList(growable: false);
  }

  List<_LiveCardItem> get _dynamicExploreItems {
    final recommended = _dynamicRecommendedItems;
    final recommendedHandles = recommended.map((e) => e.handle).toSet();
    return _dynamicLiveItems
        .where((e) => !recommendedHandles.contains(e.handle))
        .take(6)
        .toList(growable: false);
  }

  List<_LiveSearchResultItem> get _dynamicLiveSearchResultItems {
    final q = _searchController.text.trim().toLowerCase();
    final streams = q.isEmpty
        ? _liveStreams
        : _liveStreams
              .where((s) {
                final inTags = s.tags.any((t) => t.toLowerCase().contains(q));
                return s.hostUsername.toLowerCase().contains(q) ||
                    s.title.toLowerCase().contains(q) ||
                    s.description.toLowerCase().contains(q) ||
                    s.category.toLowerCase().contains(q) ||
                    inTags;
              })
              .toList(growable: false);
    return streams
        .map((s) => _LiveSearchResultItem(stream: s, card: _toLiveCardItem(s)))
        .toList(growable: false);
  }

  List<_CategoryItem> get _dynamicCategoryItems {
    final unique = <String>{};
    final categories = <_CategoryItem>[];
    for (final stream in _liveStreams) {
      final category = stream.category.trim();
      if (category.isEmpty) continue;
      final key = category.toLowerCase();
      if (!unique.add(key)) continue;
      categories.add(
        _CategoryItem(label: category, icon: _categoryIconFor(category)),
      );
    }
    return categories.take(8).toList(growable: false);
  }

  List<_CreatorItem> get _dynamicCreatorItems {
    final byHost = <String, LiveStreamModel>{};
    for (final stream in _liveStreams) {
      final existing = byHost[stream.hostId];
      if (existing == null || stream.viewerCount > existing.viewerCount) {
        byHost[stream.hostId] = stream;
      }
    }
    final ranked = byHost.values.toList()
      ..sort((a, b) => b.viewerCount.compareTo(a.viewerCount));
    return ranked
        .take(8)
        .map((s) {
          final profile = _liveHostProfiles[s.hostId];
          final avatar = ((profile?.profileImage ?? '').trim().isNotEmpty)
              ? (profile!.profileImage!).trim()
              : (s.hostProfileImage?.isNotEmpty == true)
              ? s.hostProfileImage!
              : 'https://i.pravatar.cc/120?u=${s.hostId}';
          final followers = profile?.followersCount ?? s.viewerCount;
          final following = profile?.following.length ?? 0;
          return _CreatorItem(
            name: (profile?.username?.trim().isNotEmpty == true)
                ? profile!.username!.trim()
                : s.hostUsername,
            handle:
                '@${((profile?.username ?? s.hostUsername).toLowerCase().replaceAll(' ', '_'))}',
            avatarUrl: avatar,
            followers: _formatCompactCount(followers),
            following: following,
          );
        })
        .toList(growable: false);
  }

  _LiveCardItem _toLiveCardItem(LiveStreamModel stream) {
    final profile = _liveHostProfiles[stream.hostId];
    final username = (profile?.username?.trim().isNotEmpty == true)
        ? profile!.username!.trim()
        : stream.hostUsername;
    final avatar = ((profile?.profileImage ?? '').trim().isNotEmpty)
        ? (profile!.profileImage!).trim()
        : (stream.hostProfileImage?.isNotEmpty == true)
        ? stream.hostProfileImage!
        : 'https://i.pravatar.cc/80?u=${stream.hostId}';
    return _LiveCardItem(
      thumbnailUrl: avatar,
      name: username,
      handle: '@${username.toLowerCase().replaceAll(' ', '_')}',
      avatarUrl: avatar,
      viewerCount: stream.viewerCount,
    );
  }

  static String _formatCompactCount(int n) {
    if (n >= 1000000) {
      final v = n / 1000000;
      return '${v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)}M';
    }
    if (n >= 1000) {
      final v = n / 1000;
      return '${v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)}K';
    }
    return '$n';
  }

  static IconData _categoryIconFor(String category) {
    final c = category.toLowerCase();
    if (c.contains('game')) return Icons.sports_esports_rounded;
    if (c.contains('music') || c.contains('concert'))
      return Icons.music_note_rounded;
    if (c.contains('sport')) return Icons.sports_soccer_rounded;
    if (c.contains('news')) return Icons.newspaper_rounded;
    if (c.contains('travel')) return Icons.travel_explore_rounded;
    return Icons.live_tv_rounded;
  }

  Future<void> _toggleFollow(_UserSearchItem user) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null || me.isEmpty || me == user.uid) return;
    final currently = _myFollowingIds.contains(user.uid);
    try {
      if (currently) {
        await _userService.unfollowUser(currentUid: me, targetUid: user.uid);
        _myFollowingIds.remove(user.uid);
      } else {
        await _userService.followUser(currentUid: me, targetUid: user.uid);
        _myFollowingIds.add(user.uid);
      }
      if (!mounted) return;
      setState(() {
        final idx = _allUsers.indexWhere((u) => u.uid == user.uid);
        if (idx >= 0) {
          _allUsers[idx] = _allUsers[idx].copyWith(
            isFollowing: _myFollowingIds.contains(user.uid),
          );
        }
      });
    } catch (_) {}
  }

  void _onSearchTextChange() {
    setState(() {});
  }

  @override
  void dispose() {
    _liveStreamsSub?.cancel();
    _searchFocusNode.removeListener(_onSearchFocusChange);
    _searchController.removeListener(_onSearchTextChange);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchFocusChange() {
    setState(() => _isSearchActive = _searchFocusNode.hasFocus);
  }

  void _exitSearchMode() {
    _searchFocusNode.unfocus();
    setState(() => _isSearchActive = false);
  }

  void _removeRecentSearch(int index) {
    setState(() {
      _recentSearches = List<String>.from(_recentSearches)..removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType
            .feed, // Using existing feed gradient but we can custom craft it if needed
        child: Column(
          children: [
            _buildSearchBar(
              showBackButton: _isSearchActive,
              showHashButton: !_isSearchActive,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isSearchActive
                  ? _buildSearchActiveView()
                  : _searchController.text.trim().isEmpty
                  ? _buildSearchIdleView()
                  : _buildSearchResultsView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchIdleView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTabs(),
        const SizedBox(height: 24),
        Expanded(
          child: _selectedTabIndex == 0
              ? _buildIdleLiveContent()
              : _selectedTabIndex == 1
              ? _buildIdleVRContent()
              : _buildIdleUsersContent(),
        ),
      ],
    );
  }

  Widget _buildIdleLiveContent() {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        _buildLiveNowSection(),
        const SizedBox(height: AppSpacing.xl),
        _buildSection(
          'Recommended For you',
          _dynamicRecommendedItems,
          showViewAll: true,
        ),
        const SizedBox(height: AppSpacing.xl),
        _buildLiveCategoriesSection(),
        const SizedBox(height: AppSpacing.xl),
        _buildTopCreatorsSection(),
        const SizedBox(height: AppSpacing.xl),
        _buildSection('Explore More', _dynamicExploreItems, showViewAll: true),
      ],
    );
  }

  Widget _buildIdleVRContent() {
    return Consumer<SubscriptionController>(
      builder: (context, subscriptionController, _) {
        if (!subscriptionController.hasVRAccess) {
          return const VrLockedView();
        }
        return GridView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: AppSpacing.xs,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.67,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _vrSearchResultItems.length,
          itemBuilder: (context, index) =>
              _VRSearchResultGridCard(item: _vrSearchResultItems[index]),
        );
      },
    );
  }

  Widget _buildIdleUsersContent() {
    _ensureUsersLoaded();
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Suggested for you',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_usersLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(color: Colors.white54),
            ),
          )
        else if (_usersError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Text(
              'Could not load users right now.',
              style: TextStyle(color: Colors.white70),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filteredUsers.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) => _UserSearchResultTile(
              user: _filteredUsers[index],
              onTap: () => _openUserProfile(_filteredUsers[index]),
              onFollowTap: () => _toggleFollow(_filteredUsers[index]),
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _buildSearchResultsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTabs(),
        const SizedBox(height: 16),
        Expanded(
          child: _selectedTabIndex == 0
              ? _buildLiveSearchResultsGrid()
              : _selectedTabIndex == 1
              ? _buildVRSearchResultsGrid()
              : _buildUserSearchResultsList(),
        ),
      ],
    );
  }

  Widget _buildLiveSearchResultsGrid() {
    final items = _dynamicLiveSearchResultItems;
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No live results found',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 14,
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: AppSpacing.xs,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _SearchResultGridCard(
        item: items[index].card,
        onTap: () => openLiveStreamScreen(context, items[index].stream),
      ),
    );
  }

  Widget _buildVRSearchResultsGrid() {
    return Consumer<SubscriptionController>(
      builder: (context, subscriptionController, _) {
        if (!subscriptionController.hasVRAccess) {
          return const VrLockedView();
        }
        return GridView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: AppSpacing.xs,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.65,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _vrSearchResultItems.length,
          itemBuilder: (context, index) =>
              _VRSearchResultGridCard(item: _vrSearchResultItems[index]),
        );
      },
    );
  }

  void _openUserProfile(_UserSearchItem user) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfileScreen(
          payload: UserProfilePayload(
            username: user.username,
            displayName: user.fullName,
            avatarUrl: user.avatarUrl,
            isVerified: user.isVerified,
            postCount: 0,
            followerCount: user.followerCount,
            followingCount: 0,
            bio: '',
            isCreator: true,
            targetUserId: user.uid,
            isFollowing: user.isFollowing,
          ),
        ),
      ),
    );
  }

  Widget _buildUserSearchResultsList() {
    _ensureUsersLoaded();
    if (_usersLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }
    if (_usersError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Could not load users right now.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _loadUsers, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final users = _filteredUsers;
    if (users.isEmpty) {
      return const Center(
        child: Text('No users found.', style: TextStyle(color: Colors.white70)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: AppSpacing.xs,
      ),
      itemCount: users.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => _UserSearchResultTile(
        user: users[index],
        onTap: () => _openUserProfile(users[index]),
        onFollowTap: () => _toggleFollow(users[index]),
      ),
    );
  }

  Widget _buildSearchActiveView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Recent',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: AppSpacing.xs,
            ),
            itemCount: _recentSearches.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) => _RecentSearchTile(
              query: _recentSearches[index],
              onTap: () {
                _searchController.text = _recentSearches[index];
                _searchFocusNode.unfocus();
                setState(() => _isSearchActive = false);
              },
              onRemove: () => _removeRecentSearch(index),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar({
    required bool showBackButton,
    required bool showHashButton,
  }) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            if (showBackButton) ...[
              GestureDetector(
                onTap: _exitSearchMode,
                child: Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Image.asset(
                    'assets/vyooO_icons/Home/chevron_left.png',
                    color: Colors.white,
                    width: 22,
                    height: 22,
                  ),
                ),
              ),
            ],
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 48,
                  color: Colors.white.withValues(alpha: 0.12),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    cursorColor: Colors.white70,
                    cursorWidth: 1.2,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Image.asset(
                          'assets/vyooO_icons/Home/nav_bar_icons/search.png',
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 24,
                          height: 24,
                        ),
                      ),
                      hintText: 'Search',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/vyooO_icons/Search/microphone.png',
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 22,
                              height: 22,
                            ),
                          ],
                        ),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            ),
            if (showHashButton) ...[
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/vyooO_icons/Search/hashtag.png',
                    width: 24,
                    height: 24,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 44,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1327).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          for (int index = 0; index < _tabs.length; index++) ...[
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_selectedTabIndex != index) {
                    setState(() => _selectedTabIndex = index);
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    gradient: index == _selectedTabIndex
                        ? const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xFFDE106B), Color(0xFFF81945)],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _tabs[index],
                    style: TextStyle(
                      color: index == _selectedTabIndex
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: index == _selectedTabIndex
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            if (index < _tabs.length - 1)
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.white.withValues(alpha: 0.16),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveNowSection() {
    if (_liveStreams.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ongoing Now',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No live streams right now. Check back soon!',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Ongoing Now',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 260,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _liveStreams.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final stream = _liveStreams[index];
              return _LiveCard(
                item: _toLiveCardItem(stream),
                onTap: () => openLiveStreamScreen(context, stream),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSection(
    String title,
    List<_LiveCardItem> items, {
    bool showViewAll = true,
  }) {
    final hasItems = items.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (showViewAll)
                GestureDetector(
                  onTap: () {},
                  child: Text(
                    'View All',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (!hasItems)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'No live streams available right now.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          )
        else
          SizedBox(
            height: 260,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) => _LiveCard(item: items[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildLiveCategoriesSection() {
    final categories = _dynamicCategoryItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Live Categories',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (categories.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'No categories yet. Categories appear when hosts set stream categories.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) =>
                  _CategoryCard(item: categories[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildTopCreatorsSection() {
    final creators = _dynamicCreatorItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Top Live Creators',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (creators.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Top creators will appear when users go live.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          )
        else
          SizedBox(
            height: 300,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: creators.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) =>
                  _CreatorCard(item: creators[index]),
            ),
          ),
      ],
    );
  }
}

class _RecentSearchTile extends StatelessWidget {
  const _RecentSearchTile({
    required this.query,
    required this.onTap,
    required this.onRemove,
  });

  final String query;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
              width: 0.8,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                query,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Image.asset(
                  'assets/vyooO_icons/Search/close.png',
                  width: 20,
                  height: 20,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultGridCard extends StatelessWidget {
  const _SearchResultGridCard({required this.item, this.onTap});

  final _LiveCardItem item;
  final VoidCallback? onTap;

  static String _formatCount(int n) {
    if (n >= 1000) return (n / 1000).toStringAsFixed(0);
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
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.deleteRed,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Live',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Image.asset(
                    'assets/vyooO_icons/Search/view_count.png',
                    width: 12,
                    height: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    _formatCount(item.viewerCount),
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
                    backgroundImage:
                        Uri.tryParse(item.avatarUrl)?.isAbsolute == true
                        ? NetworkImage(item.avatarUrl)
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          item.handle,
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

class _VRSearchResultGridCard extends StatelessWidget {
  const _VRSearchResultGridCard({required this.item});

  final _VRSearchItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => VrPlayerScreen(
              title: item.creatorName,
              videoUrl: item.videoUrl,
            ),
          ),
        );
      },
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
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'VR',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Image.asset(
                    'assets/vyooO_icons/Search/view_count.png',
                    width: 12,
                    height: 12,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${item.viewerCount}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('👑', style: TextStyle(fontSize: 12)),
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
                    backgroundImage:
                        Uri.tryParse(item.avatarUrl)?.isAbsolute == true
                        ? NetworkImage(item.avatarUrl)
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
                            Expanded(
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
                            if (item.isVerified)
                              Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Image.asset(
                                  'assets/vyooO_icons/Search/verified_account.png',
                                  width: 12,
                                  height: 12,
                                  color: const Color(0xFFFF2D55),
                                ),
                              ),
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

class _UserSearchResultTile extends StatelessWidget {
  const _UserSearchResultTile({
    required this.user,
    this.onTap,
    this.onFollowTap,
  });

  final _UserSearchItem user;
  final VoidCallback? onTap;
  final VoidCallback? onFollowTap;

  // static String _formatFollowers(int n) {
  //   if (n >= 1000000) {
  //     final v = n / 1000000;
  //     return '${v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)}M';
  //   }
  //   if (n >= 1000) {
  //     final v = n / 1000;
  //     return '${v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)}K';
  //   }
  //   return '$n';
  // }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  backgroundImage:
                      Uri.tryParse(user.avatarUrl)?.isAbsolute == true
                      ? NetworkImage(user.avatarUrl)
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (user.isVerified) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF81945),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 9,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.fullName,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onFollowTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: user.isFollowing
                        ? Colors.white.withValues(alpha: 0.1)
                        : const Color(0xFFF81945),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.isFollowing ? 'Following' : 'Follow',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveCardItem {
  const _LiveCardItem({
    required this.thumbnailUrl,
    required this.name,
    required this.handle,
    required this.avatarUrl,
    this.viewerCount = 102,
    // this.isVerified = false,
  });
  final String thumbnailUrl;
  final String name;
  final String handle;
  final String avatarUrl;
  final int viewerCount;
  // final bool isVerified;
}

class _LiveSearchResultItem {
  const _LiveSearchResultItem({required this.stream, required this.card});

  final LiveStreamModel stream;
  final _LiveCardItem card;
}

class _UserSearchItem {
  const _UserSearchItem({
    required this.uid,
    required this.username,
    required this.fullName,
    required this.followerCount,
    required this.avatarUrl,
    this.isVerified = false,
    this.isFollowing = false,
  });
  final String uid;
  final String username;
  final String fullName;
  final int followerCount;
  final String avatarUrl;
  final bool isVerified;
  final bool isFollowing;

  _UserSearchItem copyWith({
    String? uid,
    String? username,
    String? fullName,
    int? followerCount,
    String? avatarUrl,
    bool? isVerified,
    bool? isFollowing,
  }) {
    return _UserSearchItem(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      followerCount: followerCount ?? this.followerCount,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVerified: isVerified ?? this.isVerified,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}

class _VRSearchItem {
  const _VRSearchItem({
    required this.thumbnailUrl,
    required this.creatorName,
    required this.creatorHandle,
    required this.avatarUrl,
    this.viewerCount = 102,
    this.isVerified = false,
    this.videoUrl,
  });
  final String thumbnailUrl;
  final String creatorName;
  final String creatorHandle;
  final String avatarUrl;
  final int viewerCount;
  final bool isVerified;
  final String? videoUrl;
}

final List<_VRSearchItem> _vrSearchResultItems = [
  _VRSearchItem(
    thumbnailUrl:
        'https://images.unsplash.com/photo-1511497584788-876760111969?q=80&w=1200&auto=format&fit=crop',
    creatorName: 'Sofia Vergara',
    creatorHandle: '@Soffy33',
    avatarUrl: 'https://i.pravatar.cc/80?img=32',
    viewerCount: 102,
    videoUrl: VrPlayerScreen.testVideoUrls[0],
  ),
  _VRSearchItem(
    thumbnailUrl:
        'https://images.unsplash.com/photo-1501785888041-af3ef285b470?q=80&w=1200&auto=format&fit=crop',
    creatorName: 'Selena Gomet',
    creatorHandle: '@GomethoComet',
    avatarUrl: 'https://i.pravatar.cc/80?img=28',
    isVerified: true,
    viewerCount: 102,
    videoUrl: VrPlayerScreen.testVideoUrls[1],
  ),
  _VRSearchItem(
    thumbnailUrl:
        'https://images.unsplash.com/photo-1511497584788-876760111969?q=80&w=1200&auto=format&fit=crop',
    creatorName: 'Sofia Vergara',
    creatorHandle: '@Soffy33',
    avatarUrl: 'https://i.pravatar.cc/80?img=32',
    viewerCount: 102,
    videoUrl: VrPlayerScreen.testVideoUrls[2],
  ),
  _VRSearchItem(
    thumbnailUrl:
        'https://images.unsplash.com/photo-1501785888041-af3ef285b470?q=80&w=1200&auto=format&fit=crop',
    creatorName: 'Selena Gomet',
    creatorHandle: '@GomethoComet',
    avatarUrl: 'https://i.pravatar.cc/80?img=28',
    isVerified: true,
    viewerCount: 102,
    videoUrl: VrPlayerScreen.testVideoUrls[0],
  ),
];

class _CategoryItem {
  const _CategoryItem({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

class _CreatorItem {
  const _CreatorItem({
    required this.name,
    required this.handle,
    required this.avatarUrl,
    required this.followers,
    required this.following,
  });
  final String name;
  final String handle;
  final String avatarUrl;
  final String followers;
  final int following;
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.item, this.onTap});

  final _LiveCardItem item;
  final VoidCallback? onTap;

  static const double cardWidth = 160;
  static const double cardHeight = 220;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Uri.tryParse(item.thumbnailUrl)?.isAbsolute == true
                  ? Image.network(
                      item.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, e, s) =>
                          Container(color: const Color(0xFF1A0020)),
                    )
                  : Container(color: const Color(0xFF1A0020)),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.9),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Live',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/vyooO_icons/Search/view_count.png',
                            width: 11,
                            height: 11,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${item.viewerCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.grey.shade900,
                        backgroundImage:
                            Uri.tryParse(item.avatarUrl)?.isAbsolute == true
                            ? NetworkImage(item.avatarUrl)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (true) ...[
                                // Design has red checks for these
                                const SizedBox(width: 4),
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Image.asset(
                                    'assets/vyooO_icons/Search/verified_account.png',
                                    width: 8,
                                    height: 8,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            item.handle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                            overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.item});

  final _CategoryItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 120,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  size: 32,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatorCard extends StatefulWidget {
  const _CreatorCard({required this.item});

  final _CreatorItem item;

  @override
  State<_CreatorCard> createState() => _CreatorCardState();
}

class _CreatorCardState extends State<_CreatorCard> {
  bool _isFollowing = false;

  static const double cardWidth = 160;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: cardWidth,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.grey.shade800,
                  backgroundImage:
                      Uri.tryParse(item.avatarUrl)?.isAbsolute == true
                      ? NetworkImage(item.avatarUrl)
                      : null,
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/vyooO_icons/Search/verified_account.png',
                      width: 8,
                      height: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              item.handle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    Text(
                      item.followers,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Followers',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Column(
                  children: [
                    Text(
                      '${item.following}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Following',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 120,
              height: 36,
              child: TextButton(
                onPressed: () => setState(() => _isFollowing = !_isFollowing),
                style: TextButton.styleFrom(
                  backgroundColor: _isFollowing
                      ? Colors.white.withValues(alpha: 0.12)
                      : const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  _isFollowing ? 'Following' : 'Follow',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
