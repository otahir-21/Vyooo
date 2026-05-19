import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../features/chat/models/call_session_model.dart';
import '../../features/chat/screens/incoming_call_screen.dart';
import '../../screens/notifications/notification_screen.dart';
import '../navigation/app_keys.dart';

class PushNotificationRouter {
  PushNotificationRouter._();

  static void handleMessage(RemoteMessage message) {
    final data = message.data;
    if (data.isEmpty) return;

    final nav = appNavigatorKey.currentState;
    if (nav == null) return;

    final type = (data['type'] ?? '').toString().trim().toLowerCase();

    if (type == 'incoming_call') {
      _handleIncomingCallTap(data);
      return;
    }

    if (type == 'chat_message') {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (appNavigatorKey.currentState == null) return;
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => const NotificationScreen(),
        ),
      );
    });
  }

  static void _handleIncomingCallTap(Map<String, dynamic> data) {
    final callId = (data['callId'] ?? '').toString().trim();
    if (callId.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final nav = appNavigatorKey.currentState;
      if (nav == null) return;

      try {
        final doc = await FirebaseFirestore.instance
            .collection('callSessions')
            .doc(callId)
            .get();
        if (!doc.exists) return;
        final session = CallSessionModel.fromFirestore(doc);
        if (session.status != CallStatus.ringing) return;
        if (!session.calleeIds.contains(uid)) return;

        String? callerName;
        String? callerAvatar;
        try {
          final chatDoc = await FirebaseFirestore.instance
              .collection('chats')
              .doc(session.chatId)
              .get();
          if (chatDoc.exists) {
            final chatData = chatDoc.data();
            final pMap = chatData?['participantMap'] as Map<String, dynamic>?;
            final callerInfo = pMap?[session.callerId] as Map<String, dynamic>?;
            if (callerInfo != null) {
              callerName = (callerInfo['displayName'] as String?) ??
                  (callerInfo['username'] as String?);
              callerAvatar = callerInfo['profileImage'] as String?;
            }
          }
        } catch (_) {}

        final currentNav = appNavigatorKey.currentState;
        if (currentNav == null) return;
        currentNav.push(
          MaterialPageRoute<void>(
            builder: (_) => IncomingCallScreen(
              callSession: session,
              currentUid: uid,
              callerName: callerName,
              callerAvatarUrl: callerAvatar,
            ),
          ),
        );
      } catch (_) {}
    });
  }
}
