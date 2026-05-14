import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/platform/deferred_agora_ios.dart';
import '../../core/subscription/subscription_controller.dart';
import '../../features/subscription/subscription_screen.dart';
import 'creator_live_screen.dart' deferred as creator;

/// Opens creator live broadcast. Deferred so Agora is not loaded at app/tab startup.
Future<void> openCreatorLiveScreen(BuildContext context) async {
  final subCtrl = context.read<SubscriptionController>();
  final uid = FirebaseAuth.instance.currentUser?.uid;

  Future<void> pushCreatorLive() async {
    await registerDeferredAgoraPluginsIfNeeded();
    await creator.loadLibrary();
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => creator.CreatorLiveScreen(),
      ),
    );
  }

  var canGoLive = await subCtrl.reconcilePaidStatus(firebaseUid: uid);
  if (!context.mounted) return;
  if (!canGoLive) {
    final subscribed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const SubscriptionScreen(),
      ),
    );
    if (!context.mounted) return;
    if (subscribed != true) return;
    canGoLive = await subCtrl.reconcilePaidStatus(firebaseUid: uid);
    if (!context.mounted) return;
    if (!canGoLive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Subscription is still activating. Try Live again in a moment.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
  }

  await pushCreatorLive();
}
