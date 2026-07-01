import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/agora_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/live_chat_message_model.dart';
import '../../core/models/live_stream_model.dart';
import '../../core/services/agora_token_service.dart';
import '../../core/services/live_stream_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_padding.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_feed_header.dart';
import '../../core/widgets/app_feed_header_icon_button.dart';
import '../../core/widgets/app_feed_notification_button.dart';
import '../../core/widgets/feed_bottom_scrim.dart';
import '../../core/widgets/live_feed_comment_bar.dart';
import '../../core/widgets/live_feed_host_caption_row.dart';
import '../../core/widgets/app_network_avatar.dart';
import '../../core/navigation/home_feed_chrome_controller.dart';
import '../../core/widgets/app_bottom_navigation.dart';
import '../../core/wrappers/main_nav_wrapper.dart';
import '../notifications/notification_screen.dart';
import '../profile/user_profile_screen.dart';

/// Broadcast tab: vertical live feed — swipe between active streams.
/// Empty state when nobody is live.
class BroadcastLiveFeedScreen extends StatefulWidget {
  const BroadcastLiveFeedScreen({
    super.key,
    required this.isActive,
    this.chromeController,
  });

  final bool isActive;
  final HomeFeedChromeController? chromeController;

  @override
  State<BroadcastLiveFeedScreen> createState() => _BroadcastLiveFeedScreenState();
}

class _BroadcastLiveFeedScreenState extends State<BroadcastLiveFeedScreen> {
  final _liveService = LiveStreamService();
  final _tokenService = AgoraTokenService();
  final _pageController = PageController();
  final _chatCtrl = TextEditingController();

  List<LiveStreamModel> _streams = [];
  int _pageIndex = 0;
  bool _listReady = false;

  RtcEngine? _engine;
  bool _engineReady = false;
  bool _joining = false;
  String? _joinedStreamId;
  int _remoteUid = 0;
  bool _hostVideoAvailable = false;
  bool _hasJoined = false;

