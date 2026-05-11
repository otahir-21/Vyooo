import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/app_user_model.dart';
import '../services/auth_service.dart';
import '../services/in_app_notification_alert_service.dart';
import '../services/otp_session_service.dart';
import '../services/push_messaging_service.dart';
import '../services/signup_draft_service.dart';
import '../services/user_service.dart';
import '../utils/account_message.dart';
import '../../screens/auth/create_account_screen.dart';
import '../../screens/auth/create_username_screen.dart';
import '../../screens/auth/verify_code_screen.dart';
import '../../screens/debug/tier_picker_screen.dart';
import '../../screens/onboarding/organization_details_screen.dart';
import '../onboarding/onboarding_gate.dart';
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
        final shouldBindMessaging =
            uid != null && uid.isNotEmpty && !(user?.isAnonymous ?? true);
        if (shouldBindMessaging && _fcmBoundUid != uid) {
          _fcmBoundUid = uid;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(PushMessagingService.instance.syncTokenForUser(uid));
            unawaited(PushMessagingService.instance.handleInitialMessage());
            InAppNotificationAlertService.instance.startForUser(uid);
          });
        }
        if (shouldBindMessaging) {
          // Keep listener alive even after hot-restart/rebuild edge cases.
          InAppNotificationAlertService.instance.startForUser(uid);
        }
        if (uid == null || (user?.isAnonymous ?? true)) {
          _fcmBoundUid = null;
          InAppNotificationAlertService.instance.stop();
        }
        // Do not use `hasData`: for a signed-out user Firebase emits `null`, and
        // [AsyncSnapshot.hasData] is false whenever `data` is null — that would show
        // the loader forever. Only treat [ConnectionState.waiting] as "not resolved yet".
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _AuthDeterminingScaffold();
        }
        if (user == null) {
          return const CreateAccountScreen();
        }
        if (user.isAnonymous) {
          final draft = SignupDraftService().current;
          if (draft == null) {
            return const CreateAccountScreen();
          }
          return FutureBuilder<(String channel, String destination)>(
            future: OtpSessionService().getSignupOtpPreference(),
            builder: (context, prefSnapshot) {
              if (prefSnapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  backgroundColor: Color(0xFF0D0015),
                  body: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                );
              }
              final pref = prefSnapshot.data;
              final channel = (pref?.$1 ?? draft.channel).toLowerCase();
              final destination = (pref?.$2 ?? '').trim();
              final phone = destination.isNotEmpty ? destination : draft.phoneNumber;
              return VerifyCodeScreen(
                channel: channel == 'phone' ? 'phone' : 'email',
                phoneNumber: phone,
                maskedPhone: channel == 'phone' ? _maskPhoneForDisplay(phone) : '',
                maskedEmail: _maskEmailForDisplay(draft.email),
                autoSendOnOpen: false,
              );
            },
          );
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

