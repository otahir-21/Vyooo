import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';


import '../../core/constants/app_colors.dart';
import '../../core/models/live_stream_model.dart';
import '../../core/services/live_stream_service.dart';
import '../../core/services/user_service.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/vr/vr_player_screen.dart';
import '../content/live_stream_route.dart';
import '../content/vr_detail_screen.dart';
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
      if (mounted) setState(() => _liveStreams = streams);
    });
    _loadUsers();
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
      final following = await _userService.getFollowing(me);
      final blocked = await _userService.getBlockedUserIds(me);
      final blockedSet = blocked.toSet();
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .limit(200)
          .get();
      final users = <_UserSearchItem>[];
      for (final d in snap.docs) {
        final data = d.data();
        final uid = (data['uid'] as String?)?.trim().isNotEmpty == true
            ? (data['uid'] as String).trim()
            : d.id;
        if (uid == me || blockedSet.contains(uid)) continue;
        final rawUsername = (data['username'] as String?)?.trim() ?? '';
        final email = (data['email'] as String?)?.trim() ?? '';
        final fallbackFromEmail =
            email.contains('@') ? email.split('@').first : '';
        final username = rawUsername.isNotEmpty
            ? rawUsername
            : (fallbackFromEmail.isNotEmpty
                ? fallbackFromEmail
                : (uid.length > 8 ? uid.substring(0, 8) : uid));
        final fullName = (data['displayName'] as String?)?.trim().isNotEmpty ==
                true
            ? (data['displayName'] as String).trim()
            : username;
        final avatar = (data['profileImage'] as String?)?.trim() ?? '';
        users.add(
          _UserSearchItem(
            uid: uid,
            username: username,
            fullName: fullName,
            followerCount: 0,
            avatarUrl: avatar,
            isVerified: false,
            isFollowing: following.contains(uid),
          ),
        );
      }
      users.sort(
        (a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()),
      );
      if (!mounted) return;
      setState(() {
        _allUsers
          ..clear()
          ..addAll(users);
        _myFollowingIds = following.toSet();
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
          _recommendedItems,
          showViewAll: true,
        ),
        const SizedBox(height: AppSpacing.xl),
        _buildLiveCategoriesSection(),
        const SizedBox(height: AppSpacing.xl),
        _buildTopCreatorsSection(),
        const SizedBox(height: AppSpacing.xl),
        _buildSection('Explore More', _exploreMoreItems, showViewAll: true),
      ],
    );
  }

  Widget _buildIdleVRContent() {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Trending VR',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _vrSearchResultItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) => SizedBox(
              width: 160,
              child: _VRSearchResultGridCard(item: _vrSearchResultItems[index]),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
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
            child: Center(child: CircularProgressIndicator(color: Colors.white54)),
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
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
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
      itemCount: _searchResultItems.length,
      itemBuilder: (context, index) =>
          _SearchResultGridCard(item: _searchResultItems[index]),
    );
  }

  Widget _buildVRSearchResultsGrid() {
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
      return const Center(child: CircularProgressIndicator(color: Colors.white54));
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
              TextButton(
                onPressed: _loadUsers,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final users = _filteredUsers;
    if (users.isEmpty) {
      return const Center(
        child: Text(
          'No users found.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: AppSpacing.xs,
      ),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
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
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
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
                child: const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.search_rounded,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 24,
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
                          Icon(
                            Icons.mic_none_rounded,
                            color: Colors.white.withValues(alpha: 0.5),
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                child: const Center(
                  child: Text(
                    '#',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w400,
                    ),
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
      height: 40,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(_tabs.length, (index) {
          final isSelected = index == _selectedTabIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedTabIndex != index) {
                  setState(() => _selectedTabIndex = index);
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Color(0xFFDE106B), Color(0xFFF81945)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  _tabs[index],
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
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
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final stream = _liveStreams[index];
              final avatar = (stream.hostProfileImage?.isNotEmpty == true)
                  ? stream.hostProfileImage!
                  : 'https://i.pravatar.cc/80?u=${stream.hostId}';
              return _LiveCard(
                item: _LiveCardItem(
                  thumbnailUrl: avatar,
                  name: stream.hostUsername,
                  handle: '@${stream.hostUsername.toLowerCase().replaceAll(' ', '_')}',
                  avatarUrl: avatar,
                  viewerCount: stream.viewerCount,
                ),
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
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 260,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) => _LiveCard(item: items[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveCategoriesSection() {
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
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categoryItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) =>
                _CategoryCard(item: _categoryItems[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildTopCreatorsSection() {
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
        SizedBox(
          height: 300,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _creatorItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) =>
                _CreatorCard(item: _creatorItems[index]),
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
          border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 0.8)),
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
                child: Icon(
                  Icons.close,
                  size: 20,
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
  const _SearchResultGridCard({required this.item});

  final _LiveCardItem item;

  static String _formatCount(int n) {
    if (n >= 1000) return (n / 1000).toStringAsFixed(0);
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
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
                  Icon(
                    Icons.visibility_outlined,
                    size: 12,
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
            builder: (_) => VRDetailScreen(
              payload: VRDetailPayload(
                title: item.title,
                videoUrl: item.videoUrl,
                thumbnailUrl: item.thumbnailUrl,
                creatorName: item.creatorName,
                creatorHandle: item.creatorHandle,
                avatarUrl: item.avatarUrl,
                description: 'It\'s the silence that is more beauti...',
                likeCount: 100000,
              ),
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
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                          item.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          '${item.creatorName} ${item.creatorHandle}',
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

  static String _formatFollowers(int n) {
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.xs,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage:
                    Uri.tryParse(user.avatarUrl)?.isAbsolute == true
                    ? NetworkImage(user.avatarUrl)
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.fullName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (user.isVerified) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: AppColors.deleteRed,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatFollowers(user.followerCount)} followers',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Material(
                color: user.isFollowing
                    ? Colors.white.withValues(alpha: 0.18)
                    : AppColors.pink,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: InkWell(
                  onTap: onFollowTap,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      user.isFollowing ? 'Following' : 'Follow',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
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
    this.isVerified = false,
  });
  final String thumbnailUrl;
  final String name;
  final String handle;
  final String avatarUrl;
  final int viewerCount;
  final bool isVerified;
}

final List<_LiveCardItem> _recommendedItems = [
  _LiveCardItem(
    thumbnailUrl: 'https://picsum.photos/160/220?random=rec1',
    name: 'Alex Rivera',
    handle: '@alexr',
    avatarUrl: 'https://i.pravatar.cc/80?img=2',
    viewerCount: 89,
  ),
  _LiveCardItem(
    thumbnailUrl: 'https://picsum.photos/160/220?random=rec2',
    name: 'Sofia Wells',
    handle: '@sofwells3',
    avatarUrl: 'https://i.pravatar.cc/80?img=1',
    viewerCount: 412,
    isVerified: true,
  ),
  _LiveCardItem(
    thumbnailUrl: 'https://picsum.photos/160/220?random=rec3',
    name: 'Night Drives',
    handle: '@nightdrives',
    avatarUrl: 'https://i.pravatar.cc/80?img=12',
    viewerCount: 67,
  ),
];

final List<_LiveCardItem> _exploreMoreItems = [
  _LiveCardItem(
    thumbnailUrl: 'https://picsum.photos/160/220?random=ex1',
    name: 'Tam',
    handle: '@tamtam03',
    avatarUrl: 'https://i.pravatar.cc/80?img=25',
    viewerCount: 102,
  ),
  _LiveCardItem(
    thumbnailUrl: 'https://picsum.photos/160/220?random=ex2',
    name: 'Mr. Caspur',
    handle: '@mrcaspur',
    avatarUrl: 'https://i.pravatar.cc/80?img=44',
    viewerCount: 102,
  ),
  _LiveCardItem(
    thumbnailUrl: 'https://picsum.photos/160/220?random=ex3',
    name: 'News Live',
    handle: '@newslive',
    avatarUrl: 'https://i.pravatar.cc/80?img=50',
    viewerCount: 89,
  ),
];

/// Mock results for "Get ready with me vlogs" / any search.
final List<_LiveCardItem> _searchResultItems = [
  _LiveCardItem(
    thumbnailUrl: 'https://picsum.photos/400/600?random=grwm1',
    name: 'Sofia Vergara',
    handle: '@sofiya23',
    avatarUrl: 'https://i.pravatar.cc/80?img=32',
    viewerCount: 102,
  ),
  _LiveCardItem(
    thumbnailUrl: 'https://picsum.photos/400/600?random=grwm2',
    name: 'Selena Gomet',
    handle: '@GometroComet',
    avatarUrl: 'https://i.pravatar.cc/80?img=28',
    viewerCount: 15000,
  ),
  _LiveCardItem(
    thumbnailUrl: 'https://picsum.photos/400/600?random=grwm3',
    name: 'Caroline Hade',
    handle: '@Carryhune',
    avatarUrl: 'https://i.pravatar.cc/80?img=41',
    viewerCount: 102,
  ),
  _LiveCardItem(
    thumbnailUrl: 'https://picsum.photos/400/600?random=grwm4',
    name: 'Alena Joy',
    handle: '@alenajoyt23',
    avatarUrl: 'https://i.pravatar.cc/80?img=38',
    viewerCount: 89,
  ),
];

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
    required this.title,
    required this.creatorName,
    required this.creatorHandle,
    required this.avatarUrl,
    this.videoUrl,
  });
  final String thumbnailUrl;
  final String title;
  final String creatorName;
  final String creatorHandle;
  final String avatarUrl;
  final String? videoUrl;
}

final List<_VRSearchItem> _vrSearchResultItems = [
  _VRSearchItem(
    thumbnailUrl: 'https://picsum.photos/400/600?random=vr1',
    title: '360° City Tour',
    creatorName: 'Alex Rivera',
    creatorHandle: '@alexvr',
    avatarUrl: 'https://i.pravatar.cc/80?img=2',
    videoUrl: VrPlayerScreen.testVideoUrls[0],
  ),
  _VRSearchItem(
    thumbnailUrl: 'https://picsum.photos/400/600?random=vr2',
    title: 'Underwater VR',
    creatorName: 'Sofia Wells',
    creatorHandle: '@sofiavr',
    avatarUrl: 'https://i.pravatar.cc/80?img=1',
    videoUrl: VrPlayerScreen.testVideoUrls[1],
  ),
  _VRSearchItem(
    thumbnailUrl: 'https://picsum.photos/400/600?random=vr3',
    title: 'Concert Experience',
    creatorName: 'Night Drives',
    creatorHandle: '@nightdrives',
    avatarUrl: 'https://i.pravatar.cc/80?img=12',
    videoUrl: VrPlayerScreen.testVideoUrls[2],
  ),
  _VRSearchItem(
    thumbnailUrl: 'https://picsum.photos/400/600?random=vr4',
    title: 'Mountain Hike 360',
    creatorName: 'Tam',
    creatorHandle: '@tamtam03',
    avatarUrl: 'https://i.pravatar.cc/80?img=25',
  ),
];

class _CategoryItem {
  const _CategoryItem({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

final List<_CategoryItem> _categoryItems = [
  _CategoryItem(label: 'Gaming', icon: Icons.sports_esports_rounded),
  _CategoryItem(label: 'Music & Concerts', icon: Icons.music_note_rounded),
  _CategoryItem(label: 'Sports', icon: Icons.sports_soccer_rounded),
];

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

final List<_CreatorItem> _creatorItems = [
  const _CreatorItem(
    name: 'BTS',
    handle: '@bts.bighit.official',
    avatarUrl: 'https://i.pravatar.cc/120?img=60',
    followers: '77.5M',
    following: 11,
  ),
  const _CreatorItem(
    name: 'Priyanka Chopra',
    handle: '@priyankachoprajonaas',
    avatarUrl: 'https://i.pravatar.cc/120?img=45',
    followers: '92.7M',
    following: 567,
  ),
  const _CreatorItem(
    name: 'Taylor Swift',
    handle: '@taylorswift',
    avatarUrl: 'https://i.pravatar.cc/120?img=47',
    followers: '102M',
    following: 0,
  ),
];

class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.item, this.onTap});

  final _LiveCardItem item;
  final VoidCallback? onTap;

  static const double cardWidth = 160;
  static const double cardHeight = 220;

  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.visibility_outlined,
                            size: 11,
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
                              if (item.isVerified || true) ...[ // Design has red checks for these
                                const SizedBox(width: 4),
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 8,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            item.handle,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
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

  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 120,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
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
                  backgroundImage: Uri.tryParse(item.avatarUrl)?.isAbsolute == true
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
                    child: const Icon(Icons.check, size: 8, color: Colors.white),
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
                    Text(item.followers, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('Followers', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                  ],
                ),
                const SizedBox(width: 20),
                Column(
                  children: [
                    Text('${item.following}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('Following', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
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
                      ? Colors.white.withOpacity(0.12)
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
