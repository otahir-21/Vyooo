import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../core/controllers/reels_controller.dart';
import '../../core/services/reels_service.dart';
import '../../core/subscription/subscription_controller.dart';
import '../../core/widgets/app_feed_header.dart';
import '../../core/widgets/app_interaction_button.dart';
import '../../features/comments/widgets/comments_bottom_sheet.dart';
import '../../features/home/widgets/following_header_stories.dart';
import '../../features/reel/widgets/download_subscription_sheet.dart';
import '../../features/reel/widgets/manage_content_preferences_sheet.dart';
import '../../features/reel/widgets/not_interested_sheet.dart';
import '../../features/reel/widgets/playback_speed_sheet.dart';
import '../../features/reel/widgets/report_sheet.dart';
import '../../features/reel/widgets/reel_more_options_sheet.dart';
import '../../features/reel/widgets/video_quality_sheet.dart';
import '../../features/reel/widgets/why_seeing_this_sheet.dart';
import '../../features/share/widgets/share_bottom_sheet.dart';
import '../../features/vr/vr_screen.dart';
import '../../widgets/reel_item_widget.dart';

enum HomeTab { trending, vr, following, forYou }

/// Main home screen: vertical reels feed with interactions.
/// Default tab: For You. Tab switch is internal state only (no new route).
class HomeReelsScreen extends StatefulWidget {
  const HomeReelsScreen({super.key, this.isActive = true});

  /// Whether the Home tab is the currently visible bottom-nav tab.
  /// When false, reels should pause even if their page is selected.
  final bool isActive;

  @override
  State<HomeReelsScreen> createState() => _HomeReelsScreenState();
}