/// Shown only while [StreamBuilder] is still in [ConnectionState.waiting] for auth state.
class _AuthDeterminingScaffold extends StatelessWidget {
  const _AuthDeterminingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D0015),
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
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
  late Future<bool> _otpRequiredFuture;
  String _lastAccountNotice = '';
  String? _selectedLoginOtpChannel;
  String _selectedLoginOtpPhone = '';
  bool _otpDialogInFlight = false;
  bool _lastOtpRequired = false;
  int _lastAuthNoticeRevision = -1;
  int _lastOtpSessionRevision = -1;

  @override
  void initState() {
    super.initState();
    _readyFuture = _bootstrapUserDoc();
    _otpRequiredFuture = _isPasswordOtpRequired();
  }

  @override
  void didUpdateWidget(covariant _UserDocGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _readyFuture = _bootstrapUserDoc();
      _otpRequiredFuture = _isPasswordOtpRequired();
      _selectedLoginOtpChannel = null;
      _selectedLoginOtpPhone = '';
      _otpDialogInFlight = false;
      _lastOtpRequired = false;
      _lastAuthNoticeRevision = -1;
      _lastOtpSessionRevision = -1;
    }
  }

  Future<void> _bootstrapUserDoc() async {
    final appUser = await UserService().getUser(widget.uid);
    if (!mounted) return;
    if (appUser == null) {
      await UserService().ensureUserDocument(
        uid: widget.uid,
        email: widget.email,
        emailOtpVerified: !widget.isPasswordAccount,
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
                AuthService.authNoticeRevision,
                OtpSessionService.sessionRevision,
              ]),
              builder: (context, _) {
                _maybeShowAccountNotice(appUser);
                final authNoticeRevision = AuthService.authNoticeRevision.value;
                final otpSessionRevision = OtpSessionService.sessionRevision.value;
                if (authNoticeRevision != _lastAuthNoticeRevision ||
                    otpSessionRevision != _lastOtpSessionRevision) {
                  _lastAuthNoticeRevision = authNoticeRevision;
                  _lastOtpSessionRevision = otpSessionRevision;
                  _otpRequiredFuture = _isPasswordOtpRequired();
                }
                return FutureBuilder<bool>(
                  future: _otpRequiredFuture,
                  builder: (context, otpSnapshot) {
                    final isOtpRequired = otpSnapshot.connectionState == ConnectionState.done
                        ? (otpSnapshot.data == true)
                        : _lastOtpRequired;
                    if (otpSnapshot.connectionState == ConnectionState.done) {
                      _lastOtpRequired = isOtpRequired;
                    }
                    if (isOtpRequired) {
                      if (_selectedLoginOtpChannel == null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _showLoginOtpMethodDialog(appUser);
                        });
                        return const Scaffold(
                          backgroundColor: Color(0xFF0D0015),
                          body: Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        );
                      }
                      return VerifyCodeScreen(
                        channel: _selectedLoginOtpChannel!,
                        maskedEmail: _maskEmailForDisplay(widget.email),
                        phoneNumber: _selectedLoginOtpPhone,
                        maskedPhone: _selectedLoginOtpPhone.isNotEmpty
                            ? _maskPhoneForDisplay(_selectedLoginOtpPhone)
                            : '',
                      );
                    }
                    _selectedLoginOtpChannel = null;
                    _selectedLoginOtpPhone = '';
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
                    return _nextOnboardingScreen(appUser);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<bool> _isPasswordOtpRequired() async {
    if (!widget.isPasswordAccount) return false;
    final otpSession = OtpSessionService();
    if (otpSession.emailLoginHandshakeActive) return true;
    return otpSession.isOtpRequiredForUid(widget.uid);
  }

  Future<void> _showLoginOtpMethodDialog(AppUserModel appUser) async {
    if (!mounted || _otpDialogInFlight || _selectedLoginOtpChannel != null) return;
    _otpDialogInFlight = true;
    final normalizedPhone = UserService.normalizePhone(appUser.phoneNumber ?? '');
    final hasPhone = normalizedPhone.startsWith('+') && normalizedPhone.length >= 8;
    final selected = await _showOtpMethodDialog(
      email: widget.email,
      phoneNumber: hasPhone ? normalizedPhone : '',
    );
    if (!mounted) {
      _otpDialogInFlight = false;
      return;
    }
    _otpDialogInFlight = false;
    if (selected == null) return;
    setState(() {
      _selectedLoginOtpChannel = selected;
      _selectedLoginOtpPhone = selected == 'phone' && hasPhone
          ? normalizedPhone
          : '';
    });
  }

  Future<String?> _showOtpMethodDialog({
    required String email,
    required String phoneNumber,
  }) {
    final platform = Theme.of(context).platform;
    final isCupertino =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    if (isCupertino) {
      return _showCupertinoOtpMethodDialog(email: email, phoneNumber: phoneNumber);
    }
    return _showMaterialOtpMethodDialog(email: email, phoneNumber: phoneNumber);
  }

  Future<String?> _showCupertinoOtpMethodDialog({
    required String email,
    required String phoneNumber,
  }) {
    final hasPhone = phoneNumber.isNotEmpty;
    return showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Verify login'),
        message: const Text('Choose how you want to receive OTP.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('email'),
            child: Text(
              email.isEmpty ? 'Email OTP' : 'Email OTP\n$email',
              textAlign: TextAlign.center,
            ),
          ),
          if (hasPhone)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop('phone'),
              child: Text(
                'Number OTP\n$phoneNumber',
                textAlign: TextAlign.center,
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<String?> _showMaterialOtpMethodDialog({
    required String email,
    required String phoneNumber,
  }) {
    final hasPhone = phoneNumber.isNotEmpty;
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify login'),
        content: const Text('Choose how you want to receive OTP.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('email'),
            child: Text(email.isEmpty ? 'Email OTP' : 'Email OTP ($email)'),
          ),
          if (hasPhone)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('phone'),
              child: Text('Number OTP ($phoneNumber)'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
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

  Widget _nextOnboardingScreen(AppUserModel appUser) {
    final hasUsername = (appUser.username ?? '').trim().isNotEmpty;
    if (!hasUsername) {
      return const CreateUsernameScreen();
    }

    final accountType = appUser.accountType.trim().toLowerCase();
    if (accountType == 'business' || accountType == 'government') {
      if (!appUser.orgProfileCompleted) {
        return OrganizationDetailsScreen(accountType: accountType);
      }
    }

    // Username is set and any required org profile step is complete.
    return OnboardingGate.nextScreen(appUser);
  }
}
