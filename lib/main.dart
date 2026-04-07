import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/subscription/subscription_controller.dart';
import 'core/theme/app_padding.dart';
import 'core/theme/app_theme.dart';
import 'core/wrappers/auth_wrapper.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseInitialized = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseInitialized = true;
  } catch (e, st) {
    debugPrint('Firebase initialization failed: $e');
    debugPrint(st.toString());
  }

  final subscriptionController = SubscriptionController();
  try {
    // In mock/tier-testing mode, skip RevenueCat network initialization
    // to avoid "offerings empty" configuration noise in debug/dev builds.
    if (!AppConfig.useMockSubscriptions &&
        !AppConfig.enableSubscriptionTierTesting) {
      // Use iOS key on iOS, Android key on Android (RevenueCat gives one per platform).
      final revenueCatKey = Platform.isIOS
          ? 'appl_vPZwqxiBnbyvgMUEvKURLKzCRpj' // iOS public API key
          : 'goog_XXXXXXXXXXXX'; // Replace with your Android public API key when needed
      await subscriptionController.init(revenueCatKey);
    }
    if (kDebugMode || AppConfig.enableSubscriptionTierTesting) {
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

class VyoooApp extends StatelessWidget {
  const VyoooApp({super.key, this.firebaseInitialized = true});

  final bool firebaseInitialized;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vyooo',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      home: firebaseInitialized
          ? const AuthWrapper()
          : const _FirebaseInitErrorScreen(),
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
