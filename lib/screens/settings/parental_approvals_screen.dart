import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/parental_consent_service.dart';
import '../../core/services/user_service.dart';
import '../../core/widgets/app_gradient_background.dart';

/// Parent or guardian approves or denies minor account requests.
class ParentalApprovalsScreen extends StatefulWidget {
  const ParentalApprovalsScreen({super.key});

  @override
  State<ParentalApprovalsScreen> createState() => _ParentalApprovalsScreenState();
}

class _ParentalApprovalsScreenState extends State<ParentalApprovalsScreen> {
  QuerySnapshot<Map<String, dynamic>>? _lastEmail;
  QuerySnapshot<Map<String, dynamic>>? _lastPhone;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _emailSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _phoneSub;
  String _actionId = '';
  String? _message;

  /// Email and phone used to match [parental_consents] (shown when list is empty).
  String _matchEmail = '';
  String _matchPhone = '';
  String? _errorEmailQuery;
  String? _errorPhoneQuery;
  bool _listenBusy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_startListen());
  }

  Future<void> _startListen() async {
    await _emailSub?.cancel();
    await _phoneSub?.cancel();
    _emailSub = null;
    _phoneSub = null;

    final authUser = AuthService().currentUser;
    if (authUser == null) return;

    if (mounted) setState(() => _listenBusy = true);
    try {
      try {
        await authUser.reload();
      } catch (_) {}
      final refreshed = AuthService().currentUser;
      if (refreshed == null) return;

      final uid = refreshed.uid;
      final appUser = await UserService().getUser(uid, server: true);
      final email = (refreshed.email ?? appUser?.email ?? '').trim().toLowerCase();
      final phoneRaw = appUser?.phoneNumber ?? refreshed.phoneNumber ?? '';
      final phone = UserService.normalizePhone(phoneRaw);

      if (!mounted) return;
      setState(() {
        _matchEmail = email;
        _matchPhone = phone;
        _errorEmailQuery = null;
        _errorPhoneQuery = null;
      });

      void onEmailErr(Object e, StackTrace st) {
        if (kDebugMode) {
          debugPrint('parental_approvals email query: $e');
        }
        if (mounted) {
          setState(() {
            _errorEmailQuery =
                'Could not load requests for your email (network or permissions). Tap Refresh.';
          });
        }
      }

      void onPhoneErr(Object e, StackTrace st) {
        if (kDebugMode) {
          debugPrint('parental_approvals phone query: $e');
        }
        if (mounted) {
          setState(() {
            _errorPhoneQuery =
                'Could not load requests for your phone (network or permissions). Tap Refresh.';
          });
        }
      }

      _emailSub = ParentalConsentService()
          .pendingByParentEmail(email)
          .listen(
        (s) {
          if (mounted) {
            setState(() {
              _lastEmail = s;
              _errorEmailQuery = null;
            });
          }
        },
        onError: onEmailErr,
      );
      _phoneSub = ParentalConsentService()
          .pendingByParentPhone(phone)
          .listen(
        (s) {
          if (mounted) {
            setState(() {
              _lastPhone = s;
              _errorPhoneQuery = null;
            });
          }
        },
        onError: onPhoneErr,
      );
    } finally {
      if (mounted) setState(() => _listenBusy = false);
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _mergedDocs() {
    final merged = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final d in _lastEmail?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
      merged[d.id] = d;
    }
    for (final d in _lastPhone?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
      merged.putIfAbsent(d.id, () => d);
    }
    final list = merged.values.toList()
      ..sort((a, b) {
        final ta = a.data()['createdAt'];
        final tb = b.data()['createdAt'];
        if (ta is Timestamp && tb is Timestamp) {
          return tb.compareTo(ta);
        }
        return 0;
      });
    return list;
  }

  @override
  void dispose() {
    unawaited(_emailSub?.cancel() ?? Future<void>.value());
    unawaited(_phoneSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  Future<void> _approve(String id) async {
    setState(() {
      _actionId = id;
      _message = null;
    });
    try {
      await ParentalConsentService().approveAsParent(id);
      if (mounted) {
        setState(() {
          _actionId = '';
          _message = 'Approved.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _actionId = '';
          _message =
              'Could not approve. Sign in with the same email or phone your child entered.';
        });
      }
    }
  }

  Future<void> _deny(String id) async {
    setState(() {
      _actionId = id;
      _message = null;
    });
    try {
      await ParentalConsentService().denyAsParent(id);
      if (mounted) {
        setState(() {
          _actionId = '';
          _message = 'Declined.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _actionId = '';
          _message = 'Could not update request.';
        });
      }
    }
  }

  Widget _emptyStateBody() {
    final emailLine = _matchEmail.isEmpty
        ? 'Email: (none on this sign-in — add the same email to your VyooO profile your child used, or sign in with that email.)'
        : 'Email: $_matchEmail';
    final phoneLine = _matchPhone.isEmpty || !_matchPhone.startsWith('+')
        ? 'Phone on profile: (none or incomplete — child must have entered this exact number.)'
        : 'Phone on profile: $_matchPhone';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_listenBusy)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            ),
          if (_errorEmailQuery != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _errorEmailQuery!,
                style: TextStyle(
                  color: Colors.orange.shade200,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
          if (_errorPhoneQuery != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _errorPhoneQuery!,
                style: TextStyle(
                  color: Colors.orange.shade200,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
          Text(
            'No pending requests match this account yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'We only show invites that use the same contact as below (must match what your child typed).',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emailLine,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  phoneLine,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.tonal(
            onPressed: _listenBusy ? null : () => unawaited(_startListen()),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _mergedDocs();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.premiumDark,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Family approvals',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: _listenBusy ? null : () => unawaited(_startListen()),
                      icon: _listenBusy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh, color: Colors.white),
                    ),
                  ],
                ),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    _message!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ),
              Expanded(
                child: list.isEmpty
                    ? Center(child: _emptyStateBody())
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final doc = list[i];
                          final data = doc.data();
                          final un =
                              (data['minorUsername'] as String?) ?? 'user';
                          final busy = _actionId == doc.id;
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '@$un',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'wants to use VyooO',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: busy ? null : () => _deny(doc.id),
                                        child: const Text('Decline'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.brandPink,
                                        ),
                                        onPressed: busy ? null : () => _approve(doc.id),
                                        child: busy
                                            ? const SizedBox(
                                                height: 18,
                                                width: 18,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              )
                                            : const Text('Approve'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
