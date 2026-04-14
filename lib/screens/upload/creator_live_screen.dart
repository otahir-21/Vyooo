import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/config/agora_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/live_chat_message_model.dart';
import '../../core/models/live_stream_model.dart';
import '../../core/services/agora_token_service.dart';
import '../../core/services/live_stream_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

// ── State enum ─────────────────────────────────────────────────────────────────

enum _LiveState { initializing, permissionDenied, offline, countdown, live }

// ── Screen ─────────────────────────────────────────────────────────────────────

/// Creator live streaming screen.
/// Handles camera preview → countdown → live broadcast with Agora + Firebase.
class CreatorLiveScreen extends StatefulWidget {
  const CreatorLiveScreen({super.key});

  @override
  State<CreatorLiveScreen> createState() => _CreatorLiveScreenState();
}

class _CreatorLiveScreenState extends State<CreatorLiveScreen> {
  // ── Agora ────────────────────────────────────────────────────────────────────
  late RtcEngine _engine;
  bool _engineReady = false;
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
  List<LiveChatMessageModel> _chatMessages = [];

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
    _init();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _heartbeatTimer?.cancel();
    _toastTimer?.cancel();
    _streamSub?.cancel();
    _chatSub?.cancel();
    _chatCtrl.dispose();
    _chatScrollCtrl.dispose();
    _disposeEngine();
    super.dispose();
  }

  Future<void> _disposeEngine() async {
    // Auto-end stream if host closes the screen without pressing End Stream
    if (_streamId != null && _liveState == _LiveState.live) {
      await _liveService.endStream(_streamId!).catchError((_) {});
    }
    if (_engineReady) {
      await _engine.stopPreview();
      await _engine.leaveChannel();
      await _engine.release();
    }
  }

  // ── Init ──────────────────────────────────────────────────────────────────────

  Future<void> _init() async {
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
    _engine = createAgoraRtcEngine();
    await _engine.initialize(
      RtcEngineContext(
        appId: AgoraConfig.appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    _engine.registerEventHandler(
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
            await _engine.renewToken(newToken);
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

    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.enableVideo();
    await _engine.enableAudio();
    await _engine.startPreview();

    if (!mounted) return;
    setState(() {
      _engineReady = true;
      _engineVersion++;
      _liveState = _LiveState.offline;
    });
  }

  // ── Actions ───────────────────────────────────────────────────────────────────

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
      await _engine.joinChannel(
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
        if (_streamId != null)
          _liveService.updateHeartbeat(_streamId!).ignore();
      });
    } catch (e, st) {
      debugPrint('❌ _goLive error: $e\n$st');
      if (!mounted) return;
      _showToast('Failed to start stream: $e');
      setState(() => _liveState = _LiveState.offline);
    }
  }

  Future<void> _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    await _engine.muteLocalAudioStream(_isMuted);
    _showToast(_isMuted ? 'Live stream Muted' : 'Microphone on');
  }

  Future<void> _toggleVideo() async {
    setState(() => _isVideoOff = !_isVideoOff);
    await _engine.muteLocalVideoStream(_isVideoOff);
    if (_isVideoOff) _showToast('Video turned off');
  }

  void _toggleComments() {
    setState(() => _isCommentsOff = !_isCommentsOff);
    if (_isCommentsOff) _showToast('Comments turned off');
  }

  Future<void> _flipCamera() async {
    await _engine.switchCamera();
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
    try {
      await _liveService.addLike(_streamId!);
    } catch (_) {}
  }

  Future<void> _openSettings() async {
    if (_streamId != null && _liveState == _LiveState.live) {
      // Can only edit title/description while live — category/tags locked
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _LiveSettingsSheet(
          initialTitle: _streamTitle,
          initialDescription: _streamDescription,
          initialCategory: _streamCategory,
          initialTags: _streamTags,
          initialPrice: _streamPrice,
          isLive: true,
          onSave: (title, desc, category, tags, price) async {
            setState(() {
              _streamTitle = title;
              _streamDescription = desc;
              _streamCategory = category;
              _streamTags = tags;
              _streamPrice = price;
            });
            await _liveService.updateStreamMetadata(
              streamId: _streamId!,
              title: title,
              description: desc,
            );
          },
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _LiveSettingsSheet(
          initialTitle: _streamTitle,
          initialDescription: _streamDescription,
          initialCategory: _streamCategory,
          initialTags: _streamTags,
          initialPrice: _streamPrice,
          isLive: false,
          onSave: (title, desc, category, tags, price) {
            setState(() {
              _streamTitle = title;
              _streamDescription = desc;
              _streamCategory = category;
              _streamTags = tags;
              _streamPrice = price;
            });
          },
        ),
      );
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
    if (_streamId != null) {
      await _engine.leaveChannel();
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

    if (mounted) Navigator.of(context).pop();
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
          if (_toast != null) _buildToast(_toast!),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    if (!_engineReady) return Container(color: const Color(0xFF0A000F));
    if (_isVideoOff && _liveState == _LiveState.live)
      return Container(color: const Color(0xFF0A000F));
    return AgoraVideoView(
      key: ValueKey(_engineVersion),
      controller: VideoViewController(
        rtcEngine: _engine,
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
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Offline state ──────────────────────────────────────────────────────────────

  Widget _buildOfflineContent() {
    return SafeArea(
      child: Stack(
        children: [
          // Close
          Positioned(
            top: 6,
            left: 10,
            child: _CircleIconButton(
              icon: Icons.close,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          // OFFLINE badge
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: const Text(
                  'OFFLINE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),
          ),
          // Right tool icons
          Positioned(
            top: 60,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CircleIconButton(
                    icon: Icons.mic_rounded,
                    onTap: _toggleMute,
                    size: 40,
                  ),
                  _CircleIconButton(
                    icon: Icons.videocam_rounded,
                    onTap: _toggleVideo,
                    size: 40,
                  ),
                  _CircleIconButton(
                    icon: Icons.cameraswitch_rounded,
                    onTap: _flipCamera,
                    size: 40,
                  ),
                  _CircleIconButton(
                    icon: Icons.chat_bubble_rounded,
                    onTap: _toggleComments,
                    size: 40,
                  ),
                  _CircleIconButton(
                    icon: Icons.settings_rounded,
                    onTap: _openSettings,
                    size: 40,
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
                    icon: Icons.wifi_rounded,
                    onTap: _startCountdown,
                    isWhite: true,
                  ),
                ),
                const _LiveSegmentBar(),
                const SizedBox(height: 10),
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
          Positioned(
            top: 14,
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
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.5),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 2.5,
                ),
              ),
              child: Center(
                child: Text(
                  '$_countdown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _cancelCountdown,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
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
    );
  }

  // ── Live state ─────────────────────────────────────────────────────────────────

  Widget _buildLiveContent() {
    final viewers = _streamDoc?.viewerCount ?? 0;
    final likes = _streamDoc?.likeCount ?? 0;

    return SafeArea(
      child: Stack(
        children: [
          // Top: LIVE badge + title
          Positioned(
            top: 12,
            left: 16,
            right: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  backgroundImage: _streamDoc?.hostProfileImage != null
                      ? NetworkImage(_streamDoc!.hostProfileImage!)
                      : null,
                  child: _streamDoc?.hostProfileImage == null
                      ? const Icon(Icons.person, color: Colors.white, size: 20)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _streamTitle.isEmpty ? 'Live Stream Topic' : _streamTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _streamDoc?.description ?? 
                        'Leveraging cutting-edge technologies and modern UI/UX principles to deliver premium experiences. #vyoo #live #creative',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 60,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CircleIconButton(
                    icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    onTap: _toggleMute,
                    active: _isMuted,
                    size: 40,
                  ),
                  _CircleIconButton(
                    icon: _isVideoOff
                        ? Icons.videocam_off_rounded
                        : Icons.videocam_rounded,
                    onTap: _toggleVideo,
                    active: _isVideoOff,
                    size: 40,
                  ),
                  _CircleIconButton(
                    icon: Icons.cameraswitch_rounded,
                    onTap: _flipCamera,
                    size: 40,
                  ),
                  _CircleIconButton(
                    icon: Icons.speaker_notes_rounded,
                    onTap: _toggleComments,
                    active: _isCommentsOff,
                    size: 40,
                  ),
                  _CircleIconButton(
                    icon: Icons.settings_rounded,
                    onTap: _openSettings,
                    size: 40,
                  ),
                ],
              ),
            ),
          ),
          if (_isCommentsOff)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
          // Bottom: chat + input + end button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildChatList(),
                  const SizedBox(height: 8),
                  _buildCommentRow(likes, viewers),
                  const SizedBox(height: 10),
                  _buildEndStreamButton(),
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
      constraints: const BoxConstraints(maxHeight: 150),
      child: ListView.builder(
        controller: _chatScrollCtrl,
        shrinkWrap: true,
        itemCount: msgs.length,
        itemBuilder: (context, i) {
          final m = msgs[i];
          final isSystem = m.type == ChatMessageType.system;
          if (isSystem) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Center(
                child: Text(
                  m.message,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  backgroundImage: (m.profileImage?.isNotEmpty == true)
                      ? NetworkImage(m.profileImage!)
                      : null,
                  child: (m.profileImage?.isNotEmpty != true)
                      ? Text(
                          m.username[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, height: 1.3),
                      children: [
                        TextSpan(
                          text: '${m.username} ',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: m.message,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCommentRow(int likes, int viewers) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _chatCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendChatMessage(),
              decoration: InputDecoration(
                hintText: 'Reply...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Views
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.remove_red_eye_outlined, color: Colors.white.withValues(alpha: 0.7), size: 16),
            const SizedBox(width: 4),
            Text(_formatCount(viewers), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(width: 12),
        // Likes
        GestureDetector(
          onTap: _sendLike,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite, color: Colors.pink, size: 16),
              const SizedBox(width: 4),
              Text(_formatCount(likes), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Icon(Icons.reply_rounded, color: Colors.white, size: 20),
      ],
    );
  }

  Widget _buildEndStreamButton() {
    return Center(
      child: GestureDetector(
        onTap: _onEndStream,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF8B1538),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'End stream',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToast(String msg) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          msg,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
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
              ? AppColors.pink.withValues(alpha: 0.35)
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 24),
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
            Icon(
              icon,
              color: isWhite ? Colors.black : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: isWhite ? Colors.black : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveSegmentBar extends StatelessWidget {
  const _LiveSegmentBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SegBtn(
          label: 'Story',
          icon: Icons.auto_stories_rounded,
          selected: false,
          onTap: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 8),
        _SegBtn(
          label: 'Gallery',
          icon: Icons.photo_library_rounded,
          selected: false,
          onTap: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 8),
        const _SegBtn(
          label: 'Live',
          icon: Icons.videocam_rounded,
          selected: true,
          onTap: null,
        ),
      ],
    );
  }
}

class _SegBtn extends StatelessWidget {
  const _SegBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? Colors.white : Colors.white.withValues(alpha: 0.65);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDE106B) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size.fromRadius(thumbRadius);

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
    path.cubicTo(center.dx - r * 1.5, center.dy - r * 0.5, center.dx - r * 0.8, center.dy - r * 1.8, center.dx, center.dy - r * 0.8);
    path.cubicTo(center.dx + r * 0.8, center.dy - r * 1.8, center.dx + r * 1.5, center.dy - r * 0.5, center.dx, center.dy + r);
    canvas.drawPath(path, paint);

    // Text inside badge (e.g. C7)
    final val = (value * 10).round();
    final tp = TextPainter(
      text: TextSpan(
        text: 'C$val',
        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
      ),
      textDirection: textDirection,
    );
    tp.layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2 + 2));
  }
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
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E0A1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'VyooO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 15,
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
                      color: Color(0xFFDE106B),
                      fontSize: 15,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
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

typedef _SettingsSaveCallback =
    void Function(
      String title,
      String description,
      String category,
      List<String> tags,
      int pricePerMinute,
    );

class _LiveSettingsSheet extends StatefulWidget {
  const _LiveSettingsSheet({
    required this.initialTitle,
    required this.initialDescription,
    required this.initialCategory,
    required this.initialTags,
    required this.initialPrice,
    required this.isLive,
    required this.onSave,
  });

  final String initialTitle;
  final String initialDescription;
  final String initialCategory;
  final List<String> initialTags;
  final int initialPrice;
  final bool isLive;
  final _SettingsSaveCallback onSave;

  @override
  State<_LiveSettingsSheet> createState() => _LiveSettingsSheetState();
}

class _LiveSettingsSheetState extends State<_LiveSettingsSheet> {
  static const _titleMax = 150;
  static const _descMax = 500;

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
    widget.onSave(
      _titleCtrl.text.trim(),
      _descCtrl.text.trim(),
      _selectedCategory,
      _tags,
      _priceLevel.round(),
    );
    Navigator.of(context).pop();
  }

  void _addTag(String raw) {
    final tag = raw.trim();
    if (tag.isEmpty || _tags.length >= 8 || _tags.contains(tag)) return;
    setState(() => _tags.add(tag));
    _tagsCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A0020), Color(0xFF0D000F), Color(0xFF1A0020)],
              stops: [0.0, 0.5, 1.0],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
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
                        size: 28,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Stream Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _save,
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          color: Color(0xFFDE106B),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Form
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    _buildField(
                      'Title',
                      _titleCtrl,
                      _titleMax,
                      'Add your title',
                      1,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildField(
                      'Description',
                      _descCtrl,
                      _descMax,
                      'Add a short description',
                      3,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'All content must be categorized for better search experience',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildCategoryDropdown(),
                    const SizedBox(height: AppSpacing.md),
                    _buildTagsField(),
                    // Pricing only editable pre-live
                    if (!widget.isLive) ...[
                      const SizedBox(height: AppSpacing.md),
                      _buildPricingSlider(),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
          'All content must be categorized for better search experience.',
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
          'Tags are visible by others and are used to make you discoverable on vyoo.',
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
                .map((i) => Text(
                      '$i',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}
