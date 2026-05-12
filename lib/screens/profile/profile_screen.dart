import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vyooo/core/services/creator_subscription_service.dart';

import '../../core/controllers/reels_controller.dart';
import '../../core/config/deep_link_config.dart';
import '../../core/theme/app_gradients.dart';
import '../../widgets/caption_with_hashtags.dart';
import '../../widgets/reel_item_widget.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/app_user_model.dart';
import '../../core/models/story_highlight_model.dart';
import '../../core/models/story_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/reels_service.dart';
import '../../core/services/story_service.dart';
import '../../core/services/user_service.dart';
import '../../core/subscription/subscription_controller.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/user_facing_errors.dart';
import '../../core/utils/verification_badge.dart';
import '../../core/wrappers/auth_wrapper.dart';
import '../../features/subscription/subscription_screen.dart';
import '../../features/story/highlight_viewer_screen.dart';
import '../../features/story/widgets/profile_highlight_album_tile.dart';
import '../../features/story/story_upload_screen.dart';
import '../../features/story/story_viewer_screen.dart';
import '../../core/models/live_stream_model.dart';
import '../../core/services/live_stream_service.dart';
import '../content/live_stream_route.dart';
import '../content/post_feed_screen.dart';
import '../content/vr_detail_screen.dart';
import '../music/music_library_screen.dart';
import 'edit_profile_screen.dart';
import 'followers_following_screen.dart';
import '../settings/settings_screen.dart';

