import 'dart:async' show unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/app_user_model.dart';
import '../utils/account_message.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/otp_session_service.dart';
import '../services/push_messaging_service.dart';
import '../../screens/auth/create_account_screen.dart';
import '../../screens/auth/create_username_screen.dart';
import '../../screens/auth/verify_code_screen.dart';
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
  String? _fcmBoundUid;
  String? _lastSeenUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        final uid = user?.uid;
        if (uid == null && _lastSeenUid != null) {
          final expected = AuthService.consumeExpectedSignOut();
          if (!expected) {
            AuthService.markForceLogoutDetected();
          }
        }
        if (uid != null && uid.isNotEmpty) {
          _lastSeenUid = uid;
        } else {
          _lastSeenUid = null;
        }
        if (_purchasesBoundUid != uid) {
          _purchasesBoundUid = uid;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            unawaited(context.read<SubscriptionController>().syncPurchasesIdentity(uid));
          });
        }
        if (uid != null && uid.isNotEmpty && _fcmBoundUid != uid) {
          _fcmBoundUid = uid;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(PushMessagingService.instance.syncTokenForUser(uid));
            unawaited(PushMessagingService.instance.handleInitialMessage());
          });
        }
        if (uid == null) {
          _fcmBoundUid = null;
        }
        if (!authSnapshot.hasData || user == null) {
          return const CreateAccountScreen();
        }
        final isPasswordAccount =
            user.providerData.any((p) => p.providerId == 'password');
        return _UserDocGate(
          uid: user.uid,
          email: user.email ?? '',
          isPasswordAccount: isPasswordAccount,
        );
      },
    );
  }
}

String _maskEmailForDisplay(String email) {
  final t = email.trim();
  final at = t.indexOf('@');
  if (at <= 0 || at >= t.length - 1) return t;
  final local = t.substring(0, at);
  final domain = t.substring(at + 1);
  if (local.length <= 1) return '***@$domain';
  return '${local[0]}${'*' * (local.length - 1)}@$domain';
}

String _maskPhoneForDisplay(String phone) {
  final t = phone.trim();
  if (t.length <= 4) return t;
  final visible = t.substring(t.length - 4);
  return '${'*' * (t.length - 4)}$visible';
}

class _UserDocGate extends StatefulWidget {
  const _UserDocGate({
    required this.uid,
    required this.email,
    required this.isPasswordAccount,
  });

  final String uid;
  final String email;
  final bool isPasswordAccount;

  @override
  State<_UserDocGate> createState() => _UserDocGateState();
}

class _UserDocGateState extends State<_UserDocGate> {
  late Future<void> _readyFuture;
  String _lastAccountNotice = '';

  @override
  void initState() {
    super.initState();
    _readyFuture = _bootstrapUserDoc();
  }

  @override
  void didUpdateWidget(covariant _UserDocGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _readyFuture = _bootstrapUserDoc();
    }
  }

  Future<void> _bootstrapUserDoc() async {
    final appUser = await UserService().getUser(widget.uid);
    if (!mounted) return;
    if (appUser == null && widget.email.isNotEmpty) {
      await UserService().ensureUserDocument(
        uid: widget.uid,
        email: widget.email,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _readyFuture,
      builder: (context, readySnapshot) {
        if (readySnapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D0015),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          );
        }
        return StreamBuilder<AppUserModel?>(
          stream: UserService().userStream(widget.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting &&
                userSnapshot.data == null) {
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
            return ListenableBuilder(
              listenable: Listenable.merge([
                OtpSessionService.sessionRevision,
                AuthService.authNoticeRevision,
              ]),
              builder: (context, _) {
                _maybeShowAccountNotice(appUser);
                final handshake = OtpSessionService().emailLoginHandshakeActive;
                if (widget.isPasswordAccount &&
                    appUser.emailOtpVerified &&
                    handshake) {
                  return const Scaffold(
                    backgroundColor: Color(0xFF0D0015),
                    body: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  );
                }
                return FutureBuilder<bool>(
                  key: ValueKey<String>(
                    'otp_${widget.uid}_${OtpSessionService.sessionRevision.value}_${AuthService.authNoticeRevision.value}',
                  ),
                  future: OtpSessionService().isOtpRequiredForUid(widget.uid),
                  builder: (context, otpSnapshot) {
                    if (otpSnapshot.connectionState != ConnectionState.done) {
                      return const Scaffold(
                        backgroundColor: Color(0xFF0D0015),
                        body: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      );
                    }
                    final sessionOtpRequired = otpSnapshot.data ?? false;
                    if (widget.isPasswordAccount &&
                        (sessionOtpRequired || !appUser.emailOtpVerified)) {
                      return FutureBuilder<(String channel, String destination)>(
                        future: OtpSessionService().getSignupOtpPreference(),
                        builder: (context, prefSnapshot) {
                          final pref = prefSnapshot.data;
                          final channel = (pref?.$1 ?? 'email').toLowerCase();
                          final destination = pref?.$2 ?? '';
                          final useWhatsApp = channel == 'whatsapp' &&
                              destination.trim().isNotEmpty;
                          return VerifyCodeScreen(
                            channel: useWhatsApp ? 'whatsapp' : 'email',
                            phoneNumber: useWhatsApp ? destination : '',
                            maskedPhone: useWhatsApp
                                ? _maskPhoneForDisplay(destination)
                                : '',
                            maskedEmail: _maskEmailForDisplay(widget.email),
                            autoSendOnOpen: !sessionOtpRequired && !useWhatsApp,
                          );
                        },
                      );
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
              },
            );
          },
        );
      },
    );
  }

  void _maybeShowAccountNotice(AppUserModel appUser) {
    final forceLogoutDetected = AuthService.forceLogoutDetected;
    final notice = accountMessage(
      status: appUser.verificationStatus,
      restricted: appUser.accountType.trim().toLowerCase() == 'restricted',
      forceLogoutDetected: forceLogoutDetected,
      creatorVerified: appUser.vipVerified || appUser.isVerified,
    );
    if (notice.isEmpty || notice == _lastAccountNotice) return;
    _lastAccountNotice = notice;
    if (forceLogoutDetected) {
      AuthService.clearForceLogoutDetected();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(SnackBar(content: Text(notice)));
    });
  }
}
