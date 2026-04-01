import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../widgets/reel_item_widget.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/app_user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/reels_service.dart';
import '../../core/services/user_service.dart';
import '../../core/subscription/subscription_controller.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/wrappers/auth_wrapper.dart';
import '../../features/subscription/subscription_screen.dart';
import '../../core/models/live_stream_model.dart';
import '../content/live_stream_route.dart';
import '../content/vr_detail_screen.dart';
import '../music/music_library_screen.dart';
import 'edit_profile_screen.dart';
import 'followers_following_screen.dart';
import '../settings/settings_screen.dart';

/// Own profile tab: header, stats, Edit Profile/Share, Posts/VR/Streams, empty or Become Member.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const List<String> _tabs = ['Posts', 'VR', 'Streams'];
  static const int _savedTabIndex = 3;
  int _selectedTabIndex = 0;

  Future<void> _logout(BuildContext context) async {
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
      (route) => false,
    );
  }

  Future<void> _showUploadStreamDialog(BuildContext context) async {
    final controller = TextEditingController();
    var markAsVR = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A0020),
          title: const Text(
            'Upload Stream videos',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste Cloudflare Stream video IDs (one per line or comma-separated):',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  maxLines: 6,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'abc123\ndef456\n...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                    border: const OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: markAsVR,
                  onChanged: (v) => setDialogState(() => markAsVR = v ?? false),
                  title: Text(
                    'Show in VR tab',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
                  ),
                  activeColor: const Color(0xFFDE106B),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
              ),
            ),
            FilledButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                final ids = text
                    .split(RegExp(r'[\n,;]+'))
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                if (ids.isEmpty) return;
                final messenger = ScaffoldMessenger.of(context);
                Navigator.of(ctx).pop();
                try {
                  final added = await ReelsService().seedStreamReels(ids, markAsVR: markAsVR);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Uploaded $added reel(s) to Firebase.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Upload failed: $e'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDE106B),
                foregroundColor: Colors.white,
              ),
              child: const Text('Upload to Firebase'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestAccountDeletion(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0020),
        title: const Text(
          'Delete account',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will permanently delete your account and all associated data. This cannot be undone. Are you sure?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete account',
              style: TextStyle(color: Color(0xFFD10057), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await AuthService().signOut();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account deletion requested. Sign out complete.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
      (route) => false,
    );
  }

  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF2A1B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.settings_rounded, color: Colors.white.withValues(alpha: 0.8)),
              title: Text(
                'Settings',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.music_note_rounded, color: Colors.white.withValues(alpha: 0.8)),
              title: Text(
                'Music library',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const MusicLibraryScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.upload_rounded, color: Colors.white.withValues(alpha: 0.8)),
              title: Text(
                'Upload Stream videos',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showUploadStreamDialog(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.logout_rounded, color: Colors.white.withValues(alpha: 0.8)),
              title: Text(
                'Log out',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _logout(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_forever_rounded, color: Colors.red.withValues(alpha: 0.9)),
              title: const Text(
                'Delete account',
                style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _requestAccountDeletion(context);
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final uid = AuthService().currentUser?.uid;
    final subscriptionController = context.watch<SubscriptionController>();
    final canUploadContent = subscriptionController.canUploadContent;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF14001F),
              Color(0xFF4A003F),
              Color(0xFFDE106B),
            ],
          ),
        ),
        child: SafeArea(
          child: uid == null
              ? _buildFallbackProfile(context)
              : FutureBuilder<AppUserModel?>(
                  future: UserService().getUser(uid),
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    return _buildProfileBody(context, user: user, canUploadContent: canUploadContent);
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildFallbackProfile(BuildContext context) {
    return _buildProfileBody(
      context,
      user: null,
      canUploadContent: context.watch<SubscriptionController>().canUploadContent,
    );
  }

  Widget _buildProfileBody(BuildContext context, {AppUserModel? user, required bool canUploadContent}) {
    final username = user?.username?.isNotEmpty == true
        ? '@${user!.username}'
        : (AuthService().currentUser?.email ?? 'Profile');
    final displayName = user?.username?.isNotEmpty == true ? user!.username! : 'Name +';
    final avatarUrl = user?.profileImage;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const SizedBox(width: 40),
                    Expanded(
                      child: Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showProfileMenu(context),
                      icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                CircleAvatar(
                  radius: 52,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? Icon(Icons.person_rounded, size: 52, color: Colors.white.withValues(alpha: 0.6))
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StatChip(label: 'Posts', value: '1,038'),
                    const SizedBox(width: AppSpacing.sm),
                    _StatChip(
                      label: 'Following',
                      value: '10,906',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const FollowersFollowingScreen(
                            initialTab: 1,
                            followerCount: 2437,
                            followingCount: 10906,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StatChip(
                      label: 'Followers',
                      value: '2,437',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const FollowersFollowingScreen(
                            initialTab: 0,
                            followerCount: 2437,
                            followingCount: 10906,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text(
                    'In the right place, at the right time',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: _OutlineButton(
                        label: 'Edit Profile',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => EditProfileScreen(
                                initialName: 'Matt Rife',
                                initialUsername: user?.username ?? 'mattrife_x',
                                initialBio: 'In the right place, at the right time',
                                initialMusic: 'Zulfein • Mehul Mahesh, DJ A...',
                                avatarUrl: user?.profileImage,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _OutlineButton(label: 'Share', onPressed: () {}),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                _buildTabs(),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
        ..._buildProfileContentSlivers(context, canUploadContent, uid: AuthService().currentUser?.uid ?? ''),
      ],
    );
  }

  List<Widget> _buildProfileContentSlivers(BuildContext context, bool canUploadContent, {required String uid}) {
    if (!canUploadContent) {
      if (_selectedTabIndex == 0) {
        return [SliverFillRemaining(hasScrollBody: false, child: _buildBecomeMemberPrompt(context))];
      }
      if (_selectedTabIndex == _savedTabIndex) {
        return [SliverFillRemaining(hasScrollBody: false, child: _buildEmptySavedPlaceholder())];
      }
      return [SliverFillRemaining(hasScrollBody: false, child: _buildEmptyTabPlaceholder())];
    }
    if (_selectedTabIndex == _savedTabIndex) {
      return _buildSavedGridSlivers();
    }
    switch (_selectedTabIndex) {
      case 0:
        return _buildPostsGridSlivers(uid: uid);
      case 1:
        return _buildVRGridSlivers();
      case 2:
        return _buildStreamsListSlivers();
      default:
        return [SliverFillRemaining(hasScrollBody: false, child: _buildEmptyPostsPrompt())];
    }
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
              child: Image.network(_profileMockSavedUrls[index], fit: BoxFit.cover),
            ),
            childCount: _profileMockSavedUrls.length,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildPostsGridSlivers({required String uid}) {
    if (uid.isEmpty) {
      return [SliverFillRemaining(hasScrollBody: false, child: _buildEmptyPostsPrompt())];
    }
    return [
      SliverToBoxAdapter(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('reels')
              .where('userId', isEqualTo: uid)
              .get()
              .then((q) {
                final docs = q.docs.map((d) {
                  final data = d.data();
                  return {
                    'id': d.id,
                    'videoUrl': data['videoUrl'] as String? ?? '',
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
                child: Center(child: CircularProgressIndicator(color: Colors.white54)),
              );
            }
            if (snapshot.hasError) {
              debugPrint('Profile posts error: ${snapshot.error}');
            }
            final posts = snapshot.data ?? [];
            if (posts.isEmpty) return _buildEmptyPostsPrompt();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
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
                  final videoUrl = posts[index]['videoUrl'] as String;
                  final thumbnailUrl = _thumbnailFromVideoUrl(videoUrl);
                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _ProfileReelFeedScreen(
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
                          if (thumbnailUrl.isNotEmpty)
                            Image.network(
                              thumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const SizedBox.shrink(),
                            ),
                          const Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 18),
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

  static String _thumbnailFromVideoUrl(String videoUrl) {
    try {
      final uri = Uri.parse(videoUrl);
      final videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      if (videoId.isEmpty) return '';
      return 'https://${AppConfig.cloudflareStreamSubdomain}/$videoId/thumbnails/thumbnail.jpg';
    } catch (_) {
      return '';
    }
  }

  List<Widget> _buildVRGridSlivers() {
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
              final item = _profileMockVRItems[index];
              return _ProfileVRCard(
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
            childCount: _profileMockVRItems.length,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildStreamsListSlivers() {
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index.isOdd) return const SizedBox(height: AppSpacing.md);
              final itemIndex = index ~/ 2;
              final item = _profileMockStreamItems[itemIndex];
              return SizedBox(
                height: 200,
                child: _ProfileStreamCard(
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
            childCount: _profileMockStreamItems.length * 2 - 1,
          ),
        ),
      ),
    ];
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

  Widget _buildEmptyPostsPrompt() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 80,
            color: Colors.white.withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Tap the "+" button below to post!',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBecomeMemberPrompt(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.input * 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  children: const [
                    TextSpan(text: 'Ready to post? '),
                    TextSpan(
                      text: 'Become a Member!',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Become our member to start posting your content. Unlock full access and showcase your creativity today and you can also "monetize your content"',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              Material(
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
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFFE8C547), Color(0xFFD4A84B), Color(0xFFB8862E)],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(FontAwesomeIcons.crown, size: 18, color: Colors.white.withValues(alpha: 0.95)),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTabPlaceholder() {
    return Center(
      child: Text(
        'No content yet',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
      ),
    );
  }

  Widget _buildEmptySavedPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border_rounded, size: 48, color: Colors.white.withValues(alpha: 0.5)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No saved items yet',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// Mock saved items (same grid design as Posts).
const List<String> _profileMockSavedUrls = [
  'https://picsum.photos/400/400?random=s1',
  'https://picsum.photos/400/400?random=s2',
  'https://picsum.photos/400/400?random=s3',
  'https://picsum.photos/400/400?random=s4',
  'https://picsum.photos/400/400?random=s5',
  'https://picsum.photos/400/400?random=s6',
  'https://picsum.photos/400/400?random=s7',
  'https://picsum.photos/400/400?random=s8',
  'https://picsum.photos/400/400?random=s9',
  'https://picsum.photos/400/400?random=s10',
  'https://picsum.photos/400/400?random=s11',
];

class _ProfileVRItem {
  const _ProfileVRItem({
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

final List<_ProfileVRItem> _profileMockVRItems = [
  _ProfileVRItem(
    thumbnailUrl: 'https://picsum.photos/400/600?random=vr1',
    creatorName: 'Sofia Vergara',
    creatorHandle: '@Soffv33',
    avatarUrl: 'https://i.pravatar.cc/80?img=32',
    viewCount: 102,
  ),
  _ProfileVRItem(
    thumbnailUrl: 'https://picsum.photos/400/600?random=vr2',
    creatorName: 'Selena Gomet',
    creatorHandle: '@GometnoComet',
    avatarUrl: 'https://i.pravatar.cc/80?img=28',
    viewCount: 102,
    isVerified: true,
  ),
  _ProfileVRItem(
    thumbnailUrl: 'https://picsum.photos/400/600?random=vr3',
    creatorName: 'Caroline Hade',
    creatorHandle: '@Carryhune',
    avatarUrl: 'https://i.pravatar.cc/80?img=41',
    viewCount: 102,
  ),
  _ProfileVRItem(
    thumbnailUrl: 'https://picsum.photos/400/600?random=vr4',
    creatorName: 'Alena Joy',
    creatorHandle: '@alenajoyt23',
    avatarUrl: 'https://i.pravatar.cc/80?img=38',
    viewCount: 102,
  ),
];

class _ProfileStreamItem {
  const _ProfileStreamItem({
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

final List<_ProfileStreamItem> _profileMockStreamItems = [
  _ProfileStreamItem(
    thumbnailUrl: 'https://picsum.photos/400/240?random=live1',
    title: 'Slaughter to Prevail - K.O.D. live Drumcam fro...',
    subtitle: 'Streaming now',
    isLive: true,
    viewCount: 22500,
  ),
  _ProfileStreamItem(
    thumbnailUrl: 'https://picsum.photos/400/240?random=live2',
    title: 'Live Show @standupcomedy roasting our very...',
    subtitle: 'Streamed 2 months ago',
    isLive: false,
    viewCount: 22500,
  ),
  _ProfileStreamItem(
    thumbnailUrl: 'https://picsum.photos/400/240?random=vr5',
    title: 'Hot air balloon 360°',
    subtitle: 'Streamed 1 week ago',
    isLive: false,
    viewCount: 102,
  ),
];

class _ProfileVRCard extends StatelessWidget {
  const _ProfileVRCard({required this.item, this.onTap});

  final _ProfileVRItem item;
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

class _ProfileStreamCard extends StatelessWidget {
  const _ProfileStreamCard({required this.item, this.onTap});

  final _ProfileStreamItem item;
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

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
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
              const SizedBox(height: 2),
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

/// Dark semi-transparent pill button — matches Figma "Edit Profile" / "Share" style.
class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
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

/// Full-screen vertical PageView of the user's own reels, opened from the profile Posts grid.
class _ProfileReelFeedScreen extends StatefulWidget {
  const _ProfileReelFeedScreen({required this.reels, required this.initialIndex});

  final List<Map<String, dynamic>> reels;
  final int initialIndex;

  @override
  State<_ProfileReelFeedScreen> createState() => _ProfileReelFeedScreenState();
}

class _ProfileReelFeedScreenState extends State<_ProfileReelFeedScreen> {
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
              final videoUrl = widget.reels[index]['videoUrl'] as String;
              return ReelItemWidget(
                videoUrl: videoUrl,
                isVisible: index == _currentIndex,
              );
            },
          ),
          SafeArea(
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