// Profile palette tuned to match the provided UI reference.
const Color _profileBgTop = Color(0xFF3B0B30);
const Color _profileBgMid = Color(0xFF190624);
const Color _profileBgGlow = Color(0xFFE81E57);
const Color _profileBgBottom = Color(0xFF33092C);
const Color _profileSurface = Color(0xFF1A0B1E);

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
  final LiveStreamService _liveStreamService = LiveStreamService();
  String? _highlightsStreamUid;
  Stream<List<StoryHighlightModel>>? _highlightsStream;

  Stream<List<StoryHighlightModel>> _highlightsStreamFor(String uid) {
    if (_highlightsStreamUid != uid || _highlightsStream == null) {
      _highlightsStreamUid = uid;
      _highlightsStream = StoryService().watchHighlightsForUser(uid);
    }
    return _highlightsStream!;
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

  static String _formatStatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  static bool _isValidNetworkUrl(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.isAbsolute || uri.host.isEmpty) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  Future<void> _shareProfile({required String uid, String? username}) async {
    final ref = uid.trim();
    if (ref.isEmpty) return;
    final link = DeepLinkConfig.profileWebUri(ref).toString();
    final handle = (username ?? '').trim();
    final message = handle.isNotEmpty
        ? 'Check out @$handle on Vyooo:\n$link'
        : 'Check out this profile on Vyooo:\n$link';
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

  Future<void> _logout(BuildContext context) async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppGradients.premiumDarkGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Do you want to logout from your account?',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      'No, stay',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      'Yes, Logout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (shouldLogout != true) return;
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
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    border: const OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: markAsVR,
                  onChanged: (v) => setDialogState(() => markAsVR = v ?? false),
                  title: Text(
                    'Show in VR tab',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
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
                  final added = await ReelsService().seedStreamReels(
                    ids,
                    markAsVR: markAsVR,
                  );
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
              style: TextStyle(
                color: Color(0xFFD10057),
                fontWeight: FontWeight.w600,
              ),
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

  Future<void> _openMyStoryComposerOrViewer(
    BuildContext context, {
    required String userId,
    required String username,
    required String avatarUrl,
  }) async {
    final activeStories = await StoryService().getMyStories();
    if (!mounted) return;
    if (activeStories.isEmpty) {
      final posted = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(builder: (_) => const StoryUploadScreen()),
      );
      if (posted == true && mounted) setState(() {});
      return;
    }
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => StoryViewerScreen(
          groups: [
            StoryGroup(
              userId: userId,
              username: username,
              avatarUrl: avatarUrl,
              stories: activeStories,
            ),
          ],
          initialGroupIndex: 0,
          initialStoryIndex: 0,
          onStoriesModified: () {
            if (mounted) setState(() {});
          },
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 200),
      ),
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
              leading: Icon(
                Icons.settings_rounded,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              title: Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.music_note_rounded,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              title: Text(
                'Music library',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MusicLibraryScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.upload_rounded,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              title: Text(
                'Upload Stream videos',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showUploadStreamDialog(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.logout_rounded,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              title: Text(
                'Log out',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _logout(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_forever_rounded,
                color: Colors.red.withValues(alpha: 0.9),
              ),
              title: const Text(
                'Delete account',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
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
          // Center-right magenta glow like the reference screenshot.
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
          SafeArea(
            child: uid == null
                ? _buildFallbackProfile(context)
                : StreamBuilder<AppUserModel?>(
                    stream: UserService().userStream(uid),
                    builder: (context, userSnap) {
                      final user = userSnap.data;
                      if (userSnap.connectionState == ConnectionState.waiting &&
                          user == null) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white70,
                            ),
                          ),
                        );
                      }
                      return StreamBuilder<int>(
                        stream: UserService().followerCountStream(uid),
                        builder: (context, followerSnap) {
                          final fc = followerSnap.data ?? 0;
                          return StreamBuilder<int>(
                            stream: UserService().reelCountStream(uid),
                            builder: (context, postSnap) {
                              final pc = postSnap.data ?? 0;
                              return StreamBuilder<int>(
                                stream: CreatorSubscriptionService()
                                    .subscriberCountStream(uid),
                                builder: (context, subSnap) {
                                  final sc = subSnap.data ?? 0;
                                  final following = user?.following.length ?? 0;
                                  return _buildProfileBody(
                                    context,
                                    user: user,
                                    profileUid: uid,
                                    canUploadContent: canUploadContent,
                                    followerCount: fc,
                                    followingCount: following,
                                    postCount: pc,
                                    subscriberCount: sc,
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackProfile(BuildContext context) {
    return _buildProfileBody(
      context,
      user: null,
      profileUid: '',
      canUploadContent: context
          .watch<SubscriptionController>()
          .canUploadContent,
      followerCount: 0,
      followingCount: 0,
      postCount: 0,
      subscriberCount: 0,
    );
  }

  Widget _buildProfileBody(
    BuildContext context, {
    AppUserModel? user,
    required String profileUid,
    required bool canUploadContent,
    required int followerCount,
    required int followingCount,
    required int postCount,
    required int subscriberCount,
  }) {
    final username = user?.username?.isNotEmpty == true
        ? user!.username!
        : (AuthService().currentUser?.email ?? 'Profile');
    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : (user?.username?.isNotEmpty == true ? user!.username! : 'Name +');
    final avatarUrl = user?.profileImage;
    final isVerified = user?.isVerified ?? false;
    final badgeColor = verificationBadgeColor(
      isVerified: isVerified,
      accountType: user?.accountType ?? 'personal',
      vipVerified: user?.vipVerified ?? false,
    );
    final accountTypeKey = (user?.accountType ?? 'personal')
        .trim()
        .toLowerCase();
    final accountTypeLabel = _accountTypeLabel(accountTypeKey);
    final bio = (user?.bio ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showProfileMenu(context),
                      icon: const Icon(
                        Icons.menu_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerRight,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                FutureBuilder<List<StoryModel>>(
                  future: StoryService().getMyStories(),
                  builder: (context, snapshot) {
                    final hasStory =
                        (snapshot.data ?? const <StoryModel>[]).isNotEmpty;
                    return GestureDetector(
                      onTap: () => _openMyStoryComposerOrViewer(
                        context,
                        userId: profileUid,
                        username: user?.username ?? 'you',
                        avatarUrl: user?.profileImage ?? '',
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: hasStory
                              ? AppGradients.storyRingGradient
                              : null,
                          border: null,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(hasStory ? 2 : 0),
                          child: CircleAvatar(
                            radius: 54,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.1,
                            ),
                            backgroundImage: _isValidNetworkUrl(avatarUrl)
                                ? NetworkImage(avatarUrl!)
                                : null,
                            child: !_isValidNetworkUrl(avatarUrl)
                                ? Icon(
                                    Icons.person_rounded,
                                    size: 54,
                                    color: Colors.white.withValues(alpha: 0.4),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<StoryModel>>(
                  future: StoryService().getMyStories(),
                  builder: (context, snapshot) {
                    final hasStory =
                        (snapshot.data ?? const <StoryModel>[]).isNotEmpty;
                    return GestureDetector(
                      onTap: () => _openMyStoryComposerOrViewer(
                        context,
                        userId: profileUid,
                        username: user?.username ?? 'you',
                        avatarUrl: user?.profileImage ?? '',
                      ),
                      child: Text(
                        hasStory ? 'View story' : 'Add story',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: badgeColor,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Text(
                    accountTypeLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: Text(
                      bio,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StatChip(
                      label: 'Posts',
                      value: _formatStatCount(postCount),
                    ),
                    const SizedBox(width: 12),
                    _StatChip(
                      label: 'Followers',
                      value: _formatStatCount(followerCount),
                      onTap: () {
                        if (profileUid.isEmpty) return;
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => FollowersFollowingScreen(
                              initialTab: 0,
                              profileUserId: profileUid,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    _StatChip(
                      label: 'Following',
                      value: _formatStatCount(followingCount),
                      onTap: () {
                        if (profileUid.isEmpty) return;
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => FollowersFollowingScreen(
                              initialTab: 1,
                              profileUserId: profileUid,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    _StatChip(
                      label: 'Subscriptions',
                      value: _formatStatCount(subscriberCount),
                    ),
                  ],
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
                                initialName:
                                    user?.displayName ?? user?.username ?? '',
                                initialUsername: user?.username ?? '',
                                initialBio: user?.bio ?? '',
                                initialMusic: 'Zulfein • Mehul Mahesh, DJ A...',
                                avatarUrl: user?.profileImage,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _OutlineButton(
                        label: 'Share',
                        icon: Icons.share_outlined,
                        onPressed: () => _shareProfile(
                          uid: profileUid,
                          username: user?.username,
                        ),
                      ),
                    ),
                  ],
                ),
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
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                final compactTabs = h < 140;
                final topPad = compactTabs ? 8.0 : 24.0;
                final tabGap = compactTabs ? 8.0 : 16.0;
                return Column(
                  children: [
                    SizedBox(height: topPad),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: _buildTabs(compact: compactTabs),
                    ),
                    SizedBox(height: tabGap),
                    Expanded(
                      child: CustomScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        slivers: _buildProfileContentSlivers(
                          context,
                          canUploadContent,
                          uid: profileUid,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
          ),
        ),
        _buildHighlightsAboveNavBar(context, profileUid, user),
      ],
    );
  }

  Widget _buildHighlightsAboveNavBar(
    BuildContext context,
    String profileUid,
    AppUserModel? user,
  ) {
    if (profileUid.isEmpty) return const SizedBox.shrink();
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
            stream: _highlightsStreamFor(profileUid),
            builder: (context, snap) {
              if (snap.hasError) {
                debugPrint('Profile highlights stream: ${snap.error}');
              }
              final highlights = snap.data ?? const <StoryHighlightModel>[];
              final loading =
                  snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Highlights',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (loading) ...[
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (snap.hasError)
                    Text(
                      'Could not load highlights. Pull to refresh or try again.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    )
                  else if (highlights.isEmpty)
                    GestureDetector(
                      onTap: () => _openMyStoryComposerOrViewer(
                        context,
                        userId: profileUid,
                        username: user?.username ?? 'you',
                        avatarUrl: user?.profileImage ?? '',
                      ),
                      child: Text(
                        'Open your story, tap ···, then "Add to highlight" to save one here.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                          height: 1.35,
                          decoration: TextDecoration.underline,
                          decorationColor:
                              Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    )
                  else
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
                                    userId: profileUid,
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

  List<Widget> _buildProfileContentSlivers(
    BuildContext context,
    bool canUploadContent, {
    required String uid,
  }) {
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
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyPostsPrompt(context),
          ),
        ];
    }
  }

  List<Widget> _buildSavedGridSlivers() {
    final uid = AuthService().currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildEmptySavedPlaceholder(),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: ReelsController().fetchFavoriteReelsForProfile(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                  ),
                ),
              );
            }
            if (snapshot.hasError) {
              debugPrint('Favorite reels load error: ${snapshot.error}');
              return SizedBox(
                height: 200,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      messageForFirestore(snapshot.error),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              );
            }
            final savedReels = snapshot.data ?? <Map<String, dynamic>>[];
            if (savedReels.isEmpty) {
              return _buildEmptySavedPlaceholder();
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
                  final thumb = _thumbnailFromSavedReel(reel);
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
                            creatorName:
                                (reel['username'] as String? ?? '')
                                    .trim()
                                    .isNotEmpty
                                ? (reel['username'] as String).trim()
                                : 'Profile User',
                            creatorHandle:
                                '@${((reel['username'] as String?) ?? 'profile').replaceAll('@', '')}',
                            avatarUrl: (reel['avatarUrl'] as String? ?? '')
                                .trim(),
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

  static String _thumbnailFromSavedReel(Map<String, dynamic> reel) {
    final imageUrl = (reel['imageUrl'] as String?)?.trim() ?? '';
    if (imageUrl.isNotEmpty) return imageUrl;
    final explicitThumb = (reel['thumbnailUrl'] as String?)?.trim() ?? '';
    if (explicitThumb.isNotEmpty) return explicitThumb;
    final videoUrl = (reel['videoUrl'] as String?)?.trim() ?? '';
    if (videoUrl.isEmpty) return '';
    return _thumbnailFromVideoUrl(videoUrl);
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
    return _thumbnailFromVideoUrl(videoUrl);
  }

  List<Widget> _buildPostsGridSlivers({required String uid}) {
    if (uid.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildEmptyPostsPrompt(context),
        ),
      ];
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
                    'userId': data['userId'] as String? ?? '',
                    'username': data['username'] as String? ?? '',
                    'handle': data['handle'] as String? ?? '',
                    'avatarUrl': data['avatarUrl'] as String? ?? '',
                    'videoUrl': data['videoUrl'] as String? ?? '',
                    'imageUrl': data['imageUrl'] as String? ?? '',
                    'thumbnailUrl': data['thumbnailUrl'] as String? ?? '',
                    'mediaType': data['mediaType'] as String? ?? '',
                    'caption': data['caption'] as String? ?? '',
                    'likes': (data['likes'] as num?)?.toInt() ?? 0,
                    'comments': (data['comments'] as num?)?.toInt() ?? 0,
                    'shares': (data['shares'] as num?)?.toInt() ?? 0,
                    'views': (data['views'] as num?)?.toInt() ?? 0,
                    'saves': (data['saves'] as num?)?.toInt() ?? 0,
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
            if (snapshot.hasError) {
              debugPrint('Profile posts error: ${snapshot.error}');
              return SizedBox(
                height: 200,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      messageForFirestore(snapshot.error),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              );
            }
            final posts = snapshot.data ?? [];
            if (posts.isEmpty) return _buildEmptyPostsPrompt(context);
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
                  final thumbnailUrl = _thumbnailFromReel(reel);
                  final mediaType = ((reel['mediaType'] as String?) ?? '')
                      .toLowerCase();
                  final isVideo = mediaType != 'image';
                  final username = (reel['username'] as String? ?? '').trim();
                  final avatarUrl = (reel['avatarUrl'] as String? ?? '').trim();
                  final handle = username.isNotEmpty
                      ? '@${username.replaceAll('@', '')}'
                      : '@profile';
                  final isVerified = reel['isVerified'] == true;
                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PostFeedScreen(
                          payload: PostFeedPayload(
                            posts: posts,
                            initialIndex: index,
                            creatorName: username.isNotEmpty
                                ? username
                                : 'Profile User',
                            creatorHandle: handle,
                            avatarUrl: avatarUrl.isNotEmpty ? avatarUrl : '',
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
                          if (thumbnailUrl.isNotEmpty)
                            Image.network(
                              thumbnailUrl,
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

  static String _thumbnailFromVideoUrl(String videoUrl) {
    try {
      final uri = Uri.parse(videoUrl);
      final videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      if (videoId.isEmpty) return '';
      return 'https://videodelivery.net/$videoId/thumbnails/thumbnail.jpg';
    } catch (_) {
      return '';
    }
  }

  List<Widget> _buildVRGridSlivers() {
    final uid = AuthService().currentUser?.uid ?? '';
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
                .where((r) => (r['userId']?.toString() ?? '') == uid)
                .toList(growable: false);
            if (reels.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No VR posts yet',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              );
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
                final username = (item['username']?.toString() ?? '').trim();
                final handle = (item['handle']?.toString() ?? '').trim();
                final avatar = (item['avatarUrl']?.toString() ?? '').trim();
                final thumb = _thumbnailFromReel(item);
                final likes = (item['likes'] as num?)?.toInt() ?? 0;
                return _ProfileVRCard(
                  item: _ProfileVRItem(
                    thumbnailUrl: thumb,
                    creatorName: username.isNotEmpty ? username : 'Creator',
                    creatorHandle: handle.isNotEmpty ? handle : '@creator',
                    avatarUrl: avatar,
                    viewCount: (item['views'] as num?)?.toInt() ?? 0,
                    isVerified: false,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => VRDetailScreen(
                        payload: VRDetailPayload(
                          creatorName: username.isNotEmpty
                              ? username
                              : 'Creator',
                          creatorHandle: handle.isNotEmpty
                              ? handle
                              : '@creator',
                          avatarUrl: avatar,
                          thumbnailUrl: thumb,
                          likeCount: likes,
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

  List<Widget> _buildStreamsListSlivers() {
    final uid = AuthService().currentUser?.uid ?? '';
    return [
      SliverToBoxAdapter(
        child: StreamBuilder<List<LiveStreamModel>>(
          stream: _liveStreamService.savedStreams(uid),
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
            if (streams.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No saved streams yet',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              itemCount: streams.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final stream = streams[index];
                return SizedBox(
                  height: 200,
                  child: _ProfileStreamCard(
                    item: _ProfileStreamItem(
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

  Widget _buildTabs({bool compact = false}) {
    final outerPad = compact ? 2.0 : 4.0;
    final tabVPad = compact ? 6.0 : 10.0;
    final tabFont = compact ? 12.0 : 13.0;
    final dividerH = compact ? 12.0 : 16.0;
    final starPad = compact ? 8.0 : 10.0;
    final starIcon = compact ? 18.0 : 20.0;
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.all(outerPad),
            decoration: BoxDecoration(
              color: const Color(0xFF2B1C2D),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              children: List.generate(_tabs.length, (index) {
                final isSelected = index == _selectedTabIndex;
                return Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () =>
                                setState(() => _selectedTabIndex = index),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: tabVPad),
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
                                        : Colors.white.withValues(alpha: 0.8),
                                    fontSize: tabFont,
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
                      if (index < _tabs.length - 1 &&
                          !isSelected &&
                          _selectedTabIndex != index + 1)
                        Container(
                          height: dividerH,
                          width: 1,
                          color: Colors.white.withValues(alpha: 0.1),
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
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.all(starPad),
              decoration: BoxDecoration(
                color: const Color(0xFF2B1C2D),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _selectedTabIndex == _savedTabIndex
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: _selectedTabIndex == _savedTabIndex
                    ? const Color(0xFFFF1E5E)
                    : Colors.white.withValues(alpha: 0.8),
                size: starIcon,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPostsPrompt(
    BuildContext context, {
    bool showModalOnTap = false,
  }) {
    return InkWell(
      onTap: showModalOnTap ? () => _showBecomeMemberSheet(context) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 40,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Tap the "+" button below to post!',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showBecomeMemberSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _buildBecomeMemberPrompt(context, isModal: true),
    );
  }

  Widget _buildBecomeMemberPrompt(
    BuildContext context, {
    bool isModal = false,
  }) {
    final content = Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF1E0025),
        borderRadius: isModal
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.circular(AppRadius.input * 1.5),
        gradient: isModal
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2A002E), Color(0xFF14001F)],
              )
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 32),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text.rich(
            TextSpan(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
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
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Become our member to start posting your content. Unlock full access and showcase your creativity today and you can also "monetize your content"',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (isModal) Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SubscriptionScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF7D781), Color(0xFFD4A84B)],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4A84B).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.crown,
                      size: 16,
                      color: Colors.black,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Become Member',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );

    if (isModal) return content;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Center(child: content),
    );
  }

  // Widget _buildEmptyTabPlaceholder() {
  //   return Center(
  //     child: Text(
  //       'No content yet',
  //       style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
  //     ),
  //   );
  // }

  Widget _buildEmptySavedPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border_rounded,
            size: 48,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No favorite posts yet',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// Mock saved items (same grid design as Posts).
// const List<String> _profileMockSavedUrls = [
//   'https://picsum.photos/400/400?random=s1',
//   'https://picsum.photos/400/400?random=s2',
//   'https://picsum.photos/400/400?random=s3',
//   'https://picsum.photos/400/400?random=s4',
//   'https://picsum.photos/400/400?random=s5',
//   'https://picsum.photos/400/400?random=s6',
//   'https://picsum.photos/400/400?random=s7',
//   'https://picsum.photos/400/400?random=s8',
//   'https://picsum.photos/400/400?random=s9',
//   'https://picsum.photos/400/400?random=s10',
//   'https://picsum.photos/400/400?random=s11',
// ];

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
                    Color(0xFF020109),
                    Color(0xFF21002B),
                    Color(0xFFDE106B),
                    Color(0xFFF81945),
                  ],
                  stops: const [0.0, 0.20, 0.60, 1.0],
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
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 76,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF3B1D3D),
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
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 9,
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

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 8),
                Icon(icon, size: 16, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen vertical PageView of the user's own reels, opened from the profile Posts grid.
class _ProfileReelFeedScreen extends StatefulWidget {
  const _ProfileReelFeedScreen({
    required this.reels,
    required this.initialIndex,
  });

  final List<Map<String, dynamic>> reels;
  final int initialIndex;

  @override
  State<_ProfileReelFeedScreen> createState() => _ProfileReelFeedScreenState();
}

class _ProfileReelFeedScreenState extends State<_ProfileReelFeedScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  late final List<Map<String, dynamic>> _seedReels;
  final List<Map<String, dynamic>> _loopedReels = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _seedReels = widget.reels.map((r) => Map<String, dynamic>.from(r)).toList();
    _loopedReels.addAll(_seedReels);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  void _appendRandomBatch() {
    if (_seedReels.isEmpty) return;
    final batch = _seedReels.map((r) => Map<String, dynamic>.from(r)).toList()
      ..shuffle();
    if (_loopedReels.isNotEmpty && batch.length > 1) {
      final lastId = _loopedReels.last['id'];
      if (batch.first['id'] == lastId) {
        final swapIndex = batch.indexWhere((item) => item['id'] != lastId);
        if (swapIndex > 0) {
          final tmp = batch[0];
          batch[0] = batch[swapIndex];
          batch[swapIndex] = tmp;
        }
      }
    }
    _loopedReels.addAll(batch);
  }

  static String _formatCount(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return '$value';
  }

  Future<void> _editCaption(Map<String, dynamic> reel) async {
    final reelId = (reel['id'] as String?)?.trim() ?? '';
    if (reelId.isEmpty) return;
    final existing = (reel['caption'] as String?) ?? '';
    final controller = TextEditingController(text: existing);
    final nextCaption = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit caption'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Write a caption'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted || nextCaption == null || nextCaption == existing) return;
    try {
      await FirebaseFirestore.instance.collection('reels').doc(reelId).update({
        'caption': nextCaption,
      });
      if (!mounted) return;
      setState(() {
        for (final item in _seedReels) {
          if (item['id'] == reelId) item['caption'] = nextCaption;
        }
        for (final item in _loopedReels) {
          if (item['id'] == reelId) item['caption'] = nextCaption;
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update caption. Please try again.'),
        ),
      );
    }
  }

  Future<void> _deletePost(Map<String, dynamic> reel) async {
    final reelId = (reel['id'] as String?)?.trim() ?? '';
    if (reelId.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text(
          'This will remove this post from your profile feed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await FirebaseFirestore.instance.collection('reels').doc(reelId).delete();
      if (!mounted) return;
      setState(() {
        _seedReels.removeWhere((item) => item['id'] == reelId);
        _loopedReels.removeWhere((item) => item['id'] == reelId);
        if (_loopedReels.isEmpty) {
          Navigator.of(context).pop();
          return;
        }
        if (_currentIndex >= _loopedReels.length) {
          _currentIndex = _loopedReels.length - 1;
        }
      });
      if (mounted && _loopedReels.isNotEmpty) {
        _pageController.jumpToPage(_currentIndex);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete post. Please try again.'),
        ),
      );
    }
  }

  void _openPostOptions(Map<String, dynamic> reel) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: Colors.white),
              title: const Text(
                'Edit caption',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _editCaption(reel);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.deleteRed,
              ),
              title: const Text(
                'Delete post',
                style: TextStyle(color: AppColors.deleteRed),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _deletePost(reel);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentReel = _loopedReels.isEmpty
        ? null
        : _loopedReels[_currentIndex];
    final avatarUrl = ((currentReel?['avatarUrl'] as String?) ?? '').trim();
    final username = ((currentReel?['username'] as String?) ?? '').trim();
    final handle = ((currentReel?['handle'] as String?) ?? '').trim();
    final caption = ((currentReel?['caption'] as String?) ?? '').trim();
    final normalizedHandle = handle.startsWith('@') ? handle : '@$handle';
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: (i) {
              if (i >= _loopedReels.length - 2) {
                setState(() {
                  _appendRandomBatch();
                  _currentIndex = i;
                });
                return;
              }
              setState(() => _currentIndex = i);
            },
            itemCount: _loopedReels.length,
            itemBuilder: (context, index) {
              final reel = _loopedReels[index];
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
                      child: Image.network(
                        displayUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
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
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x66000000),
                    Color(0x00000000),
                    Color(0x99000000),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
              child: SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Text(
                  'Posts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (currentReel != null)
                  IconButton(
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => _openPostOptions(currentReel),
                  ),
              ],
            ),
          ),
          if (currentReel != null)
            Positioned(
              right: 16,
              bottom: 120,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _OverlayMetric(
                    icon: Icons.remove_red_eye_outlined,
                    value: _formatCount((currentReel['views'] as int?) ?? 0),
                  ),
                  const SizedBox(height: 14),
                  _OverlayMetric(
                    icon: Icons.favorite_rounded,
                    value: _formatCount((currentReel['likes'] as int?) ?? 0),
                  ),
                  const SizedBox(height: 14),
                  _OverlayMetric(
                    icon: Icons.chat_bubble_outline_rounded,
                    value: _formatCount((currentReel['comments'] as int?) ?? 0),
                  ),
                  const SizedBox(height: 14),
                  _OverlayMetric(
                    icon: Icons.reply_rounded,
                    value: _formatCount((currentReel['shares'] as int?) ?? 0),
                  ),
                  const SizedBox(height: 14),
                  _OverlayMetric(
                    icon: Icons.star_outline_rounded,
                    value: _formatCount((currentReel['saves'] as int?) ?? 0),
                  ),
                ],
              ),
            ),
          if (currentReel != null)
            Positioned(
              left: 16,
              right: 80,
              bottom: 34,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white24,
                        backgroundImage: avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl.isEmpty
                            ? const Icon(
                                Icons.person,
                                color: Colors.white70,
                                size: 18,
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              username.isNotEmpty ? username : 'My Post',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              handle.isNotEmpty
                                  ? normalizedHandle
                                  : '@myprofile',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (caption.isNotEmpty)
                    CaptionWithHashtags(
                      text: caption,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 26,
                        height: 1.05,
                      ),
                      hashtagColor: AppColors.brandPink,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      'No caption',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 26,
                        height: 1.05,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _OverlayMetric extends StatelessWidget {
  const _OverlayMetric({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
