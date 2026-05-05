import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/call_session_model.dart';
import '../services/call_signaling_service.dart';
import 'chat_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({
    super.key,
    required this.callSession,
    required this.currentUid,
    this.callerName,
    this.callerAvatarUrl,
  });

  final CallSessionModel callSession;
  final String currentUid;
  final String? callerName;
  final String? callerAvatarUrl;

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final CallSignalingService _signaling = CallSignalingService();
  StreamSubscription<CallSessionModel?>? _callSub;
  bool _handling = false;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    _callSub = _signaling.watchCall(widget.callSession.id).listen((session) {
      if (!mounted) return;
      if (_accepting) return;
      if (session == null) {
        debugPrint('[IncomingCall] session null, closing');
        _close();
        return;
      }
      if (session.status != CallStatus.ringing) {
        debugPrint(
          '[IncomingCall] status changed to ${session.status}, closing',
        );
        _close();
      }
    });
  }

  @override
  void dispose() {
    _callSub?.cancel();
    super.dispose();
  }

  void _close() {
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _accept() async {
    if (_handling) return;
    setState(() {
      _handling = true;
      _accepting = true;
    });
    debugPrint('[IncomingCall] accept tapped callId=${widget.callSession.id}');
    try {
      debugPrint('[IncomingCall] calling acceptCall');
      await _signaling.acceptCall(
        callId: widget.callSession.id,
        uid: widget.currentUid,
      );
      debugPrint('[IncomingCall] acceptCall success');
      if (!mounted) return;
      _callSub?.cancel();
      _callSub = null;
      debugPrint(
        '[IncomingCall] navigating to ChatCallScreen channel=${widget.callSession.agoraChannelName}',
      );
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ChatCallScreen(
            callSession: widget.callSession.copyWith(status: CallStatus.active),
            currentUid: widget.currentUid,
            callerName: widget.callerName,
          ),
        ),
      );
      debugPrint('[IncomingCall] navigation complete');
    } catch (e) {
      debugPrint('[IncomingCall] accept failed error=$e');
      _accepting = false;
      if (mounted) {
        setState(() => _handling = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to accept call: $e')));
      }
    }
  }

  Future<void> _decline() async {
    if (_handling) return;
    setState(() => _handling = true);
    debugPrint('[IncomingCall] decline tapped callId=${widget.callSession.id}');
    try {
      await _signaling.declineCall(
        callId: widget.callSession.id,
        uid: widget.currentUid,
      );
    } catch (_) {}
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callSession.type == CallType.video;
    final name = widget.callerName ?? 'Unknown';
    final avatar = widget.callerAvatarUrl;
    final hasAvatar = avatar != null && avatar.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF07010F),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            CircleAvatar(
              radius: 56,
              backgroundColor: const Color(0xFF2A1B2E),
              backgroundImage: hasAvatar
                  ? CachedNetworkImageProvider(avatar)
                  : null,
              child: hasAvatar
                  ? null
                  : const Icon(Icons.person, color: Colors.white54, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _accepting
                  ? 'Connecting...'
                  : isVideo
                  ? 'Incoming video call...'
                  : 'Incoming audio call...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
            const Spacer(flex: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.call_end,
                  color: Colors.red,
                  label: 'Decline',
                  onTap: _decline,
                ),
                _buildActionButton(
                  icon: isVideo ? Icons.videocam : Icons.call,
                  color: Colors.green,
                  label: 'Accept',
                  onTap: _accept,
                ),
              ],
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _handling ? null : onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _handling ? color.withValues(alpha: 0.4) : color,
              shape: BoxShape.circle,
            ),
            child: _accepting
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
