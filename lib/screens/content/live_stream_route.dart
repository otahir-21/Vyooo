import 'package:flutter/material.dart';

import '../../core/models/live_stream_model.dart';
import '../../core/platform/deferred_agora_ios.dart';
import 'live_stream_screen.dart' deferred as live;

/// Opens the viewer live screen. Deferred import delays loading Agora/iris until
/// the user enters a stream (IndexedStack builds Search/Profile without touching RTC).
Future<void> openLiveStreamScreen(
  BuildContext context,
  LiveStreamModel stream,
) async {
  await registerDeferredAgoraPluginsIfNeeded();
  await live.loadLibrary();
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => live.LiveStreamScreen(stream: stream),
    ),
  );
}
