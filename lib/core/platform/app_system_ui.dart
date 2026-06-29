import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Central Android/iOS system UI setup for edge-to-edge and phone portrait.
abstract final class AppSystemUi {
  /// Logical width threshold: below = phone (portrait lock), at/above = large screen.
  static const double phoneShortestSideDp = 600;

  /// Call once from [main] after [WidgetsFlutterBinding.ensureInitialized].
  static Future<void> configureAtStartup() async {
    if (kIsWeb) return;

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await applyPhonePortraitLockIfNeeded();
    setEdgeToEdgeOverlayStyle();
  }

  /// Transparent system bars; icon brightness only (no deprecated bar colors on Android 15+).
  static void setEdgeToEdgeOverlayStyle() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
    );
  }

  /// Portrait on phones only; large screens (tablets/foldables) stay unrestricted for Play/Android 16.
  static Future<void> applyPhonePortraitLockIfNeeded() async {
    if (kIsWeb) return;
    if (!isPhoneLayout) {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      return;
    }
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  static bool get isPhoneLayout {
    final views = PlatformDispatcher.instance.views;
    if (views.isEmpty) return true;
    final view = views.first;
    final logicalSize = view.physicalSize / view.devicePixelRatio;
    return logicalSize.shortestSide < phoneShortestSideDp;
  }

  /// Hides system overlays without [SystemUiMode.immersiveSticky] (deprecated bar-color APIs on Android 15+).
  static Future<void> enterImmersiveFullscreen() async {
    if (kIsWeb) return;
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: const <SystemUiOverlay>[],
    );
  }

  static Future<void> exitImmersiveFullscreen() async {
    if (kIsWeb) return;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    setEdgeToEdgeOverlayStyle();
    await applyPhonePortraitLockIfNeeded();
  }

  /// Bottom padding so app chrome (bottom nav, auth floating controls) sits above
  /// the system gesture/nav bar. Android uses the full inset; iOS keeps a partial
  /// overlap with the home indicator for the floating pill look.
  static double bottomChromeInset(
    BuildContext context, {
    double iosInsetFactor = 0.5,
  }) {
    final systemBottom = MediaQuery.viewPaddingOf(context).bottom;
    if (kIsWeb) return 0;
    if (Platform.isAndroid) return systemBottom;
    return systemBottom * iosInsetFactor;
  }

  /// Re-apply portrait after leaving a route that cleared orientation (e.g. crop).
  static Future<void> onReturnToAppShell() async {
    if (kIsWeb) return;
    if (Platform.isIOS || Platform.isAndroid) {
      await applyPhonePortraitLockIfNeeded();
    }
  }
}
