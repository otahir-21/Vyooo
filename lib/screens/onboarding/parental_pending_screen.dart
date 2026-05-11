import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/app_user_model.dart';
import '../../core/models/parent_consent_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/parental_consent_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_gradient_background.dart';

/// Minor waits here until a parent approves or denies in [ParentalApprovalsScreen].
class ParentalPendingScreen extends StatefulWidget {
  const ParentalPendingScreen({super.key, required this.consentId});

  final String consentId;

  @override
  State<ParentalPendingScreen> createState() => _ParentalPendingScreenState();
}

class _ParentalPendingScreenState extends State<ParentalPendingScreen> {
  /// Firestore document id for [parental_consents] (no whitespace).
  late final String _consentDocId;

  String? _terminalConsentHandled;
  String _consentLiveStatus = '';
  bool _consentStreamError = false;
  bool _syncBusy = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  static String _statusLabel(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'pending':
        return 'Waiting for parent';
      case 'approved':
        return 'Approved';
      case 'denied':
        return 'Declined';
      default:
        return raw.isEmpty ? 'Loading…' : raw;
    }
  }

  static String _accountLabel(String? status) {
    final s = (status ?? '').trim().toLowerCase();
    switch (s) {
      case ParentConsentStatusValue.pending:
        return 'Pending approval';
      case ParentConsentStatusValue.approved:
        return 'Approved';
      case ParentConsentStatusValue.denied:
        return 'Declined';
      case ParentConsentStatusValue.pendingContact:
        return 'Need parent contact';
      case ParentConsentStatusValue.notRequired:
        return 'Not required';
      default:
        return s.isEmpty ? 'Loading…' : status!.trim();
    }
  }

  @override
  void initState() {
    super.initState();
    _consentDocId = widget.consentId.replaceAll(RegExp(r'\s+'), '');
    if (_consentDocId.isEmpty) {
      _consentStreamError = true;
      return;
    }
    _sub = ParentalConsentService()
        .consentStream(_consentDocId)
        .listen(_onConsent, onError: (_) {
      if (mounted) setState(() => _consentStreamError = true);
    });
  }

  void _onConsent(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    final status = (data?['status'] as String?) ?? '';
    if (mounted) {
      setState(() {
        _consentLiveStatus = status;
        _consentStreamError = false;
      });
    }

    if (status != 'approved' && status != 'denied') return;
    if (status == _terminalConsentHandled) return;
    _terminalConsentHandled = status;

    final uid = AuthService().currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    unawaited(
      ParentalConsentService()
          .minorSyncUserDocFromConsent(minorUid: uid, consentId: _consentDocId)
          .then((_) {}, onError: (_) {}),
    );
  }

  Future<void> _manualSync() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null || uid.isEmpty || _consentDocId.isEmpty) return;
    setState(() => _syncBusy = true);
    try {
      await ParentalConsentService().minorSyncUserDocFromConsent(
        minorUid: uid,
        consentId: _consentDocId,
      );
    } finally {
      if (mounted) setState(() => _syncBusy = false);
    }
  }

  @override
  void dispose() {
    final s = _sub;
    _sub = null;
    if (s != null) unawaited(s.cancel());
    super.dispose();
  }

  Future<void> _onBack() async {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    await AuthService().signOut();
  }

  bool _needsAccountSync(String? accountStatus) {
    final a = (accountStatus ?? '').trim().toLowerCase();
    final c = _consentLiveStatus.trim().toLowerCase();
    if (c == 'approved' && a == ParentConsentStatusValue.pending) return true;
    if (c == 'denied' && a == ParentConsentStatusValue.pending) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid ?? '';

    return PopScope(
      canPop: Navigator.of(context).canPop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AppGradientBackground(
          type: GradientType.dob,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: _onBack,
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Waiting for parent',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.defaultTextColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ask your parent or guardian to open VyooO → Settings → Family approvals and approve your account.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_consentDocId.isEmpty)
                    Text(
                      'This device is missing a valid request id. Go back and send the parent request again.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Colors.redAccent.withValues(alpha: 0.95),
                      ),
                    )
                  else if (_consentStreamError)
                    Text(
                      'Could not load request status. Check your connection, then use Sync now below.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Colors.orangeAccent.withValues(alpha: 0.95),
                      ),
                    )
                  else if (uid.isEmpty)
                    const Text(
                      'Sign in again to see your request status.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    )
                  else
                    StreamBuilder<AppUserModel?>(
                      stream: UserService().userStream(uid),
                      builder: (context, userSnap) {
                        final u = userSnap.data;
                        final accountSt = u?.parentConsentStatus ?? '';
                        final needsSync = _needsAccountSync(
                          accountSt.isEmpty ? null : accountSt,
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Request status: ${_statusLabel(_consentLiveStatus)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Your account: ${_accountLabel(accountSt.isEmpty ? null : accountSt)}',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                  if (needsSync) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      'The request changed but your profile did not update yet. Tap Sync now to continue.',
                                      style: TextStyle(
                                        color: Colors.amber.shade100,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    FilledButton(
                                      onPressed: _syncBusy ? null : _manualSync,
                                      child: _syncBusy
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text('Sync now'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (accountSt == ParentConsentStatusValue.approved)
                              const Text(
                                'Approved — continuing…',
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 15,
                                ),
                              )
                            else if (accountSt == ParentConsentStatusValue.denied)
                              const Text(
                                'This request was declined. Go back to enter another parent contact.',
                                style: TextStyle(
                                  color: AppColors.brandPink,
                                  fontSize: 15,
                                ),
                              )
                            else
                              const Row(
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Checking status…',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            if (_consentLiveStatus == 'pending' &&
                                accountSt == ParentConsentStatusValue.pending)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: TextButton(
                                  onPressed: _syncBusy ? null : _manualSync,
                                  child: Text(
                                    'Parent already tapped approve? Sync now',
                                    style: TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                      decorationColor: AppTheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  if (uid.isNotEmpty && (_consentStreamError || _consentDocId.isEmpty))
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: FilledButton.tonal(
                        onPressed: _syncBusy || _consentDocId.isEmpty ? null : _manualSync,
                        child: _syncBusy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Sync now'),
                      ),
                    ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
