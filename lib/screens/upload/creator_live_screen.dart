import 'dart:async';
import 'dart:io' show Platform;

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vyooo/core/widgets/app_gradient_background.dart';

import '../../core/config/agora_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/live_stream_assets.dart';
import '../../core/models/live_chat_message_model.dart';
import '../../core/models/live_stream_model.dart';
import '../../core/services/agora_token_service.dart';
import '../../core/services/live_stream_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_bottom_navigation.dart';
import '../../core/widgets/app_feed_header.dart';
import '../../core/widgets/app_feed_header_icon_button.dart';
import '../../core/widgets/app_feed_notification_button.dart';
import '../../core/widgets/live_comment_input_field.dart';
import '../../core/wrappers/main_nav_wrapper.dart';
import '../../features/story/story_upload_screen.dart';
import '../../screens/notifications/notification_screen.dart';
import 'upload_screen.dart';
import 'widgets/upload_create_bottom_bar.dart';

// ── State enum ─────────────────────────────────────────────────────────────────

enum _LiveState { initializing, permissionDenied, offline, countdown, live }

/// iOS needs extra time after removing [AgoraVideoView] before creating a new one.
const Duration _kIosPlatformViewSettleDelay = Duration(milliseconds: 400);

// ── Screen ─────────────────────────────────────────────────────────────────────

/// Creator live streaming screen.
/// Handles camera preview → countdown → live broadcast with Agora + Firebase.
class CreatorLiveScreen extends StatefulWidget {
  const CreatorLiveScreen({
    super.key,
    this.autoStartLive = false,
    this.embeddedInMainShell = false,
    this.isActive = true,
    this.shellBottomInset = AppBottomNavigation.barHeight,
    this.onShellExit,
    this.onOverlayRouteChanged,
  });

  /// When true, starts the go-live countdown once camera preview is ready.
  final bool autoStartLive;

  /// Embedded under [MainNavWrapper] broadcast tab — standard bottom nav stays visible.
  final bool embeddedInMainShell;

  /// Whether the broadcast tab is the active shell tab (pauses preview when false).
  final bool isActive;

  /// Space reserved for the main-shell bottom nav overlay.
  final double shellBottomInset;

  /// Called instead of [Navigator.pop] when [embeddedInMainShell] is true.
  final VoidCallback? onShellExit;

  /// Settings / other routes pushed above live — host keeps this widget mounted.
  final ValueChanged<bool>? onOverlayRouteChanged;

  @override
  State<CreatorLiveScreen> createState() => _CreatorLiveScreenState();
}