  StreamSubscription<List<LiveStreamModel>>? _streamsSub;
  StreamSubscription<LiveStreamModel?>? _streamDocSub;
  StreamSubscription<List<LiveChatMessageModel>>? _chatSub;
  StreamSubscription<bool>? _likeSub;
  LiveStreamModel? _liveDoc;
  List<LiveChatMessageModel> _chatMessages = [];
  bool _isLiked = false;
  bool _likeInFlight = false;
  bool _showHostCaption = true;
  double _streamProgress = 1.0;

  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _streamsSub = _liveService.liveStreams().listen(_onStreamsUpdated);
    widget.chromeController?.seekFraction.addListener(_onChromeSeek);
    if (widget.isActive) {
      unawaited(_ensureAgoraAndJoin());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyChromeProgressState();
    });
  }

  @override
  void didUpdateWidget(BroadcastLiveFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chromeController != widget.chromeController) {
      oldWidget.chromeController?.seekFraction.removeListener(_onChromeSeek);
      widget.chromeController?.seekFraction.addListener(_onChromeSeek);
    }
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        unawaited(_ensureAgoraAndJoin());
      } else {
        unawaited(_teardownAgora());
        _syncChromeProgressVisibility(hide: true);
      }
    } else {
      _applyChromeProgressState();
    }
  }

  @override
  void dispose() {
    widget.chromeController?.seekFraction.removeListener(_onChromeSeek);
    _syncChromeProgressVisibility(hide: true);
    _streamsSub?.cancel();
    _streamDocSub?.cancel();
    _chatSub?.cancel();
    _likeSub?.cancel();
    _chatCtrl.dispose();
    _pageController.dispose();
    _toastTimer?.cancel();
    unawaited(_teardownAgora());
    super.dispose();
  }

  HomeFeedChromeController? get _chrome => widget.chromeController;

  double _feedNavHeight(
    BuildContext context, {
    required bool includeProgressBand,
    bool liveProgressBand = false,
  }) =>
      AppBottomNavigation.totalHeightFor(
        context,
        feedChrome: true,
        includeReelProgressBand: includeProgressBand,
        liveProgressBand: liveProgressBand,
      );

  bool _showLiveProgressBar({required bool hostCaptionVisible}) =>
      widget.isActive &&
      _streams.isNotEmpty &&
      hostCaptionVisible;

  void _applyChromeProgressState() {
    _syncChromeProgressVisibility(
      hostCaptionVisible: _showHostCaption,
      progress: _streamProgress,
    );
  }

  void _syncChromeProgressVisibility({
    bool hide = false,
    bool hostCaptionVisible = true,
    double progress = 1.0,
  }) {
    final chrome = _chrome;
    if (chrome == null) return;
    if (hide || !_showLiveProgressBar(hostCaptionVisible: hostCaptionVisible)) {
      chrome.progress.value = null;
      chrome.seekFraction.value = null;
      return;
    }
    chrome.progress.value = progress;
  }

  void _onChromeSeek() {
    final fraction = _chrome?.seekFraction.value;
    if (fraction == null) return;
    final clamped = fraction.clamp(0.0, 1.0);
    if (clamped == _streamProgress) return;
    setState(() => _streamProgress = clamped);
  }

  void _onHostCaptionVisibilityChanged(bool visible) {
    setState(() => _showHostCaption = visible);
    _applyChromeProgressState();
  }

  double _feedShellBottomInset(
    BuildContext context, {
    required bool hostCaptionVisible,
  }) {
    final showProgress = _showLiveProgressBar(
      hostCaptionVisible: hostCaptionVisible,
    );
    return _feedNavHeight(
      context,
      includeProgressBand: showProgress,
      liveProgressBand: showProgress,
    );
  }

  /// Sits just above chrome; [AppBottomNavigation] draws on top in [MainNavWrapper].
  double _feedOverlayBottom(
    BuildContext context, {
    required bool hostCaptionVisible,
  }) {
    return _feedShellBottomInset(
      context,
      hostCaptionVisible: hostCaptionVisible,
    );
  }

  void _onStreamsUpdated(List<LiveStreamModel> streams) {
    if (!mounted) return;

    final previousId = _currentStream?.id;
    setState(() {
      _streams = streams;
      _listReady = true;
      if (_pageIndex >= streams.length) {
        _pageIndex = streams.isEmpty ? 0 : streams.length - 1;
      }
    });

    if (streams.isEmpty) {
      unawaited(_teardownAgora());
      _syncChromeProgressVisibility(hide: true);
      return;
    }

    if (previousId != null && !streams.any((s) => s.id == previousId)) {
      if (_pageController.hasClients) {
        final target = _pageIndex.clamp(0, streams.length - 1);
        _pageController.jumpToPage(target);
      }
      if (widget.isActive) {
        unawaited(_joinStreamAtIndex(_pageIndex));
      }
      return;
    }

    if (widget.isActive && _joinedStreamId == null && !_joining) {
      unawaited(_joinStreamAtIndex(_pageIndex));
    }
    _applyChromeProgressState();
  }

  LiveStreamModel? get _currentStream {
    if (_streams.isEmpty || _pageIndex < 0 || _pageIndex >= _streams.length) {
      return null;
    }
    return _streams[_pageIndex];
  }

  Future<void> _ensureAgoraAndJoin() async {
    if (!widget.isActive || _streams.isEmpty) return;
    if (_engine == null) {
      await _initAgora();
    }
    await _joinStreamAtIndex(_pageIndex);
  }

  Future<void> _initAgora() async {
    if (_engine != null) return;
    final engine = createAgoraRtcEngine();
    await engine.initialize(
      RtcEngineContext(
        appId: AgoraConfig.appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) async {
          _hasJoined = true;
          final stream = _currentStream;
          if (stream == null) return;
          await _liveService.viewerJoined(stream.id).catchError((_) {});
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final profile =
                await _liveService.resolveChatSenderProfile(user.uid);
            await _liveService
                .sendMessage(
                  streamId: stream.id,
                  userId: user.uid,
                  username: profile.username,
                  profileImage: profile.profileImage,
                  message: '${profile.username} joined the stream 👋',
                  type: ChatMessageType.join,
                )
                .catchError((_) {});
          }
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          if (!mounted) return;
          setState(() {
            _remoteUid = remoteUid;
            _hostVideoAvailable = true;
          });
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (!mounted) return;
          if (remoteUid == _remoteUid) {
            setState(() {
              _hostVideoAvailable = false;
              _remoteUid = 0;
            });
          }
        },
        onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
          if (!mounted) return;
          if (remoteUid != _remoteUid) return;
          final hasVideo =
              state == RemoteVideoState.remoteVideoStateDecoding ||
              state == RemoteVideoState.remoteVideoStateStarting;
          setState(() => _hostVideoAvailable = hasVideo);
        },
        onTokenPrivilegeWillExpire: (connection, token) async {
          final stream = _currentStream;
          if (stream == null || _engine == null) return;
          try {
            final newToken = await _tokenService.renewToken(
              channelName: stream.agoraChannelName,
              uid: 0,
              isHost: false,
            );
            await _engine!.renewToken(newToken);
          } catch (_) {
            _showToast('Connection may disconnect soon');
          }
        },
        onError: (err, msg) {
          if (!mounted) return;
          _showToast('Connection error');
        },
      ),
    );

    await engine.setClientRole(role: ClientRoleType.clientRoleAudience);
    await engine.enableVideo();
    await engine.enableAudio();

    if (!mounted) return;
    setState(() {
      _engine = engine;
      _engineReady = true;
    });
  }

  Future<void> _teardownAgora() async {
    await _leaveCurrentStream();
    final engine = _engine;
    _engine = null;
    if (engine != null) {
      try {
        await engine.release();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _engineReady = false;
      _remoteUid = 0;
      _hostVideoAvailable = false;
      _hasJoined = false;
      _joinedStreamId = null;
      _liveDoc = null;
      _chatMessages = [];
    });
  }

  Future<void> _leaveCurrentStream() async {
    _streamDocSub?.cancel();
    _streamDocSub = null;
    _chatSub?.cancel();
    _chatSub = null;
    _likeSub?.cancel();
    _likeSub = null;

    final streamId = _joinedStreamId;
    final engine = _engine;
    if (streamId == null || engine == null || !_engineReady) {
      _joinedStreamId = null;
      _hasJoined = false;
      return;
    }

    if (_hasJoined) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final name =
            user.displayName ?? user.email?.split('@').first ?? 'Viewer';
        await _liveService
            .sendMessage(
              streamId: streamId,
              userId: user.uid,
              username: name,
              message: '$name left the stream',
              type: ChatMessageType.system,
            )
            .catchError((_) {});
      }
      await _liveService.viewerLeft(streamId).catchError((_) {});
      try {
        await engine.leaveChannel();
      } catch (_) {}
    }

    _joinedStreamId = null;
    _hasJoined = false;
    if (mounted) {
      setState(() {
        _remoteUid = 0;
        _hostVideoAvailable = false;
        _isLiked = false;
      });
    }
  }

  Future<void> _joinStreamAtIndex(int index) async {
    if (!widget.isActive || _streams.isEmpty) return;
    if (index < 0 || index >= _streams.length) return;

    final stream = _streams[index];
    if (_joinedStreamId == stream.id) return;
    if (_joining) return;

    _joining = true;
    try {
      if (_engine == null) {
        await _initAgora();
      }
      final engine = _engine;
      if (engine == null || !mounted) return;

      await _leaveCurrentStream();

      final token = await _tokenService.getToken(
        channelName: stream.agoraChannelName,
        uid: 0,
        isHost: false,
      );

      await engine.joinChannel(
        token: token,
        channelId: stream.agoraChannelName,
        uid: 0,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleAudience,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );

      if (!mounted) return;
      setState(() {
        _joinedStreamId = stream.id;
        _liveDoc = stream;
        _chatMessages = [];
      });

      _streamDocSub = _liveService.streamDoc(stream.id).listen((doc) {
        if (!mounted || doc == null) return;
        setState(() => _liveDoc = doc);
        if (doc.status == LiveStreamStatus.ended) {
          _showToast('Stream has ended');
        }
      });

      _chatSub = _liveService.chatMessages(stream.id).listen((msgs) {
        if (!mounted) return;
        setState(() => _chatMessages = msgs);
      });

      _likeSub?.cancel();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        _likeSub = _liveService.userLikedStream(stream.id, uid).listen((liked) {
          if (!mounted || _joinedStreamId != stream.id) return;
          setState(() => _isLiked = liked);
        });
      } else {
        _isLiked = false;
      }
    } catch (_) {
      _showToast('Could not join stream');
    } finally {
      _joining = false;
    }
  }

  void _onPageChanged(int index) {
    if (_pageIndex == index) return;
    setState(() {
      _pageIndex = index;
      _streamProgress = 1.0;
    });
    _chatCtrl.clear();
    _applyChromeProgressState();
    unawaited(_joinStreamAtIndex(index));
  }

  Future<void> _sendMessage() async {
    final stream = _currentStream;
    final text = _chatCtrl.text.trim();
    if (stream == null || text.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _chatCtrl.clear();
    try {
      final profile = await _liveService.resolveChatSenderProfile(user.uid);
      await _liveService.sendMessage(
        streamId: stream.id,
        userId: user.uid,
        username: profile.username,
        profileImage: profile.profileImage,
        message: text,
      );
    } catch (_) {
      _showToast('Failed to send');
    }
  }

  Future<void> _sendLike() async {
    final stream = _currentStream;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (stream == null) return;
    if (uid == null) {
      _showToast('Sign in to like');
      return;
    }
    if (_likeInFlight) return;

    final wantLiked = !_isLiked;
    _likeInFlight = true;
    setState(() => _isLiked = wantLiked);

    try {
      final actual = await _liveService.toggleLike(
        streamId: stream.id,
        userId: uid,
        wantLiked: wantLiked,
      );
      if (!mounted) return;
      if (actual != wantLiked) {
        setState(() => _isLiked = actual);
      }
    } catch (_) {
      if (mounted) setState(() => _isLiked = !wantLiked);
      _showToast('Could not update like');
    } finally {
      _likeInFlight = false;
    }
  }

  Future<void> _shareStream(LiveStreamModel doc) async {
    final title = doc.title.trim().isEmpty ? 'Live on VyooO' : doc.title.trim();
    final body =
        doc.description.trim().isNotEmpty ? doc.description.trim() : title;
    await SharePlus.instance.share(
      ShareParams(text: 'Watch this live stream on VyooO: $body'),
    );
  }

  void _showToast(String msg) {
    setState(() => _toast = msg);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_listReady) {
      return const ColoredBox(
        color: Color(0xFF0A000F),
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_streams.isEmpty) {
      return _buildEmptyState(context);
    }

    final doc = _liveDoc ?? _currentStream!;
    final shellBottomInset = _feedShellBottomInset(
      context,
      hostCaptionVisible: _showHostCaption,
    );
    final overlayBottom = _feedOverlayBottom(
      context,
      hostCaptionVisible: _showHostCaption,
    );

    return ColoredBox(
      color: AppColors.feedBottomChrome,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: shellBottomInset,
            child: const ColoredBox(color: AppColors.feedBottomChrome),
          ),
          Positioned.fill(
            bottom: shellBottomInset,
            child: _buildFeedClipArea(
              Stack(
                fit: StackFit.expand,
                children: [
                  _buildVideoLayer(doc),
                  _buildGradientOverlay(),
                  const FeedBottomScrim(clipBottomCorners: false),
                  PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    itemCount: _streams.length,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, index) => const SizedBox.expand(),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: overlayBottom,
            child: _BroadcastFeedPageOverlay(
              stream: doc,
              chatMessages: _chatMessages,
              isLiked: _isLiked,
              chatController: _chatCtrl,
              streamProgress: _streamProgress,
              showHostCaption: _showHostCaption,
              onHostCaptionVisibilityChanged: _onHostCaptionVisibilityChanged,
              onSendMessage: _sendMessage,
              onLike: _sendLike,
              onShare: () => _shareStream(doc),
              onHostTap: () {
                final stream = _currentStream;
                if (stream == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => UserProfileScreen(
                      payload: UserProfilePayload(
                        targetUserId: stream.hostId,
                        username: stream.hostUsername,
                        displayName: stream.hostUsername,
                        avatarUrl: stream.hostProfileImage ?? '',
                        followerCount: 0,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: _buildHeader(context),
            ),
          ),
          if (!_engineReady || _joining)
            Positioned.fill(
              bottom: shellBottomInset,
              child: ColoredBox(
                color: const Color(0x880A000F),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
          if (_toast != null) _buildToast(_toast!),
        ],
      ),
    );
  }

  /// Same rounded bottom edge as home reel feed (`feedPostBottomRadius`).
  Widget _buildFeedClipArea(Widget child) {
    return ColoredBox(
      color: Colors.black,
      child: child,
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final shellBottomInset = _feedShellBottomInset(
      context,
      hostCaptionVisible: false,
    );

    return ColoredBox(
      color: AppColors.feedBottomChrome,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: shellBottomInset,
            child: const ColoredBox(color: AppColors.feedBottomChrome),
          ),
          Positioned.fill(
            bottom: shellBottomInset,
            child: _buildFeedClipArea(
              const ColoredBox(color: Color(0xFF0A000F)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                const Spacer(),
                Padding(
                  padding: AppPadding.screenHorizontal,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sensors_rounded,
                        size: 56,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'No live streaming happened',
                        textAlign: TextAlign.center,
                        style: AppTypography.feedReelDisplayName.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'When someone goes live, their stream will appear here.',
                        textAlign: TextAlign.center,
                        style: AppTypography.feedReelHandle.copyWith(
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                SizedBox(height: shellBottomInset),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return AppFeedLogoBar(
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppFeedHeaderIconButton.search(
            onTap: () => MainNavWrapper.openSearchTab(),
          ),
          SizedBox(width: AppSpacing.xs),
          StreamBuilder<int>(
            stream: NotificationService().watchUnreadCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              final showBadge = count > 0;
              final label = count > 99 ? '99+' : '$count';
              return AppFeedNotificationButton(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationScreen(),
                    ),
                  );
                },
                badge: showBadge
                    ? Container(
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF2D55),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: const Color(0xFF14001F),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : null,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVideoLayer(LiveStreamModel doc) {
    final engine = _engine;
    if (!_engineReady ||
        engine == null ||
        !_hostVideoAvailable ||
        _remoteUid == 0) {
      return _buildVideoPlaceholder(doc);
    }
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: engine,
        canvas: VideoCanvas(uid: _remoteUid),
        connection: RtcConnection(channelId: doc.agoraChannelName),
      ),
    );
  }

  Widget _buildVideoPlaceholder(LiveStreamModel doc) {
    return ColoredBox(
      color: const Color(0xFF0A000F),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              backgroundImage: doc.hostProfileImage?.isNotEmpty == true
                  ? NetworkImage(doc.hostProfileImage!)
                  : null,
              child: doc.hostProfileImage?.isNotEmpty != true
                  ? Text(
                      doc.hostUsername.isNotEmpty
                          ? doc.hostUsername[0].toUpperCase()
                          : '?',
                      style: AppTypography.feedReelDisplayName.copyWith(
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              doc.hostUsername,
              style: AppTypography.feedReelUsername.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Connecting to stream...',
              style: AppTypography.feedReelHandle.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.5),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToast(String msg) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          msg,
          style: AppTypography.feedReelUsername.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _BroadcastFeedPageOverlay extends StatelessWidget {
  const _BroadcastFeedPageOverlay({
    required this.stream,
    required this.chatMessages,
    required this.isLiked,
    required this.chatController,
    required this.streamProgress,
    required this.showHostCaption,
    required this.onHostCaptionVisibilityChanged,
    required this.onSendMessage,
    required this.onLike,
    required this.onShare,
    required this.onHostTap,
  });

  final LiveStreamModel stream;
  final List<LiveChatMessageModel> chatMessages;
  final bool isLiked;
  final TextEditingController chatController;
  final double streamProgress;
  final bool showHostCaption;
  final ValueChanged<bool> onHostCaptionVisibilityChanged;
  final VoidCallback onSendMessage;
  final VoidCallback onLike;
  final VoidCallback onShare;
  final VoidCallback onHostTap;

  Duration _streamElapsed(LiveStreamModel stream) {
    final started = stream.createdAt.toDate();
    final elapsed = DateTime.now().difference(started);
    if (elapsed.isNegative) return Duration.zero;
    return elapsed;
  }

  List<LiveChatMessageModel> _previewChatMessages(
    LiveStreamModel stream,
    List<LiveChatMessageModel> messages,
  ) {
    if (streamProgress >= 0.99) return messages;
    final elapsedMs = _streamElapsed(stream).inMilliseconds;
    if (elapsedMs <= 0) return messages;

    final started = stream.createdAt.toDate();
    final cutoff = started.add(
      Duration(milliseconds: (elapsedMs * streamProgress).round()),
    );
    return messages
        .where((m) => !m.createdAt.toDate().isAfter(cutoff))
        .toList();
  }

  String _caption(LiveStreamModel stream) {
    final desc = stream.description.trim();
    if (desc.isNotEmpty) return desc;
    final title = stream.title.trim();
    if (title.isNotEmpty && title.toLowerCase() != 'live stream') {
      return title;
    }
    return 'Watch live with ${stream.hostUsername}';
  }

  @override
  Widget build(BuildContext context) {
    final previewMessages = _previewChatMessages(stream, chatMessages);
    final chatToCommentGap = AppSizes.liveFeedScaleH(
      context,
      AppSpacing.liveFeedOverlayChatToCommentGap,
    );
    final commentToCaptionGap = AppSizes.liveFeedScaleH(
      context,
      AppSpacing.liveFeedOverlayCommentToCaptionGap,
    );
    final hostToProgressGap = AppSizes.liveFeedScaleH(
      context,
      AppSizes.liveFeedHostToProgressGap,
    );

    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: AppPadding.liveFeedOverlayContentOf(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (chatMessages.isNotEmpty) ...[
              _ChatOverlay(messages: previewMessages),
              SizedBox(height: chatToCommentGap),
            ],
            LiveFeedCommentBar(
              controller: chatController,
              likeCount: stream.likeCount,
              isLiked: isLiked,
              onSendMessage: onSendMessage,
              onLike: onLike,
              onShare: onShare,
              hostCaptionVisible: showHostCaption,
              onChevronTap: () {
                onHostCaptionVisibilityChanged(!showHostCaption);
              },
            ),
            if (showHostCaption) ...[
              SizedBox(height: commentToCaptionGap),
              LiveFeedHostCaptionRow(
                avatarUrl: stream.hostProfileImage,
                hostInitial: stream.hostUsername,
                caption: _caption(stream),
                onTap: onHostTap,
              ),
              SizedBox(height: hostToProgressGap),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatOverlay extends StatelessWidget {
  const _ChatOverlay({required this.messages});

  final List<LiveChatMessageModel> messages;

  static double _maxChatHeight(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    return screenH * 0.32;
  }

  @override
  Widget build(BuildContext context) {
    final visible = messages
        .where(
          (m) =>
              m.type != ChatMessageType.system &&
              m.type != ChatMessageType.join,
        )
        .toList();

    if (visible.isEmpty) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: _maxChatHeight(context)),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        reverse: true,
        shrinkWrap: true,
        physics: visible.length > 4
            ? const ClampingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        itemCount: visible.length,
        itemBuilder: (context, i) {
          final m = visible[visible.length - 1 - i];
          return _LiveChatMessageCard(message: m);
        },
      ),
    );
  }
}

/// Figma live-feed chat row — min 54px; grows for full message text.
class _LiveChatMessageCard extends StatelessWidget {
  const _LiveChatMessageCard({required this.message});

  final LiveChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppSizes.liveChatCardHeight,
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: AppSizes.liveChatCardContentTopInset,
              ),
              child: Opacity(
                opacity: 0.5,
                child: _ChatAvatar(message: message),
              ),
            ),
            const SizedBox(width: AppSizes.liveChatAvatarToTextGap),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: AppSizes.liveChatCardContentTopInset,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.liveChatUsername,
                    ),
                    const SizedBox(
                      height: AppSizes.liveChatUsernameMessageGap,
                    ),
                    Text(
                      message.message,
                      style: AppTypography.liveChatMessage,
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
}

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({required this.message});

  final LiveChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final image = message.profileImage?.trim() ?? '';
    return ClipOval(
      child: SizedBox(
        width: AppSizes.liveChatAvatarSize,
        height: AppSizes.liveChatAvatarSize,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image.isNotEmpty)
              AppNetworkAvatar(
                imageUrl: image,
                userId: message.userId,
                size: AppSizes.liveChatAvatarSize,
                fallback: _fallback(),
              )
            else
              _fallback(),
            ColoredBox(color: Colors.black.withValues(alpha: 0.2)),
          ],
        ),
      ),
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: Colors.white.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          message.username.isNotEmpty
              ? message.username[0].toUpperCase()
              : '?',
          style: AppTypography.liveChatUsername.copyWith(
            fontSize: 10,
            height: 1,
          ),
        ),
      ),
    );
  }
}
