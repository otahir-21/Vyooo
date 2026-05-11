import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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

  @override
  void initState() {
    super.initState();
    _listen();
  }

  Future<void> _listen() async {
    final auth = AuthService().currentUser;
    if (auth == null) return;
    final uid = auth.uid;
    final appUser = await UserService().getUser(uid);
    final email = (auth.email ?? appUser?.email ?? '').trim().toLowerCase();
    final phoneRaw = appUser?.phoneNumber ?? auth.phoneNumber ?? '';
    final phone = UserService.normalizePhone(phoneRaw);

    _emailSub = ParentalConsentService()
        .pendingByParentEmail(email)
        .listen((s) {
      _lastEmail = s;
      _remerge();
    }, onError: (_) {});
    _phoneSub = ParentalConsentService()
        .pendingByParentPhone(phone)
        .listen((s) {
      _lastPhone = s;
      _remerge();
    }, onError: (_) {});
  }

  void _remerge() {
    if (mounted) setState(() {});
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
                    const SizedBox(width: 48),
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
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No pending requests.\n\nIf your child entered your email or phone, make sure this account uses the same email or verified phone number.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              height: 1.4,
                            ),
                          ),
                        ),
                      )
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
