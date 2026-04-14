import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../firebase_options.dart';

/// Top-level handler required by [FirebaseMessaging.onBackgroundMessage].
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) {
    debugPrint('FCM background: id=${message.messageId} data=${message.data}');
  }
}

/// Registers FCM, persists token under `users/{uid}/push_tokens/default` for Cloud Functions.
class PushMessagingService {
  PushMessagingService._();
  static final PushMessagingService instance = PushMessagingService._();

  static const String _tokenDocId = 'default';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _listenersAttached = false;

  /// Call once after [Firebase.initializeApp]. Registers background handler attachment in [main].
  Future<void> configure() async {
    if (kIsWeb) return;
    if (_isApple) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    if (_listenersAttached) return;
    _listenersAttached = true;

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
    _messaging.onTokenRefresh.listen(_onTokenRefresh);
  }

  bool get _isApple =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Request OS permission, fetch token, write to Firestore. Safe to call on each sign-in.
  Future<void> syncTokenForUser(String uid) async {
    if (uid.isEmpty || kIsWeb) return;

    if (_isApple) {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        if (kDebugMode) {
          debugPrint('FCM: notification permission denied');
        }
        return;
      }
    }

    if (_isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        final result = await Permission.notification.request();
        if (!result.isGranted) {
          if (kDebugMode) {
            debugPrint('FCM: Android notification permission not granted');
          }
          return;
        }
      }
    }

    final token = await _getFcmTokenSafely();
    if (token == null || token.isEmpty) {
      if (kDebugMode) debugPrint('FCM: no token (simulator or unavailable)');
      return;
    }

    await _persistToken(uid, token);
  }

  Future<void> _onTokenRefresh(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    await _persistToken(uid, token);
  }

  /// iOS can briefly report "apns-token-not-set" right after permission is granted.
  /// Wait for APNS token and retry fetching FCM token instead of throwing.
  Future<String?> _getFcmTokenSafely() async {
    try {
      return await _messaging.getToken();
    } on FirebaseException catch (e) {
      final isApnsNotReady =
          _isApple && (e.code == 'apns-token-not-set' || e.code == 'unknown');
      if (!isApnsNotReady) {
        if (kDebugMode) debugPrint('FCM getToken failed: ${e.code} ${e.message}');
        return null;
      }

      final ready = await _waitForApnsToken();
      if (!ready) {
        if (kDebugMode) debugPrint('FCM: APNS token not ready yet');
        return null;
      }
      try {
        return await _messaging.getToken();
      } on FirebaseException catch (retryError) {
        if (kDebugMode) {
          debugPrint(
            'FCM getToken retry failed: ${retryError.code} ${retryError.message}',
          );
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FCM getToken failed: $e');
      return null;
    }
  }

  Future<bool> _waitForApnsToken() async {
    if (!_isApple) return true;
    for (var i = 0; i < 12; i++) {
      final apns = await _messaging.getAPNSToken();
      if (apns != null && apns.isNotEmpty) return true;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  Future<void> _persistToken(String uid, String token) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('push_tokens')
          .doc(_tokenDocId)
          .set({
        'token': token,
        'platform': _isApple
            ? 'ios'
            : _isAndroid
                ? 'android'
                : 'other',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (kDebugMode) debugPrint('FCM token saved for $uid');
    } catch (e) {
      if (kDebugMode) debugPrint('FCM persist failed: $e');
    }
  }

  /// Call before [FirebaseAuth.signOut] so this device is not targeted for the old account.
  Future<void> clearForSignOut(String uid) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('push_tokens')
          .doc(_tokenDocId)
          .delete();
    } catch (_) {}
    try {
      await _messaging.deleteToken();
    } catch (_) {}
  }

  void _onForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('FCM foreground: ${message.notification?.title} ${message.data}');
    }
  }

  void _onMessageOpened(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('FCM opened from background: ${message.data}');
    }
  }

  /// Optional: handle cold start from notification tap.
  Future<void> handleInitialMessage() async {
    final initial = await _messaging.getInitialMessage();
    if (initial != null && kDebugMode) {
      debugPrint('FCM initial message: ${initial.data}');
    }
  }
}
