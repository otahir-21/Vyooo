import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../screens/notifications/notification_screen.dart';
import '../navigation/app_keys.dart';

/// Routes the user when they open the app from an FCM notification tap.
class PushNotificationRouter {
  PushNotificationRouter._();

  static void handleMessage(RemoteMessage message) {
    final data = message.data;
    if (data.isEmpty) return;

    final nav = appNavigatorKey.currentState;
    if (nav == null) return;

    final type = (data['type'] ?? '').toString().trim().toLowerCase();

    if (type == 'chat_message' || type == 'incoming_call') {
      // Chat/call flows are opened from their existing screens when active.
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
}