class _CreatorLiveScreenState extends State<CreatorLiveScreen>
    with WidgetsBindingObserver {
  // ── Agora ────────────────────────────────────────────────────────────────────
  RtcEngine? _engine;
  bool _engineReady = false;
  bool _showAgoraView = false;
  bool _agoraTornDown = false;
  bool _initializingAgora = false;
  bool _teardownInProgress = false;
  bool _appBackgrounded = false;
  bool _overlayRouteOpen = false;
  int _localUid = 0;
  int _engineVersion =
      0; // incremented on each init — forces AgoraVideoView to rebuild

  // ── State ─────────────────────────────────────────────────────────────────────
  _LiveState _liveState = _LiveState.initializing;
  int _countdown = 3;
  Timer? _countdownTimer;
  Timer? _heartbeatTimer;

  // ── Controls ──────────────────────────────────────────────────────────────────
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isCommentsOff = false;
  bool _isFrontCamera = true;
  bool _streamInfoExpanded = true;

  // ── Toast ─────────────────────────────────────────────────────────────────────
  String? _toast;
  Timer? _toastTimer;

  // ── Firebase ──────────────────────────────────────────────────────────────────
  final _liveService = LiveStreamService();
  final _tokenService = AgoraTokenService();
  final _userService = UserService();
  String? _streamId;
  LiveStreamModel? _streamDoc;
  StreamSubscription<LiveStreamModel?>? _streamSub;
  StreamSubscription<List<LiveChatMessageModel>>? _chatSub;
  StreamSubscription<bool>? _likeSub;
  List<LiveChatMessageModel> _chatMessages = [];
  bool _isLiked = false;
  bool _likeInFlight = false;

  // ── Settings ──────────────────────────────────────────────────────────────────
  String _streamTitle = '';
  String _streamDescription = '';
  String _streamCategory = '';
  List<String> _streamTags = [];
  int _streamPrice = 0;

  // ── Chat input ─────────────────────────────────────────────────────────────────
  final _chatCtrl = TextEditingController();
  final _chatScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!widget.embeddedInMainShell || widget.isActive) {
      unawaited(_init());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        unawaited(_handleAppBackgrounded());
      case AppLifecycleState.resumed:
        unawaited(_handleAppResumed());
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  void didUpdateWidget(CreatorLiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.embeddedInMainShell) return;
    if (!oldWidget.isActive && widget.isActive && (_agoraTornDown || !_engineReady)) {
      unawaited(_init());
      return;
    }
    if (oldWidget.isActive != widget.isActive) {
      unawaited(_handleShellActiveChanged(widget.isActive));
    }
  }

  void _exitLiveScreen() {
    if (widget.embeddedInMainShell) {
      widget.onShellExit?.call();
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _handleShellActiveChanged(bool active) async {
    if (!widget.embeddedInMainShell) return;
    if (_overlayRouteOpen) return;
    if (!active) {
      if (_liveState == _LiveState.countdown) {
        _cancelCountdown();
      }
      await _detachAgoraPlatformView();
      if (_liveState == _LiveState.offline && _engineReady && _engine != null) {
        try {
          await _engine!.stopPreview();
        } catch (_) {}
      }
      return;
    }
    if (_agoraTornDown) {
      await _init();
      return;
    }
    if (_engineReady && !_showAgoraView && mounted) {
      setState(() => _showAgoraView = true);
      await _waitForPlatformViewRelease();
    }
    if (_liveState == _LiveState.offline && _engineReady && _engine != null) {
      try {
        await _engine!.startPreview();
      } catch (_) {}
    }
  }

  Future<void> _waitForPlatformViewRelease() async {
    await WidgetsBinding.instance.endOfFrame;
    if (Platform.isIOS) {
      await Future<void>.delayed(_kIosPlatformViewSettleDelay);
    }
  }

  Future<void> _detachAgoraPlatformView() async {
    if (!_showAgoraView) return;
    if (mounted) {
      setState(() => _showAgoraView = false);
    } else {
      _showAgoraView = false;
    }
    await _waitForPlatformViewRelease();
  }

  Future<void> _handleAppBackgrounded() async {
    if (_overlayRouteOpen || _appBackgrounded || _teardownInProgress) return;
    _appBackgrounded = true;
    final wasLive = _liveState == _LiveState.live;
    _countdownTimer?.cancel();
    _heartbeatTimer?.cancel();
    if (wasLive && _streamId != null) {
      await _liveService.endStream(_streamId!).catchError((_) {});
    }
    await _teardownAgora(endLiveStream: false);
    if (!mounted) return;
    setState(() {
      _liveState = _LiveState.offline;
      _streamId = null;
      _streamDoc = null;
      _chatMessages = [];
    });
    _streamSub?.cancel();
    _chatSub?.cancel();
    _likeSub?.cancel();
    _likeSub?.cancel();
    _streamSub = null;
    _chatSub = null;
    _likeSub = null;
  }

  Future<void> _handleAppResumed() async {
    if (_overlayRouteOpen) return;
    if (!_appBackgrounded) return;
    _appBackgrounded = false;
    if (!mounted) return;
    if (widget.embeddedInMainShell && !widget.isActive) return;
    if (Platform.isIOS) {
      await Future<void>.delayed(_kIosPlatformViewSettleDelay);
    }
    if (!mounted) return;
    if (_agoraTornDown || !_engineReady) {
      await _init();
    }
  }

  Future<void> _resetToOfflineAfterStream() async {
    _heartbeatTimer?.cancel();
    _streamSub?.cancel();
    _chatSub?.cancel();
    _likeSub?.cancel();
    _likeSub?.cancel();
    _streamSub = null;
    _chatSub = null;
    _likeSub = null;
    _streamId = null;
    _streamDoc = null;
    _chatMessages = [];
    _isLiked = false;
    if (_engineReady && _engine != null) {
      if (!_showAgoraView && mounted) {
        setState(() => _showAgoraView = true);
        await _waitForPlatformViewRelease();
      }
      try {
        await _engine!.startPreview();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _liveState = _LiveState.offline);
  }

  Widget _buildBottomBar() {
    if (widget.embeddedInMainShell) {
      return SizedBox(height: widget.shellBottomInset);
    }
    return _createHubBottomBar();
  }

  double get _shellLogoBarTopInset =>
      widget.embeddedInMainShell ? AppFeedLogoBar.layoutHeight() : 0;

  Widget _buildShellTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: AppFeedLogoBar(trailing: _buildShellHeaderActions()),
      ),
    );
  }

  Widget _buildShellHeaderActions() {
    return Row(
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
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _heartbeatTimer?.cancel();
    _toastTimer?.cancel();
    _streamSub?.cancel();
    _chatSub?.cancel();
    _likeSub?.cancel();
    _chatCtrl.dispose();
    _chatScrollCtrl.dispose();
    _showAgoraView = false;
    _engineReady = false;
    unawaited(_teardownAgora(endLiveStream: true));
    super.dispose();
  }

  Future<void> _teardownAgora({required bool endLiveStream}) async {
    if (_teardownInProgress) return;
    _teardownInProgress = true;
    try {
      if (endLiveStream &&
          _streamId != null &&
          _liveState == _LiveState.live) {
        await _liveService.endStream(_streamId!).catchError((_) {});
      }

      final engine = _engine;
      final hadEngine = _engineReady && engine != null;
      await _detachAgoraPlatformView();
      _engineReady = false;

      if (hadEngine) {
        try {
          await engine.stopPreview();
        } catch (_) {}
        try {
          await engine.leaveChannel();
        } catch (_) {}
        try {
          await engine.release();
        } catch (_) {}
      }
      _engine = null;
      _agoraTornDown = true;
      _engineVersion++;
      if (Platform.isIOS) {
        await Future<void>.delayed(_kIosPlatformViewSettleDelay);
      }
    } finally {
      _teardownInProgress = false;
    }
  }

  // ── Init ──────────────────────────────────────────────────────────────────────

  Future<void> _init() async {
    if (_initializingAgora) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _liveService.endStaleLiveStreamsForHost(uid);
    }
    if (!mounted) return;

    final granted = await _requestPermissions();
    if (!mounted) return;
    if (!granted) {
      setState(() => _liveState = _LiveState.permissionDenied);
      return;
    }
    await _initAgora();
  }

  Future<bool> _requestPermissions() async {
    final statuses = await [Permission.camera, Permission.microphone].request();
    return statuses[Permission.camera]!.isGranted &&
        statuses[Permission.microphone]!.isGranted;
  }

  Future<void> _initAgora() async {
    if (_initializingAgora) return;
    _initializingAgora = true;
    try {
      if (_engine != null) {
        await _teardownAgora(endLiveStream: false);
      }
      final engine = createAgoraRtcEngine();
      _engine = engine;
      await engine.initialize(
      RtcEngineContext(
        appId: AgoraConfig.appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          if (!mounted) return;
          setState(() => _localUid = connection.localUid ?? 0);
          if (_streamId != null) {
            _liveService.updateHostAgoraUid(_streamId!, _localUid);
          }
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          if (_streamId == null) return;
          _liveService
              .sendMessage(
                streamId: _streamId!,
                userId: 'system',
                username: 'system',
                message: 'Someone joined the stream 👋',
                type: ChatMessageType.join,
              )
              .catchError((_) {});
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (_streamId == null) return;
          _liveService
              .sendMessage(
                streamId: _streamId!,
                userId: 'system',
                username: 'system',
                message: 'A viewer left the stream',
                type: ChatMessageType.system,
              )
              .catchError((_) {});
        },
        onTokenPrivilegeWillExpire: (connection, token) async {
          if (_streamId == null) return;
          try {
            final newToken = await _tokenService.renewToken(
              channelName: _streamId!,
              uid: _localUid,
              isHost: true,
            );
            await engine.renewToken(newToken);
          } catch (_) {
            _showToast('Token renewal failed — stream may disconnect');
          }
        },
        onError: (err, msg) {
          if (!mounted) return;
          _showToast('Stream error: $msg');
        },
      ),
    );

    await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await engine.enableVideo();
    await engine.enableAudio();
    await engine.startPreview();

    if (!mounted) return;
    if (Platform.isIOS) {
      await Future<void>.delayed(_kIosPlatformViewSettleDelay);
    }
    if (!mounted) return;
    setState(() {
      _engineReady = true;
      _showAgoraView = true;
      _agoraTornDown = false;
      _engineVersion++;
      _liveState = _LiveState.offline;
    });
    if (widget.autoStartLive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onLiveStartTap();
      });
    }
    } finally {
      _initializingAgora = false;
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────────

  /// Shared entry for **Start Live** and the bottom-bar **Live** segment.
  Future<void> _onLiveStartTap() async {
    if (_liveState != _LiveState.offline) return;

    final start = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (_) => const _ConfirmDialog(
        message: 'Do you want to start your live stream?',
        confirmLabel: 'Yes, Go Live',
      ),
    );
    if (start != true || !mounted) return;

    _startCountdown();
  }

  void _startCountdown() {
    setState(() {
      _liveState = _LiveState.countdown;
      _countdown = 3;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_countdown <= 1) {
        t.cancel();
        await _goLive();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    setState(() => _liveState = _LiveState.offline);
  }

  Future<void> _goLive() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showToast('Not signed in');
      setState(() => _liveState = _LiveState.offline);
      return;
    }

    try {
      // Load user profile for display name
      final profile = await _userService.getUser(user.uid);
      final username =
          profile?.username ?? user.email?.split('@').first ?? 'Host';
      final profileImage = profile?.profileImage;

      // Create Firestore document — channel name = doc ID
      final streamId = await _liveService.createStream(
        hostId: user.uid,
        hostUsername: username,
        hostProfileImage: profileImage,
        title: _streamTitle.isEmpty ? 'Live Stream' : _streamTitle,
        description: _streamDescription,
        category: _streamCategory,
        tags: _streamTags,
        pricePerMinute: _streamPrice,
      );
      _streamId = streamId;

      // Fetch a signed token from the Cloud Function
      final token = await _tokenService.getToken(
        channelName: streamId,
        uid: 0,
        isHost: true,
      );

      // Join Agora channel as broadcaster
      await _engine!.joinChannel(
        token: token,
        channelId: streamId,
        uid: 0,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: false,
          autoSubscribeVideo: false,
        ),
      );

      // Subscribe to real-time updates
      _streamSub = _liveService.streamDoc(streamId).listen((doc) {
        if (mounted && doc != null) setState(() => _streamDoc = doc);
      });
      _chatSub = _liveService.chatMessages(streamId).listen((msgs) {
        if (!mounted) return;
        setState(() => _chatMessages = msgs);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_chatScrollCtrl.hasClients) {
            _chatScrollCtrl.animateTo(
              _chatScrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      });

      _likeSub?.cancel();
      _likeSub = _liveService.userLikedStream(streamId, user.uid).listen((liked) {
        if (!mounted) return;
        setState(() => _isLiked = liked);
      });

      // Send join system message
      await _liveService.sendMessage(
        streamId: streamId,
        userId: user.uid,
        username: username,
        message: 'Stream started 🎬',
        type: ChatMessageType.system,
      );

      if (!mounted) return;
      setState(() => _liveState = _LiveState.live);
      // Send heartbeat immediately, then every 30 s so discover list stays current
      _liveService.updateHeartbeat(_streamId!).ignore();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_streamId != null) {
          _liveService.updateHeartbeat(_streamId!).ignore();
        }
      });
    } catch (e, st) {
      debugPrint('❌ _goLive error: $e\n$st');
      if (!mounted) return;
      _showToast('Failed to start stream: $e');
      setState(() => _liveState = _LiveState.offline);
    }
  }

  Future<void> _toggleMute() async {
    if (_engine == null) return;
    setState(() => _isMuted = !_isMuted);
    await _engine!.muteLocalAudioStream(_isMuted);
    _showToast(_isMuted ? 'Live stream Muted' : 'Microphone on');
  }

  Future<void> _toggleVideo() async {
    if (_engine == null) return;
    setState(() => _isVideoOff = !_isVideoOff);
    await _engine!.muteLocalVideoStream(_isVideoOff);
    if (_isVideoOff) _showToast('Video turned off');
  }

  void _toggleComments() {
    setState(() => _isCommentsOff = !_isCommentsOff);
    if (_isCommentsOff) _showToast('Comments turned off');
  }

  Future<void> _flipCamera() async {
    if (_engine == null) return;
    await _engine!.switchCamera();
    setState(() => _isFrontCamera = !_isFrontCamera);
  }

  Future<void> _sendChatMessage() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty || _streamId == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _chatCtrl.clear();
    try {
      await _liveService.sendMessage(
        streamId: _streamId!,
        userId: user.uid,
        username: _streamDoc?.hostUsername ?? 'Host',
        profileImage: _streamDoc?.hostProfileImage,
        message: text,
      );
    } catch (e) {
      _showToast('Failed to send');
    }
  }

  Future<void> _sendLike() async {
    if (_streamId == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_likeInFlight) return;

    final wantLiked = !_isLiked;
    _likeInFlight = true;
    setState(() => _isLiked = wantLiked);

    try {
      final actual = await _liveService.toggleLike(
        streamId: _streamId!,
        userId: uid,
        wantLiked: wantLiked,
      );
      if (!mounted) return;
      if (actual != wantLiked) setState(() => _isLiked = actual);
    } catch (_) {
      if (mounted) setState(() => _isLiked = !wantLiked);
      _showToast('Could not update like');
    } finally {
      _likeInFlight = false;
    }
  }

  Future<void> _shareStream() async {
    if (_streamId == null) return;
    final title = _streamTitle.isEmpty ? 'Live on VyooO' : _streamTitle;
    final body = _streamDescription.isNotEmpty ? _streamDescription : title;
    await SharePlus.instance.share(
      ShareParams(text: 'Join my live stream on VyooO: $body'),
    );
  }

  void _toggleStreamInfo() {
    setState(() => _streamInfoExpanded = !_streamInfoExpanded);
  }

  void _setOverlayRouteOpen(bool open) {
    if (_overlayRouteOpen == open) return;
    _overlayRouteOpen = open;
    widget.onOverlayRouteChanged?.call(open);
  }

  Future<void> _applySettingsResult(_LiveSettingsResult result) async {
    if (!mounted) return;
    setState(() {
      _streamTitle = result.title;
      _streamDescription = result.description;
      _streamCategory = result.category;
      _streamTags = result.tags;
      _streamPrice = result.price;
    });
    if (_liveState == _LiveState.live && _streamId != null) {
      await _liveService.updateStreamMetadata(
        streamId: _streamId!,
        title: result.title,
        description: result.description,
      );
    }
  }

  Future<void> _openSettings() async {
    _setOverlayRouteOpen(true);
    try {
      final result = await Navigator.of(context).push<_LiveSettingsResult>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _LiveSettingsSheet(
            initialTitle: _streamTitle,
            initialDescription: _streamDescription,
            initialCategory: _streamCategory,
            initialTags: _streamTags,
            initialPrice: _streamPrice,
            isLive: _liveState == _LiveState.live,
          ),
        ),
      );
      if (!mounted || result == null) return;
      await _applySettingsResult(result);
    } finally {
      if (mounted) {
        _setOverlayRouteOpen(false);
      } else {
        _overlayRouteOpen = false;
        widget.onOverlayRouteChanged?.call(false);
      }
    }
  }

  Future<void> _onEndStream() async {
    final end = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (_) => const _ConfirmDialog(
        message: 'Do you want to end this live stream?',
        confirmLabel: 'Yes, End',
      ),
    );
    if (end != true || !mounted) return;

    // End the stream
    if (_streamId != null && _engine != null) {
      await _engine!.leaveChannel();
      await _liveService.endStream(_streamId!, savedToProfile: false);
    }

    if (!mounted) return;
    final save = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (_) => const _ConfirmDialog(
        message: 'Do you want to add this live stream to your profile?',
        confirmLabel: 'Yes, Add',
      ),
    );

    if (save == true && _streamId != null) {
      await _liveService.endStream(_streamId!, savedToProfile: true);
    }

    if (!mounted) return;
    if (widget.embeddedInMainShell) {
      await _resetToOfflineAfterStream();
    } else {
      Navigator.of(context).pop();
    }
  }

  Widget _buildCountdownCancelButton() {
    return GestureDetector(
      onTap: _cancelCountdown,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.close, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Same **Story | Gallery | Live** row as [UploadScreen] (+ hub); Live is selected here.
  Widget _createHubBottomBar() {
    return UploadCreateBottomBar(
      selectedSegment: 2,
      onStoryTap: () {
        Navigator.of(context).pushReplacement<void, void>(
          MaterialPageRoute<void>(
            builder: (_) => const StoryUploadScreen(successDismissToRoot: true),
          ),
        );
      },
      onPostTap: () {
        Navigator.of(context).pushReplacement<void, void>(
          MaterialPageRoute<void>(
            builder: (_) => const UploadScreen(initialBottomSegment: 1),
          ),
        );
      },
      onLiveTap: _onLiveStartTap,
    );
  }

  void _showToast(String msg) {
    setState(() => _toast = msg);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(),
          _buildGradientOverlay(),
          _buildStateContent(),
          if (widget.embeddedInMainShell) _buildShellTopBar(),
          if (_toast != null) _buildToast(_toast!),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    if (!_engineReady || !_showAgoraView || _engine == null) {
      return Container(color: const Color(0xFF0A000F));
    }
    if (_isVideoOff && _liveState == _LiveState.live) {
      return Container(color: const Color(0xFF0A000F));
    }
    return AgoraVideoView(
      key: ValueKey('creator_agora_$_engineVersion'),
      controller: VideoViewController(
        rtcEngine: _engine!,
        canvas: const VideoCanvas(uid: 0), // 0 = always local video
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.55),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.88),
          ],
          stops: const [0.0, 0.15, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildStateContent() {
    return switch (_liveState) {
      _LiveState.initializing => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      _LiveState.permissionDenied => _buildPermissionDenied(),
      _LiveState.offline => _buildOfflineContent(),
      _LiveState.countdown => _buildCountdownContent(),
      _LiveState.live => _buildLiveContent(),
    };
  }

  // ── Permission denied ──────────────────────────────────────────────────────────

  Widget _buildPermissionDenied() {
    return SafeArea(
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.videocam_off_rounded,
                    color: Colors.white54,
                    size: 64,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Camera & microphone access is required to go live.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _GradientButton(
                    label: 'Open Settings',
                    icon: Icons.settings_rounded,
                    onTap: () => openAppSettings(),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _exitLiveScreen,
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  // ── Offline state ──────────────────────────────────────────────────────────────

  Widget _buildOfflineContent() {
    return SafeArea(
      child: Stack(
        children: [
          if (!widget.embeddedInMainShell)
            Positioned(
              top: 6,
              left: 10,
              child: _CircleIconButton(
                icon: Icons.close,
                onTap: _exitLiveScreen,
              ),
            ),
          // OFFLINE badge
          Positioned(
            top: _shellLogoBarTopInset + 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'OFFLINE',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
          // Right tool icons
          Positioned(
            top: _shellLogoBarTopInset + 86,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CircleIconButton(
                    icon: Icons.mic_none_rounded,
                    onTap: _toggleMute,
                    size: 38,
                  ),
                  _CircleIconButton(
                    icon: Icons.videocam_outlined,
                    onTap: _toggleVideo,
                    size: 38,
                  ),
                  _CircleIconButton(
                    icon: Icons.refresh_rounded,
                    onTap: _flipCamera,
                    size: 38,
                  ),
                  _CircleIconButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    onTap: _toggleComments,
                    size: 38,
                  ),
                  _CircleIconButton(
                    icon: Icons.settings_outlined,
                    onTap: _openSettings,
                    size: 38,
                  ),
                ],
              ),
            ),
          ),
          // Bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_streamTitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _streamTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 8,
                  ),
                  child: _GradientButton(
                    label: 'Start Live',
                    icon: Icons.sensors_rounded,
                    onTap: _onLiveStartTap,
                    isWhite: true,
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Countdown state ────────────────────────────────────────────────────────────

  Widget _buildCountdownContent() {
    return SafeArea(
      child: Stack(
        children: [
          // Background overlay for countdown
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.35)),
          ),
          Positioned(
            top: _shellLogoBarTopInset + 8,
            left: 48,
            right: 48,
            child: Text(
              _streamTitle.isEmpty ? 'Going Live...' : _streamTitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Center(
            child: SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                children: [
                  CustomPaint(
                    size: const Size(96, 96),
                    painter: _CountdownCirclePainter(),
                  ),
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.35),
                      ),
                      child: Center(
                        child: Text(
                          '$_countdown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
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
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.embeddedInMainShell)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildCountdownCancelButton(),
                  ),
                _buildBottomBar(),
                if (!widget.embeddedInMainShell)
                  Container(
                    height: 100,
                    color: const Color(0xFF490038), // brandPurple/Plum bar
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Center(child: _buildCountdownCancelButton()),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Live state ─────────────────────────────────────────────────────────────────

  Widget _buildLiveContent() {
    final likes = _streamDoc?.likeCount ?? 0;

    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: _shellLogoBarTopInset + 88,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CircleIconButton(
                    icon: _isMuted
                        ? Icons.mic_off_outlined
                        : Icons.mic_none_rounded,
                    onTap: _toggleMute,
                    active: _isMuted,
                    size: 38,
                  ),
                  _CircleIconButton(
                    icon: _isVideoOff
                        ? Icons.videocam_off_outlined
                        : Icons.videocam_outlined,
                    onTap: _toggleVideo,
                    active: _isVideoOff,
                    size: 38,
                  ),
                  _CircleIconButton(
                    icon: Icons.refresh_rounded,
                    onTap: _flipCamera,
                    size: 38,
                  ),
                  _CircleIconButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    onTap: _toggleComments,
                    active: _isCommentsOff,
                    size: 38,
                  ),
                  _CircleIconButton(
                    icon: Icons.settings_outlined,
                    onTap: _openSettings,
                    size: 38,
                  ),
                  _CircleIconButton(
                    icon: Icons.stop_rounded,
                    onTap: _onEndStream,
                    active: true,
                    size: 38,
                  ),
                ],
              ),
            ),
          ),
          if (_isCommentsOff)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Comments turned off',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          // Bottom: comments, interaction bar, streamer info
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildChatList(),
                        const SizedBox(height: AppSpacing.sm),
                        _buildLiveInteractionBar(likes),
                      ],
                    ),
                  ),
                  if (_streamInfoExpanded) _buildStreamerInfoBar(),
                  _buildBottomBar(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    final msgs = _isCommentsOff
        ? const <LiveChatMessageModel>[]
        : _chatMessages;
    if (msgs.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        controller: _chatScrollCtrl,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: msgs.length,
        itemBuilder: (context, i) {
          final m = msgs[i];
          final isSystem = m.type == ChatMessageType.system;
          if (isSystem) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Center(
                child: Text(
                  m.message,
                  style: AppTypography.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  backgroundImage: (m.profileImage?.isNotEmpty == true)
                      ? NetworkImage(m.profileImage!)
                      : null,
                  child: (m.profileImage?.isNotEmpty != true)
                      ? Text(
                          m.username.isNotEmpty
                              ? m.username[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLiveInteractionBar(int likes) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: LiveCommentInputField(
            controller: _chatCtrl,
            enabled: !_isCommentsOff,
            onSubmitted: (_) => _sendChatMessage(),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        GestureDetector(
          onTap: _toggleStreamInfo,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Icon(
              _streamInfoExpanded
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_up_rounded,
              color: Colors.white.withValues(alpha: 0.9),
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        GestureDetector(
          onTap: _sendLike,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _isLiked
                    ? const Color(0xFFFF2D55)
                    : Colors.white.withValues(alpha: 0.9),
                size: 22,
              ),
              const SizedBox(width: 4),
              Text(
                _formatCount(likes),
                style: AppTypography.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        GestureDetector(
          onTap: _shareStream,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: SvgPicture.asset(
              LiveStreamAssets.share,
              width: AppSizes.liveShareIconWidth,
              height: AppSizes.liveShareIconHeight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStreamerInfoBar() {
    final hostImage = _streamDoc?.hostProfileImage;
    final description = _streamDescription.isNotEmpty
        ? _streamDescription
        : (_streamTitle.isNotEmpty
            ? _streamTitle
            : 'Watch live on VyooO');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            backgroundImage: hostImage != null && hostImage.isNotEmpty
                ? NetworkImage(hostImage)
                : null,
            child: hostImage == null || hostImage.isEmpty
                ? const Icon(Icons.person, color: Colors.white, size: 22)
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToast(String msg) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          msg,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? AppColors.brandPink.withValues(alpha: 0.35)
              : Colors.transparent,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isWhite = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isWhite;

  @override
  Widget build(BuildContext context) {
    final iconColor = isWhite ? AppColors.brandPink : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isWhite ? Colors.white : null,
          gradient: isWhite
              ? null
              : const LinearGradient(
                  colors: [Color(0xFFDE106B), Color(0xFFF81945)],
                ),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: isWhite ? Colors.black : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeartSliderThumb extends SliderComponentShape {
  final double thumbRadius;

  const _HeartSliderThumb({this.thumbRadius = 14.0});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size.fromRadius(thumbRadius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    final paint = Paint()
      ..color = const Color(0xFFF81945)
      ..style = PaintingStyle.fill;

    // Heart-like badge shape
    const double r = 10.0;
    final path = Path();
    path.moveTo(center.dx, center.dy + r);
    path.cubicTo(
      center.dx - r * 1.5,
      center.dy - r * 0.5,
      center.dx - r * 0.8,
      center.dy - r * 1.8,
      center.dx,
      center.dy - r * 0.8,
    );
    path.cubicTo(
      center.dx + r * 0.8,
      center.dy - r * 1.8,
      center.dx + r * 1.5,
      center.dy - r * 0.5,
      center.dx,
      center.dy + r,
    );
    canvas.drawPath(path, paint);

    // Text inside badge (e.g. C7)
    final val = (value * 10).round();
    final tp = TextPainter(
      text: TextSpan(
        text: 'C$val',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: textDirection,
    );
    tp.layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2 + 2));
  }
}

class _CountdownCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // 1. Solid part (approx 1/3 of circle)
    final solidPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -2.2, // Start at approx 10 o'clock
      2.1, // Sweep approx 120 degrees
      false,
      solidPaint,
    );

    // 2. Dashed part
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const double dashLen = 6;
    const double spaceLen = 6;
    double startAngle = -0.1; // Start where solid part ends
    const double endAngle = 4.0; // End where solid part begins again (looping)

    // Rough loop to draw dashes for the remaining arc
    while (startAngle < endAngle) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashLen / radius,
        false,
        dashPaint,
      );
      startAngle += (dashLen + spaceLen) / radius;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Confirm dialog ─────────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({required this.message, required this.confirmLabel});

  final String message;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        decoration: BoxDecoration(
          color: const Color(0xFF2E0D2E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'VyooO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(true),
                  child: Text(
                    confirmLabel,
                    style: const TextStyle(
                      color: AppColors.brandPink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'No',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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

// ── Settings bottom sheet ──────────────────────────────────────────────────────

class _LiveSettingsResult {
  const _LiveSettingsResult({
    required this.title,
    required this.description,
    required this.category,
    required this.tags,
    required this.price,
  });

  final String title;
  final String description;
  final String category;
  final List<String> tags;
  final int price;
}

class _LiveSettingsSheet extends StatefulWidget {
  const _LiveSettingsSheet({
    required this.initialTitle,
    required this.initialDescription,
    required this.initialCategory,
    required this.initialTags,
    required this.initialPrice,
    required this.isLive,
  });

  final String initialTitle;
  final String initialDescription;
  final String initialCategory;
  final List<String> initialTags;
  final int initialPrice;
  final bool isLive;

  @override
  State<_LiveSettingsSheet> createState() => _LiveSettingsSheetState();
}

class _LiveSettingsSheetState extends State<_LiveSettingsSheet> {
  static const _titleMax = 120;
  static const _descMax = 200;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  final TextEditingController _tagsCtrl = TextEditingController();

  late String _selectedCategory;
  late List<String> _tags;
  late double _priceLevel;

  static const _categories = [
    'Entertainment',
    'Music',
    'Sports',
    'Gaming',
    'Education',
    'Fitness',
    'Travel',
    'Food',
    'Art',
    'Technology',
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _descCtrl = TextEditingController(text: widget.initialDescription);
    _selectedCategory = widget.initialCategory;
    _tags = List.from(widget.initialTags);
    _priceLevel = widget.initialPrice.toDouble().clamp(0, 7);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(
      _LiveSettingsResult(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _selectedCategory,
        tags: List<String>.from(_tags),
        price: _priceLevel.round(),
      ),
    );
  }

  void _addTag(String raw) {
    final tag = raw.trim();
    if (tag.isEmpty || _tags.length >= 8 || _tags.contains(tag)) return;
    setState(() => _tags.add(tag));
    _tagsCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.premiumDark,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Stream Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _save,
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          color: AppColors.brandMagenta,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Form
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    _buildField(
                      'Title',
                      _titleCtrl,
                      _titleMax,
                      'Add your Title',
                      1,
                    ),
                    const SizedBox(height: 24),
                    _buildField(
                      'Description',
                      _descCtrl,
                      _descMax,
                      'Add a short description',
                      3,
                    ),
                    const SizedBox(height: 24),
                    _buildCategoryDropdown(),
                    const SizedBox(height: 24),
                    _buildTagsField(),
                    // Pricing only editable pre-live
                    if (!widget.isLive) ...[
                      const SizedBox(height: 24),
                      _buildPricingSlider(),
                    ],
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl,
    int maxLength,
    String hint,
    int maxLines,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: ctrl,
              builder: (context, v, child) => Text(
                '${v.text.length}/$maxLength',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        TextField(
          controller: ctrl,
          maxLength: maxLength,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 13,
            ),
            border: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24, width: 0.8),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24, width: 0.8),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFDE106B), width: 1.2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            counterText: '',
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedCategory.isEmpty ? null : _selectedCategory,
            hint: Text(
              'Select your category',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 13,
              ),
            ),
            isExpanded: true,
            dropdownColor: const Color(0xFF2A1030),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withValues(alpha: 0.6),
              size: 20,
            ),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            items: _categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _selectedCategory = v ?? ''),
          ),
        ),
        const Divider(color: Colors.white24, height: 1, thickness: 0.8),
        const SizedBox(height: 8),
        Text(
          'Adding a category helps others find your content in search.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildTagsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tags',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${_tags.length}/6',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
        TextField(
          controller: _tagsCtrl,
          enabled: _tags.length < 6,
          onSubmitted: _addTag,
          textInputAction: TextInputAction.done,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Enter your own tags',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 13,
            ),
            border: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24, width: 0.8),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24, width: 0.8),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFDE106B), width: 1.2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            counterText: '',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tags are visible by others and are used to make you discoverable on Vyooo.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
          ),
        ),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _tags.map((t) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => setState(() => _tags.remove(t)),
                      child: Icon(
                        Icons.close,
                        color: Colors.white.withValues(alpha: 0.6),
                        size: 14,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildPricingSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Live video pricing',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Set your per-minute rate for non-subscribers',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFFDE106B),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
            thumbShape: const _HeartSliderThumb(thumbRadius: 16),
            overlayColor: const Color(0xFFDE106B).withValues(alpha: 0.1),
            trackHeight: 2,
          ),
          child: Slider(
            value: _priceLevel,
            min: 0,
            max: 10,
            divisions: 10,
            onChanged: (v) => setState(() => _priceLevel = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [0, 2, 4, 6, 8, 10]
                .map(
                  (i) => Text(
                    '$i',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
