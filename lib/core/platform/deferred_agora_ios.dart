import 'dart:io' show Platform;

import 'package:flutter/services.dart';

const _channel = MethodChannel('vyooo/deferred_native_plugins');

/// On iOS, Agora + Iris native plugins are not registered at cold start (see
/// `ios/scripts/strip_agora_at_launch.sh`). Call this before loading any library
/// that uses `agora_rtc_engine`, so registration runs on the main isolate once.
Future<void> registerDeferredAgoraPluginsIfNeeded() async {
  if (!Platform.isIOS) return;
  try {
    await _channel.invokeMethod<void>('registerAgora');
  } on PlatformException catch (e) {
    throw StateError(
      'Deferred Agora native registration failed: ${e.message ?? e.code}',
    );
  }
}
