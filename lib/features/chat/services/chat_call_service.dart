import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/config/agora_config.dart';
import '../../../core/platform/deferred_agora_ios.dart';
import '../../../core/services/agora_token_service.dart';

class ChatCallService extends ChangeNotifier {
  ChatCallService._();
  static final ChatCallService instance = ChatCallService._();

  RtcEngine? _engine;
  bool _engineReady = false;
  bool _joined = false;
  bool _joining = false;
  bool _micMuted = false;
  bool _cameraMuted = false;
  bool _speakerOn = true;
  bool _frontCamera = true;
  final Set<int> _remoteUids = {};
  int _localUid = 0;
  String _channelName = '';

  bool get engineReady => _engineReady;
  bool get joined => _joined;
  bool get joining => _joining;
  bool get micMuted => _micMuted;
  bool get cameraMuted => _cameraMuted;
  bool get speakerOn => _speakerOn;
  bool get frontCamera => _frontCamera;
  Set<int> get remoteUids => Set.unmodifiable(_remoteUids);
  int get localUid => _localUid;
  String get channelName => _channelName;
  RtcEngine? get engine => _engine;

  Future<bool> requestPermissions({required bool isVideo}) async {
    debugPrint('[ChatCall] requestPermissions isVideo=$isVideo');
    final mic = await Permission.microphone.request();
    debugPrint('[ChatCall] mic permission: $mic');
    if (!mic.isGranted) return false;
    if (isVideo) {
      final cam = await Permission.camera.request();
      debugPrint('[ChatCall] camera permission: $cam');
      if (!cam.isGranted) return false;
    }
    return true;
  }

  Future<void> initEngine() async {
    if (_engineReady) {
      debugPrint('[ChatCall] initEngine: already ready');
      return;
    }
    debugPrint('[ChatCall] initEngine: start');
    await registerDeferredAgoraPluginsIfNeeded();
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(
      RtcEngineContext(
        appId: AgoraConfig.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
    debugPrint('[ChatCall] RtcEngine_initialize done');

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint(
            '[ChatCall] onJoinChannelSuccess channel=${connection.channelId} uid=${connection.localUid} elapsed=$elapsed',
          );
          _joined = true;
          _joining = false;
          _applySpeakerphone();
          notifyListeners();
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          debugPrint('[ChatCall] onUserJoined remoteUid=$remoteUid');
          _remoteUids.add(remoteUid);
          notifyListeners();
        },
        onUserOffline: (connection, remoteUid, reason) {
          debugPrint(
            '[ChatCall] onUserOffline remoteUid=$remoteUid reason=$reason',
          );
          _remoteUids.remove(remoteUid);
          notifyListeners();
        },
        onError: (err, msg) {
          debugPrint('[ChatCall] onError: $err $msg');
        },
      ),
    );

    _engineReady = true;
    debugPrint('[ChatCall] initEngine: done');
  }

  Future<void> _applySpeakerphone() async {
    if (_engine == null) return;
    try {
      await _engine!.setEnableSpeakerphone(_speakerOn);
      debugPrint('[ChatCall] setEnableSpeakerphone($_speakerOn) OK');
    } catch (e) {
      debugPrint(
        '[ChatCall] setEnableSpeakerphone($_speakerOn) failed (non-fatal): $e',
      );
    }
  }

  Future<void> joinChannel({
    required String channelName,
    required bool isVideo,
  }) async {
    if (!_engineReady || _engine == null) {
      debugPrint('[ChatCall] joinChannel: engine not ready');
      return;
    }
    if (_joining || _joined) {
      debugPrint(
        '[ChatCall] joinChannel: already joining=$_joining joined=$_joined',
      );
      return;
    }

    _joining = true;
    _channelName = channelName;

    final firebaseUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _localUid = AgoraConfig.agoraUidFromFirebaseUid(firebaseUid);

    debugPrint(
      '[ChatCall] appId prefix=${AgoraConfig.appId.substring(0, 8)}...',
    );
    debugPrint(
      '[ChatCall] channelName="$channelName" (len=${channelName.length})',
    );
    debugPrint(
      '[ChatCall] localAgoraUid=$_localUid (from firebaseUid=${firebaseUid.substring(0, firebaseUid.length.clamp(0, 6))}...)',
    );
    debugPrint('[ChatCall] isVideo=$isVideo');

    final token = await AgoraTokenService().getToken(
      channelName: channelName,
      uid: _localUid,
      isHost: true,
    );
    debugPrint('[ChatCall] token received length=${token.length}');

    await _engine!.enableAudio();
    debugPrint('[ChatCall] enableAudio done');

    if (isVideo) {
      await _engine!.enableVideo();
      debugPrint('[ChatCall] enableVideo done');
      await _engine!.startPreview();
      debugPrint('[ChatCall] startPreview done');
    } else {
      await _engine!.disableVideo();
      debugPrint('[ChatCall] disableVideo done');
    }

    _speakerOn = true;
    _micMuted = false;
    _cameraMuted = false;
    _frontCamera = true;
    _remoteUids.clear();

    debugPrint(
      '[ChatCall] joinChannel: calling engine.joinChannel uid=$_localUid channel="$channelName"',
    );
    await _engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: _localUid,
      options: const ChannelMediaOptions(
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
        publishMicrophoneTrack: true,
        publishCameraTrack: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
    debugPrint('[ChatCall] joinChannel: call returned');
  }

  Future<void> leaveChannel() async {
    if (!_engineReady || _engine == null) return;
    if (!_joined && !_joining) return;
    try {
      await _engine!.leaveChannel();
    } catch (_) {}
    _joined = false;
    _joining = false;
    _remoteUids.clear();
    notifyListeners();
  }

  Future<void> dispose_() async {
    await leaveChannel();
    if (_engineReady && _engine != null) {
      try {
        _engine!.unregisterEventHandler(RtcEngineEventHandler());
        await _engine!.release();
      } catch (_) {}
      _engine = null;
      _engineReady = false;
    }
    _channelName = '';
    notifyListeners();
  }

  Future<void> toggleMic() async {
    if (!_engineReady || _engine == null) return;
    _micMuted = !_micMuted;
    await _engine!.muteLocalAudioStream(_micMuted);
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    if (!_engineReady || _engine == null) return;
    _cameraMuted = !_cameraMuted;
    await _engine!.muteLocalVideoStream(_cameraMuted);
    notifyListeners();
  }

  Future<void> switchCamera() async {
    if (!_engineReady || _engine == null) return;
    await _engine!.switchCamera();
    _frontCamera = !_frontCamera;
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    if (!_engineReady || _engine == null) return;
    _speakerOn = !_speakerOn;
    try {
      await _engine!.setEnableSpeakerphone(_speakerOn);
    } catch (e) {
      debugPrint('[ChatCall] toggleSpeaker failed (non-fatal): $e');
    }
    notifyListeners();
  }
}
