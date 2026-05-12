import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import 'core/config/app_config.dart';
import 'core/navigation/app_keys.dart';
import 'core/navigation/app_route_observer.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/push_messaging_service.dart';
import 'core/subscription/subscription_controller.dart';
import 'core/theme/app_padding.dart';
import 'core/theme/app_theme.dart';
import 'core/wrappers/auth_wrapper.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  bool firebaseInitialized = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // After Firebase init (recommended order). Hot restart can still log
    // "duplicate background isolate" on Android — harmless; use full app restart to clear.
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
    // Local stack: `firebase emulators:start --only firestore,functions` from repo root,
    // then `flutter run --dart-define=USE_FIRESTORE_EMULATOR=true` (debug only).
    if (kDebugMode) {
      const useFirestoreEmu = bool.fromEnvironment(
        'USE_FIRESTORE_EMULATOR',
        defaultValue: false,
      );
      if (!kIsWeb && useFirestoreEmu) {
        const hostOverride = String.fromEnvironment(
          'FIRESTORE_EMULATOR_HOST',
          defaultValue: '',
        );
        final host = hostOverride.trim().isNotEmpty
            ? hostOverride.trim()
            : (Platform.isAndroid ? '10.0.2.2' : 'localhost');
        const port = int.fromEnvironment(
          'FIRESTORE_EMULATOR_PORT',
          defaultValue: 8080,
        );
        FirebaseFirestore.instance.useFirestoreEmulator(host, port);
        debugPrint('Firestore: emulator at $host:$port');
      }
    }
    await _configureFirebaseAppCheck();
    firebaseInitialized = true;
    await PushMessagingService.instance.configure();
  } catch (e, st) {
    debugPrint('Firebase initialization failed: $e');
    debugPrint(st.toString());
  }

  try {
    await DeepLinkService.instance.init();
  } catch (e, st) {
    debugPrint('Deep link init failed: $e');
    debugPrint(st.toString());
  }

  final subscriptionController = SubscriptionController();
  try {
    // Configure RevenueCat only when real billing is enabled and key exists.
    if (!AppConfig.useMockSubscriptions &&
        !AppConfig.enableSubscriptionTierTesting) {
      final revenueCatKey = Platform.isIOS
          ? AppConfig.revenueCatApplePublicKey
          : AppConfig.revenueCatGooglePublicKey;
      if (revenueCatKey.trim().isNotEmpty && !revenueCatKey.contains('XXXX')) {
        await subscriptionController.init(revenueCatKey);
      } else {
        debugPrint(
          'RevenueCat disabled: missing public SDK key for current platform.',
        );
      }
    }
    if (kDebugMode && AppConfig.enableSubscriptionTierTesting) {
      await subscriptionController.loadTestTierOverride();
    }
  } catch (e, st) {
    debugPrint('RevenueCat initialization failed: $e');
    debugPrint(st.toString());
  }

  runApp(
    ChangeNotifierProvider<SubscriptionController>.value(
      value: subscriptionController,
      child: VyoooApp(firebaseInitialized: firebaseInitialized),
    ),
  );
}

Future<void> _configureFirebaseAppCheck() async {
  if (kIsWeb) return;
  const forceDebugAppCheck = bool.fromEnvironment(
    'FORCE_DEBUG_APP_CHECK',
    defaultValue: false,
  );
  // Keep local development unblocked: App Check is only required in release
  // unless explicitly forced on via --dart-define=FORCE_DEBUG_APP_CHECK=true.
  if (!kReleaseMode && !forceDebugAppCheck) {
    debugPrint('AppCheck: skipped for non-release build');
    return;
  }
  final useDebugProvider = forceDebugAppCheck || !kReleaseMode;
  try {
    if (Platform.isAndroid) {
      debugPrint(
        'AppCheck(Android): using ${useDebugProvider ? 'debug' : 'playIntegrity'} provider',
      );
      await FirebaseAppCheck.instance.activate(
        providerAndroid: useDebugProvider
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
      );
      return;
    }
    if (Platform.isIOS) {
      debugPrint(
        'AppCheck(iOS): using ${useDebugProvider ? 'debug' : 'appAttest/deviceCheck'} provider',
      );
      await FirebaseAppCheck.instance.activate(
        providerApple: useDebugProvider
            ? const AppleDebugProvider()
            : const AppleAppAttestWithDeviceCheckFallbackProvider(),
      );
    }
  } catch (e, st) {
    debugPrint('Firebase App Check init failed: $e');
    debugPrint(st.toString());
  }
}

class VyoooApp extends StatelessWidget {
  const VyoooApp({super.key, this.firebaseInitialized = true});

  final bool firebaseInitialized;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vyooo',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      navigatorObservers: [appRouteObserver],
      home: firebaseInitialized
          ? const _SplashVideoScreen()
          : const _FirebaseInitErrorScreen(),
    );
  }
}

class _SplashVideoScreen extends StatefulWidget {
  const _SplashVideoScreen();

  @override
  State<_SplashVideoScreen> createState() => _SplashVideoScreenState();
}

class _SplashVideoScreenState extends State<_SplashVideoScreen> {
  late final VideoPlayerController _controller;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/videos/splash.mp4');
    _initializeVideo();
    _navigationTimer = Timer(const Duration(seconds: 3), _goToNextScreen);
  }

  Future<void> _initializeVideo() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(true);
      await _controller.play();
      if (mounted) setState(() {});
    } catch (e, st) {
      debugPrint('Splash video failed to initialize: $e');
      debugPrint(st.toString());
    }
  }

  void _goToNextScreen() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AuthWrapper(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _controller.value.isInitialized
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Shown when Firebase fails to init (e.g. after hot restart). Do a full run to fix.
class _FirebaseInitErrorScreen extends StatelessWidget {
  const _FirebaseInitErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0015),
      body: SafeArea(
        child: Padding(
          padding: AppPadding.authFormHorizontal,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: Colors.white54,
              ),
              AppPadding.sectionGap,
              const Text(
                'Firebase couldn’t connect',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              AppPadding.itemGap,
              const Text(
                'This often happens after a hot restart.\n\n'
                'Stop the app completely, then run again from your IDE or:\n'
                'flutter run',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
