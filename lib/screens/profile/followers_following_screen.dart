import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/app_user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/utils/user_facing_errors.dart';
import '../../core/subscription/subscription_controller.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/subscription/subscription_screen.dart';
import 'user_profile_screen.dart';

/// Initial tab when opening the screen: 0 = Followers, 1 = Following, 2 = Subscriptions.
/// [profileUserId]: whose lists to load; omit to use the signed-in user (own profile).
class FollowersFollowingScreen extends StatefulWidget {
  const FollowersFollowingScreen({
    super.key,
    this.initialTab = 0,
    this.profileUserId,
  });

  final int initialTab;

  /// Firestore uid for the profile whose followers/following are listed.
  final String? profileUserId;

  @override
  State<FollowersFollowingScreen> createState() =>
      _FollowersFollowingScreenState();
}

class _FollowersFollowingScreenState extends State<FollowersFollowingScreen> {
  late int _selectedTabIndex;
  final TextEditingController _searchController = TextEditingController();

  bool _loadingLists = true;
  int _followerCount = 0;
  int _followingCount = 0;
  List<_ConnectionUser> _followers = [];
  List<_ConnectionUser> _following = [];
  List<_ConnectionUser> _discoverUsers = [];

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTab.clamp(0, 2);
    _searchController.addListener(() => setState(() {}));
    _loadConnections();
    // Reconcile store status on entry so paid members don't momentarily see
    // upsell UI due to delayed sandbox/store sync.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = AuthService().currentUser?.uid;
      context.read<SubscriptionController>().reconcilePaidStatus(
        firebaseUid: uid,
      );
    });
  }

  @override
  void didUpdateWidget(FollowersFollowingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileUserId != widget.profileUserId) {
      _loadConnections();
    }
  }

  Future<void> _loadConnections() async {
    final subject = widget.profileUserId ?? AuthService().currentUser?.uid;
    if (subject == null || subject.isEmpty) {
      if (mounted) {
        setState(() {
          _loadingLists = false;
          _followers = [];
          _following = [];
          _followerCount = 0;
          _followingCount = 0;
        });
      }
      return;
    }

    if (mounted) setState(() => _loadingLists = true);

    final svc = UserService();
    final me = AuthService().currentUser?.uid;
    var myFollowing = <String>[];
    var myBlocked = <String>[];
    if (me != null && me.isNotEmpty) {
      myFollowing = await svc.getFollowing(me);
      myBlocked = await svc.getBlockedUserIds(me);
    }
    final blockedSet = myBlocked.toSet();

    final followerModels = await svc.getFollowerProfilesForUser(subject);
    final followingModels = await svc.getFollowingProfilesForUser(subject);
    final fc = await svc.getFollowerCount(subject);
    final discoverItems = me == null || me.isEmpty
        ? <UserDiscoveryItem>[]
        : await svc.discoverUserItems(currentUid: me, limit: 160);
    final discover = discoverItems
        .map(
          (i) => _ConnectionUser(
            targetUserId: i.uid,
            name: i.displayName,
            username: i.username,
            avatarUrl: i.avatarUrl,
            isVerified: i.isVerified,
            accountType: i.accountType,
            vipVerified: i.vipVerified,
            isFollowing: i.isFollowing,
          ),
        )
        .toList();

    if (!mounted) return;
    setState(() {
      _loadingLists = false;
      _followerCount = fc;
      _followingCount = followingModels.length;
      _followers = followerModels
          .where((m) => !blockedSet.contains(m.uid))
          .map((m) => _connectionFromAppUser(m, myFollowing))
          .toList();
      _following = followingModels
          .where((m) => !blockedSet.contains(m.uid))
          .map((m) => _connectionFromAppUser(m, myFollowing))
          .toList();
      _discoverUsers = discover;
    });
  }

  static _ConnectionUser _connectionFromAppUser(
    AppUserModel m,
    List<String> myFollowing,
  ) {
    final handle = (m.username != null && m.username!.trim().isNotEmpty)
        ? m.username!.trim()
        : (m.email.contains('@')
              ? m.email.split('@').first
              : (m.uid.length > 8 ? m.uid.substring(0, 8) : m.uid));
    final displayName =
        (m.displayName != null && m.displayName!.trim().isNotEmpty)
        ? m.displayName!.trim()
        : handle;
    return _ConnectionUser(
      targetUserId: m.uid,
      name: displayName,
      username: handle,
      avatarUrl: m.profileImage ?? '',
      isVerified: m.isVerified,
      accountType: m.accountType,
      vipVerified: m.vipVerified,
      isFollowing: myFollowing.contains(m.uid),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  void _showRemoveFollowerModal(BuildContext context, _ConnectionUser user) {
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _RemoveModalButton(
                    label: 'Block',
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      final target = user.targetUserId;
                      final me = AuthService().currentUser?.uid;
                      if (target == null ||
                          target.isEmpty ||
                          me == null ||
                          me.isEmpty) {
                        return;
                      }
                      try {
                        await UserService().blockUser(
                          currentUid: me,
                          targetUid: target,
                        );
                        if (context.mounted) {
                          await _loadConnections();
                          messenger.showSnackBar(
                            const SnackBar(content: Text('User blocked.')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(messageForFirestore(e))),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Block this follower?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage:
                    Uri.tryParse(user.avatarUrl)?.isAbsolute == true
                    ? NetworkImage(user.avatarUrl)
                    : null,
                child: Uri.tryParse(user.avatarUrl)?.isAbsolute != true
                    ? Icon(
                        Icons.person_rounded,
                        size: 40,
                        color: Colors.white.withValues(alpha: 0.6),
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                user.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'Blocking removes this account from your feed and they won\'t be able to follow your activity.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  void _showRemoveFollowingModal(BuildContext context, _ConnectionUser user) {
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _RemoveModalButton(
                    label: 'Unfollow',
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final id = user.targetUserId;
                      final me = AuthService().currentUser?.uid;
                      if (id == null ||
                          id.isEmpty ||
                          me == null ||
                          me.isEmpty) {
                        return;
                      }
                      try {
                        await UserService().unfollowUser(
                          currentUid: me,
                          targetUid: id,
                        );
                        if (context.mounted) {
                          await _loadConnections();
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(messageForFirestore(e))),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Remove from following?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage:
                    Uri.tryParse(user.avatarUrl)?.isAbsolute == true
                    ? NetworkImage(user.avatarUrl)
                    : null,
                child: Uri.tryParse(user.avatarUrl)?.isAbsolute != true
                    ? Icon(
                        Icons.person_rounded,
                        size: 40,
                        color: Colors.white.withValues(alpha: 0.6),
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                user.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'We won\'t tell @${user.username} that you stopped following them.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  void _showRemoveSubscriptionModal(
    BuildContext context,
    _ConnectionUser user,
  ) {
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _RemoveModalButton(
                    label: 'Remove',
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Remove Subscription?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage:
                    Uri.tryParse(user.avatarUrl)?.isAbsolute == true
                    ? NetworkImage(user.avatarUrl)
                    : null,
                child: Uri.tryParse(user.avatarUrl)?.isAbsolute != true
                    ? Icon(
                        Icons.person_rounded,
                        size: 40,
                        color: Colors.white.withValues(alpha: 0.6),
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                user.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'We won\'t tell @${user.username} that you stopped subscribing them.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF14001F), Color(0xFF4A003F), Color(0xFFDE106B)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    Expanded(
                      child: uid != null
                          ? FutureBuilder<String>(
                              future: UserService()
                                  .getUser(uid)
                                  .then(
                                    (u) => u?.username?.isNotEmpty == true
                                        ? '@${u!.username}'
                                        : (AuthService().currentUser?.email ??
                                              '@user'),
                                  ),
                              builder: (_, snap) => Text(
                                snap.data ?? '@lexilongbottom',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          : const Text(
                              '@lexilongbottom',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.menu_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),
              _buildTabs(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.input),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Search for users',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 16,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.white.withValues(alpha: 0.6),
                        size: 22,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _selectedTabIndex == 2
                    ? _buildSubscriptionsContent(context)
                    : _buildUserList(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    final followerLabel = _followerCount == 1
        ? '1 Follower'
        : '${_formatCount(_followerCount)} Followers';
    final followingLabel = '${_formatCount(_followingCount)} Following';
    final labels = [followerLabel, followingLabel, 'Subscriptions'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: List.generate(3, (index) {
          final isSelected = index == _selectedTabIndex;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTabIndex = index),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      labels[index],
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: isSelected ? 1.0 : 0.7,
                        ),
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSubscriptionsContent(BuildContext context) {
    final isSubscribed = context.watch<SubscriptionController>().isPaid;
    if (!isSubscribed) {
      return _buildBecomeMemberCard(context);
    }
    return _buildSubscriptionsList(context);
  }

  Widget _buildBecomeMemberCard(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Want to Subscribe? Become a Member!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Subscribe today to access exclusive content from top creators. Enjoy a premium, seamless viewing experience wherever you are.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFFE8C547),
                        Color(0xFFD4A84B),
                        Color(0xFFB8862E),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SubscriptionScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FaIcon(
                              FontAwesomeIcons.crown,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Become Member',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionsList(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final recommended = _discoverUsers
        .where((u) => !u.isFollowing)
        .take(10)
        .toList();
    final filtered = query.isEmpty
        ? _discoverUsers
        : _discoverUsers
              .where(
                (u) =>
                    u.name.toLowerCase().contains(query) ||
                    u.username.toLowerCase().contains(query),
              )
              .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            'Recommended for you',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recommended.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final u = recommended[index];
              return GestureDetector(
                onTap: () {},
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      backgroundImage: u.avatarUrl.isNotEmpty
                          ? NetworkImage(u.avatarUrl)
                          : null,
                      child: u.avatarUrl.isEmpty
                          ? const Icon(
                              Icons.person_rounded,
                              color: Colors.white54,
                            )
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      u.name,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ...List.generate(filtered.length, (index) {
          final user = filtered[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _SubscriptionRow(
              user: user,
              onRemove: () => _showRemoveSubscriptionModal(context, user),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => UserProfileScreen(
                      payload: UserProfilePayload(
                        username: user.username,
                        displayName: user.name,
                        avatarUrl: user.avatarUrl,
                        isVerified: user.isVerified,
                        accountType: user.accountType,
                        vipVerified: user.vipVerified,
                        postCount: 0,
                        followerCount: 0,
                        followingCount: 0,
                        bio: '',
                        isCreator: true,
                        isFollowing: user.isFollowing,
                        isSubscribed: true,
                        targetUserId: user.targetUserId,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        }),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _buildUserList(BuildContext context) {
    if (_loadingLists) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }

    final query = _searchController.text.trim().toLowerCase();
    final baseList = query.isEmpty
        ? (_selectedTabIndex == 0 ? _followers : _following)
        : _discoverUsers;
    final filtered = query.isEmpty
        ? baseList
        : baseList
              .where(
                (u) =>
                    u.name.toLowerCase().contains(query) ||
                    u.username.toLowerCase().contains(query),
              )
              .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            query.isNotEmpty
                ? 'No users found.'
                : (_selectedTabIndex == 0
                      ? 'No followers yet.'
                      : 'Not following anyone yet.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    final me = AuthService().currentUser?.uid;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemCount: filtered.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final user = filtered[index];
        final id = user.targetUserId;
        return _ConnectionRow(
          user: user,
          isFollowing: user.isFollowing,
          onUnfollowSheet: (query.isNotEmpty || _selectedTabIndex == 1)
              ? () => _showRemoveFollowingModal(context, user)
              : () => _showRemoveFollowerModal(context, user),
          onFollow: (me != null && id != null && id.isNotEmpty && me != id)
              ? () async {
                  await UserService().followUser(currentUid: me, targetUid: id);
                  await _loadConnections();
                }
              : null,
          onTap: id == null || id.isEmpty
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => UserProfileScreen(
                        payload: UserProfilePayload(
                          username: user.username,
                          displayName: user.name,
                          avatarUrl: user.avatarUrl,
                          isVerified: user.isVerified,
                          accountType: user.accountType,
                          vipVerified: user.vipVerified,
                          postCount: 0,
                          followerCount: 0,
                          followingCount: 0,
                          bio: '',
                          isCreator: true,
                          isFollowing: user.isFollowing,
                          isSubscribed: false,
                          targetUserId: id,
                        ),
                      ),
                    ),
                  );
                },
        );
      },
    );
  }
}

class _ConnectionUser {
  const _ConnectionUser({
    this.targetUserId,
    required this.name,
    required this.username,
    required this.avatarUrl,
    this.isVerified = false,
    this.accountType = 'personal',
    this.vipVerified = false,
    this.isFollowing = false,
  });
  final String? targetUserId;
  final String name;
  final String username;
  final String avatarUrl;
  final bool isVerified;
  final String accountType;
  final bool vipVerified;

  /// Whether the signed-in user follows this row (for button state).
  final bool isFollowing;
}

class _ConnectionRow extends StatefulWidget {
  const _ConnectionRow({
    required this.user,
    required this.isFollowing,
    required this.onUnfollowSheet,
    this.onFollow,
    this.onTap,
  });

  final _ConnectionUser user;
  final bool isFollowing;
  final VoidCallback onUnfollowSheet;
  final Future<void> Function()? onFollow;
  final VoidCallback? onTap;

  @override
  State<_ConnectionRow> createState() => _ConnectionRowState();
}

class _ConnectionRowState extends State<_ConnectionRow> {
  late bool _isFollowing;
  bool _followBusy = false;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.isFollowing;
  }

  @override
  void didUpdateWidget(_ConnectionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFollowing != widget.isFollowing) {
      _isFollowing = widget.isFollowing;
    }
  }

  Future<void> _onFollowTap() async {
    if (_followBusy) return;
    if (_isFollowing) {
      widget.onUnfollowSheet();
      return;
    }
    final fn = widget.onFollow;
    if (fn == null) return;
    setState(() => _followBusy = true);
    try {
      await fn();
      if (mounted) setState(() => _isFollowing = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messageForFirestore(e))));
      }
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage:
                    Uri.tryParse(widget.user.avatarUrl)?.isAbsolute == true
                    ? NetworkImage(widget.user.avatarUrl)
                    : null,
                child: Uri.tryParse(widget.user.avatarUrl)?.isAbsolute != true
                    ? Icon(
                        Icons.person_rounded,
                        color: Colors.white.withValues(alpha: 0.6),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.user.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '@${widget.user.username}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _FollowingButton(
                isFollowing: _isFollowing,
                busy: _followBusy,
                onTap: _onFollowTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row for Subscriptions tab: avatar, name, handle, "Subscribed" badge with X.
class _SubscriptionRow extends StatelessWidget {
  const _SubscriptionRow({
    required this.user,
    required this.onRemove,
    required this.onTap,
  });

  final _ConnectionUser user;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage:
                    Uri.tryParse(user.avatarUrl)?.isAbsolute == true
                    ? NetworkImage(user.avatarUrl)
                    : null,
                child: Uri.tryParse(user.avatarUrl)?.isAbsolute != true
                    ? Icon(
                        Icons.person_rounded,
                        color: Colors.white.withValues(alpha: 0.6),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '@${user.username}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Material(
                color: const Color(0xFF2A1B2E),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: InkWell(
                  onTap: onRemove,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Subscribed',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ],
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

/// Pink gradient "Remove" button for confirmation modals.
class _RemoveModalButton extends StatelessWidget {
  const _RemoveModalButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFDE106B), Color(0xFFF81945)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FollowingButton extends StatelessWidget {
  const _FollowingButton({
    required this.isFollowing,
    required this.busy,
    required this.onTap,
  });

  final bool isFollowing;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (isFollowing) {
      return Material(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: busy ? () {} : onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Following',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.close,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Material(
      color: AppColors.brandPink,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: busy ? () {} : onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Follow',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
