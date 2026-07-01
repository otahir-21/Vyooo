import 'package:flutter/material.dart';

import '../../core/navigation/home_feed_chrome_controller.dart';
import '../../core/platform/deferred_agora_ios.dart';
import 'broadcast_live_feed_screen.dart' deferred as broadcast;

/// Main-shell broadcast tab: vertical live viewer feed (Figma live feed).
/// Agora loads lazily — only when this tab is opened.
class BroadcastTabHost extends StatefulWidget {
  const BroadcastTabHost({
    super.key,
    required this.isActive,
    required this.onRequestHome,
    this.chromeController,
  });

  final bool isActive;

  /// Kept for API compatibility with [MainNavWrapper]; feed tab does not exit to home.
  final VoidCallback onRequestHome;

  final HomeFeedChromeController? chromeController;

  @override
  State<BroadcastTabHost> createState() => _BroadcastTabHostState();
}

class _BroadcastTabHostState extends State<BroadcastTabHost> {
  bool _libraryLoaded = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _ensureLibrary();
    }
  }

  @override
  void didUpdateWidget(BroadcastTabHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_libraryLoaded && _loadError == null) {
      _ensureLibrary();
    }
  }

  Future<void> _ensureLibrary() async {
    if (_libraryLoaded || _loadError != null) return;
    try {
      await registerDeferredAgoraPluginsIfNeeded();
      await broadcast.loadLibrary();
      if (!mounted) return;
      setState(() => _libraryLoaded = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return const ColoredBox(color: Color(0xFF0A000F));
    }

    if (_loadError != null) {
      return ColoredBox(
        color: const Color(0xFF0A000F),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Live streaming is unavailable right now.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 15,
              ),
            ),
          ),
        ),
      );
    }

    if (!_libraryLoaded) {
      return const ColoredBox(
        color: Color(0xFF0A000F),
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return broadcast.BroadcastLiveFeedScreen(
      isActive: widget.isActive,
      chromeController: widget.chromeController,
    );
  }
}
