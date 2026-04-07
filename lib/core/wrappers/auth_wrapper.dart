import 'dart:async' show unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/app_user_model.dart';
import '../services/user_service.dart';
import '../../screens/auth/create_account_screen.dart';
import '../../screens/auth/create_username_screen.dart';
import '../../screens/debug/tier_picker_screen.dart';
import '../subscription/subscription_controller.dart';
import 'main_nav_wrapper.dart';

/// Flow guard: routes to Register, Onboarding, or Home based on Firebase Auth + Firestore user doc.
/// When not logged in, show Register first. Do NOT allow access to onboarding if onboardingCompleted is true.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _purchasesBoundUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        final uid = user?.uid;
        if (_purchasesBoundUid != uid) {
          _purchasesBoundUid = uid;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            unawaited(context.read<SubscriptionController>().syncPurchasesIdentity(uid));
          });
        }
        if (!authSnapshot.hasData || user == null) {
          return const CreateAccountScreen();
        }
        return _UserDocGate(uid: user.uid, email: user.email ?? '');
      },
    );
  }
}

class _UserDocGate extends StatefulWidget {
  const _UserDocGate({required this.uid, required this.email});

  final String uid;
  final String email;

  @override
  State<_UserDocGate> createState() => _UserDocGateState();
}

class _UserDocGateState extends State<_UserDocGate> {
  late Future<AppUserModel?> _userFuture;

  Future<AppUserModel?> _loadOrCreateUser() async {
    final appUser = await UserService().getUser(widget.uid);
    if (appUser == null && widget.email.isNotEmpty) {
      await UserService().ensureUserDocument(uid: widget.uid, email: widget.email);
      return UserService().getUser(widget.uid);
    }
    return appUser;
  }

  @override
  void initState() {
    super.initState();
    _userFuture = _loadOrCreateUser();
  }

  @override
  void didUpdateWidget(covariant _UserDocGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid || oldWidget.email != widget.email) {
      _userFuture = _loadOrCreateUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUserModel?>(
      future: _userFuture,
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D0015),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          );
        }
        final appUser = userSnapshot.data;
        if (appUser == null) {
          return const CreateUsernameScreen();
        }
        if (appUser.onboardingCompleted) {
          if (kDebugMode && AppConfig.enableSubscriptionTierTesting) {
            return TierPickerScreen(
              onContinue: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MainNavWrapper()),
                  (route) => false,
                );
              },
            );
          }
          return const MainNavWrapper();
        }
        return const CreateUsernameScreen();
      },
    );
  }
}
