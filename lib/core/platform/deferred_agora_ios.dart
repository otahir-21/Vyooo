import 'dart:io' show Platform;

import 'package:flutter/services.dart';

const _channel = MethodChannel('vyooo/deferred_native_plugins');

/// Avoid redundant platform-channel work; native side is also idempotent via `hasPlugin:`.
bool _iosDeferredAgoraRegistrationDone = false;

/// On iOS, Agora + Iris native plugins are not registered at cold start (see
/// `ios/scripts/strip_agora_at_launch.sh`). Call this before loading any library
/// that uses `agora_rtc_engine`, so registration runs on the main isolate once.
///
/// Safe to call from every live/call entry point: native [AgoraDeferredRegistration]
/// skips plugins already registered (e.g. if [GeneratedPluginRegistrant] still
/// included them for that build).
Future<void> registerDeferredAgoraPluginsIfNeeded() async {
  if (!Platform.isIOS) return;
  if (_iosDeferredAgoraRegistrationDone) return;
  try {
    await _channel.invokeMethod<void>('registerAgora');
    _iosDeferredAgoraRegistrationDone = true;
  } on PlatformException catch (e) {
    throw StateError(
      'Deferred Agora native registration failed: ${e.message ?? e.code}',
    );
  }
}