class _HomeReelsScreenState extends State<HomeReelsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final PageController _pageController = PageController();
  final ReelsController _reelsController = ReelsController();
  final ReelsService _reelsService = ReelsService();

  int _currentIndex = 0;
  HomeTab currentTab = HomeTab.forYou;
  bool _showControls = false;
  List<Map<String, dynamic>> _reelsForYou = [];
  List<Map<String, dynamic>> _reelsFollowing = [];
  List<Map<String, dynamic>> _reelsTrending = [];
  List<Map<String, dynamic>> _reelsVR = [];
  String? _selectedStoryId;

  /// Reels for current tab. Rebuilt when currentTab changes; PageView uses this.
  List<Map<String, dynamic>> get _currentReels {
    switch (currentTab) {
      case HomeTab.trending:
        return _reelsTrending;
      case HomeTab.vr:
        return _reelsVR;
      case HomeTab.following:
        return _reelsFollowing;
      case HomeTab.forYou:
        return _reelsForYou;
    }
  }

  // Mock data - HQ car reels style. Used as fallback until Firestore has reels.
  static List<Map<String, dynamic>> get _mockReels => [
    {
      'id': 'reel1',
      'videoUrl': 'https://assets.mixkit.co/videos/24481/24481-720.mp4',
      'username': 'supercar_daily',
      'handle': '@supercardaily',
      'caption': 'Sunday drive hits different 🏎️ #carreels #luxury #vyooo',
      'likes': 28400,
      'comments': 892,
      'saves': 1203,
      'views': 412000,
      'shares': 456,
      'avatarUrl': '',
    },
    {
      'id': 'reel2',
      'videoUrl':
          'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
      'username': 'luxury_rides',
      'handle': '@luxuryrides',
      'caption': 'POV: you finally got the keys 🔑 #carlife #newcar #vyooo',
      'likes': 15600,
      'comments': 234,
      'saves': 567,
      'views': 198000,
      'shares': 189,
      'avatarUrl': '',
    },
    {
      'id': 'reel3',
      'videoUrl':
          'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      'username': 'street_garage',
      'handle': '@streetgarage',
      'caption': 'Build not bought 💪 #carmods #carreels #vyooo',
      'likes': 42100,
      'comments': 1204,
      'saves': 2100,
      'views': 890000,
      'shares': 678,
      'avatarUrl': '',
    },
    {
      'id': 'reel4',
      'videoUrl': 'https://assets.mixkit.co/videos/24481/24481-720.mp4',
      'username': 'night_drives',
      'handle': '@nightdrives',
      'caption':
          'City lights & good vibes only 🌃 #nightdrive #carreels #vyooo',
      'likes': 33800,
      'comments': 567,
      'saves': 890,
      'views': 521000,
      'shares': 312,
      'avatarUrl': '',
    },
  ];

  // State for likes/saves (optimistic UI)
  final Map<String, bool> _likedReels = {};
  final Map<String, bool> _savedReels = {};

  // Playback and quality (from three-dots menu)
  String _playbackSpeedId = '1';
  String _playbackSpeedLabel = '1x (Normal)';
  String _qualityId = 'auto';
  String _qualityLabel = 'Auto (1080p HD)';

  @override
  void initState() {
    super.initState();
    _reelsForYou = _mockReels;
    _reelsFollowing = _mockReels;
    _reelsTrending = _mockReels;
    _reelsVR = _mockReels;
    _loadReels();
  }

  Future<void> _loadReels() async {
    final forYou = await _reelsService.getReelsForYou();
    final following = await _reelsService.getReelsFollowing();
    final trending = await _reelsService.getReelsTrending();
    final vr = await _reelsService.getReelsVR();
    if (mounted) {
      setState(() {
        if (forYou.isNotEmpty) _reelsForYou = forYou;
        if (following.isNotEmpty) _reelsFollowing = following;
        if (trending.isNotEmpty) _reelsTrending = trending;
        if (vr.isNotEmpty) _reelsVR = vr;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    if (index < _currentReels.length) {
      _reelsController.incrementView(
        reelId: _currentReels[index]['id'] as String,
      );
    }
  }

  Future<void> _onLike(String reelId, bool currentlyLiked) async {
    final newState = await _reelsController.likeReel(
      reelId: reelId,
      currentlyLiked: currentlyLiked,
    );
    setState(() => _likedReels[reelId] = newState);
  }

  Future<void> _onSave(String reelId, bool currentlySaved) async {
    final newState = await _reelsController.saveReel(
      reelId: reelId,
      currentlySaved: currentlySaved,
    );
    setState(() => _savedReels[reelId] = newState);
  }

  void _onShare(String reelId) {
    final reel = _currentIndex < _currentReels.length
        ? _currentReels[_currentIndex]
        : null;
    showShareBottomSheet(
      context,
      reelId: reelId,
      authorName: reel?['username'] as String?,
      thumbnailUrl: reel?['thumbnailUrl'] as String?,
      onShareViaNative: () => _reelsController.shareReel(reelId: reelId),
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
    showCommentsBottomSheet(
      context,
      reelId: reelId,
      onReply: (_) => _showSnackBar('Reply'),
      onLike: (_) => _showSnackBar('Liked'),
      onViewReplies: (_) => _showSnackBar('View replies'),
    );
  }

  void _onTabChanged(HomeTab tab) {
    setState(() {
      currentTab = tab;
      _currentIndex = 0;
    });
    // PageView is only in the tree when tab != VR. Schedule jump after build.
    if (tab != HomeTab.vr) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && currentTab == tab && _pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      });
    }
  }

  void _onVideoTap() {
    setState(() => _showControls = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isVrTab = currentTab == HomeTab.vr;
    final isFollowing = currentTab == HomeTab.following;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: (isFollowing || isVrTab)
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF49113B), // Dark magenta
                    Color(0xFF000000),
                  ],
                )
              : null,
        ),
        child: Stack(
          children: [
            if (isVrTab)
              Positioned.fill(
                top: 110, // Just below header
                child: _buildVrContent(),
              )
            else
              Positioned.fill(
                top: isFollowing ? 220 : 0, // Push video down for stories
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isFollowing ? 8 : 0,
                    vertical: isFollowing ? 8 : 0,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isFollowing ? 24 : 0),
                    child: _buildReelsFeed(),
                  ),
                ),
              ),
            _buildHeader(),
            if (isFollowing) _buildStoryRow(),
            if (!isVrTab) ...[
              _buildInteractionButtons(),
              _buildBottomUserInfo(),
              if (_showControls) _buildControlsOverlay(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVrContent() {
    return Consumer<SubscriptionController>(
      builder: (context, subscriptionController, _) {
        if (!subscriptionController.hasVRAccess) {
          return const VrLockedView();
        }
        return const VrGridView();
      },
    );
  }

  Widget _buildStoryRow() {
    final stories = _reelsFollowing
        .take(8)
        .map(
          (r) => {
            'id': r['id'],
            'profileImage': r['avatarUrl'],
            'avatarUrl': r['avatarUrl'],
          },
        )
        .toList();
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: FollowingHeaderStories(
        stories: stories,
        selectedId: _selectedStoryId,
        onStoryTap: (id) => setState(() => _selectedStoryId = id),
      ),
    );
  }

  Widget _buildReelsFeed() {
    final reels = _currentReels;
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      onPageChanged: _onPageChanged,
      itemCount: reels.length,
      itemBuilder: (context, index) {
        final reel = reels[index];
        return GestureDetector(
          onTap: _onVideoTap,
          child: ReelItemWidget(
            videoUrl: reel['videoUrl'] as String,
            // Only play when this page is visible AND the home tab is active.
            isVisible: widget.isActive && index == _currentIndex,
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: AppFeedHeader(
          selectedIndex: currentTab.index,
          onTabSelected: (index) => _onTabChanged(HomeTab.values[index]),
        ),
      ),
    );
  }

  Widget _buildInteractionButtons() {
    if (_currentIndex >= _currentReels.length) return const SizedBox.shrink();
    final reel = _currentReels[_currentIndex];
    final reelId = reel['id'] as String;
    final isLiked = _likedReels[reelId] ?? false;
    final isSaved = _savedReels[reelId] ?? false;

    return Positioned(
      right: 12,
      bottom: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppInteractionButton(
            icon: Icons.visibility_outlined,
            count: _formatCount(reel['views'] as int),
          ),
          const SizedBox(height: 16),
          AppInteractionButton(
            icon: isLiked ? Icons.favorite : Icons.favorite_border,
            count: _formatCount(reel['likes'] as int),
            isActive: isLiked,
            activeColor: const Color(0xFFEF4444), // Accurate red/pink
            onTap: () => _onLike(reelId, isLiked),
          ),
          const SizedBox(height: 16),
          AppInteractionButton(
            icon: Icons.chat_bubble_outline,
            count: _formatCount(reel['comments'] as int),
            onTap: () => _onComment(reelId),
          ),
          const SizedBox(height: 16),
          AppInteractionButton(
            icon: isSaved ? Icons.star : Icons.star_border,
            count: _formatCount(reel['saves'] as int),
            isActive: isSaved,
            activeColor: const Color(0xFFFFD700), // Gold
            onTap: () => _onSave(reelId, isSaved),
          ),
          const SizedBox(height: 16),
          AppInteractionButton(
            icon: Icons.reply, // Share style icon
            count: _formatCount(reel['shares'] as int),
            onTap: () => _onShare(reelId),
          ),
          const SizedBox(height: 16),
          AppInteractionButton(
            icon: Icons.more_horiz,
            count: '',
            onTap: () => _onMoreOptions(reelId),
          ),
        ],
      ),
    );
  }

  void _onMoreOptions(String reelId) {
    final reel = _currentReels.firstWhere((r) => r['id'] == reelId);
    showReelMoreOptionsSheet(
      context,
      reelId: reelId,
      playbackSpeed: _playbackSpeedLabel,
      quality: _qualityLabel,
      onDownload: _onDownloadTapped,
      onReport: () => showReportSheet(
        context,
        username: reel['username'] as String,
        avatarUrl: reel['avatarUrl'] as String,
      ),
      onNotInterested: () => showNotInterestedSheet(context),
      onCaptions: () => _showSnackBar('Captions'),
      onPlaybackSpeed: _openPlaybackSpeedSheet,
      onQuality: _openVideoQualitySheet,
      onManagePreferences: () => showManageContentPreferencesSheet(context),
      onWhyThisPost: () => showWhySeeingThisSheet(context),
    );
  }

  void _onDownloadTapped() {
    final subscriptionController = context.read<SubscriptionController>();
    if (subscriptionController.isSubscriber ||
        subscriptionController.isCreator) {
      _showSnackBar('Download started');
    } else {
      showDownloadSubscriptionSheet(context);
    }
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
    if (_currentIndex >= _currentReels.length) return const SizedBox.shrink();
    final reel = _currentReels[_currentIndex];

    return Positioned(
      left: 16,
      right: 80,
      bottom: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.grey[800],
                  backgroundImage: (reel['avatarUrl'] as String).isNotEmpty
                      ? NetworkImage(reel['avatarUrl'] as String)
                      : null,
                  child: (reel['avatarUrl'] as String).isEmpty
                      ? const Icon(Icons.person, color: Colors.white, size: 24)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          reel['username'] as String,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.all(1),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 9,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      reel['handle'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            reel['caption'] as String,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              fontWeight: FontWeight.w400,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              // TODO: Expand caption
            },
            child: Text(
              'See More',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Page indicators
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              final isTarget = index == 0;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isTarget ? 10 : 6,
                height: 6,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: isTarget
                      ? Colors.white
                      : Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    final playing = _currentIndex < _currentReels.length && _isVideoPlaying();
    return Center(
      child: AnimatedOpacity(
        opacity: _showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _onVideoTap,
                child: Icon(
                  playing ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              Container(
                width: 1,
                height: 24,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: Colors.white.withOpacity(0.3),
              ),
              GestureDetector(
                onTap: () {
                  // TODO: Toggle mute
                },
                child: const Icon(
                  Icons.volume_off_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isVideoPlaying() {
    // Placeholder - check actual player state from ReelItemWidget if needed
    return true;
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
