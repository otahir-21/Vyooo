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
  String? _lastConsentStatus;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ParentalConsentService()
        .consentStream(widget.consentId)
        .listen(_onConsent, onError: (_) {});
  }

  void _onConsent(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    final status = (data?['status'] as String?) ?? '';
    if (status == _lastConsentStatus) return;
    if (status != 'approved' && status != 'denied') return;
    _lastConsentStatus = status;

    final uid = AuthService().currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    unawaited(
      ParentalConsentService()
          .minorSyncUserDocFromConsent(minorUid: uid, consentId: widget.consentId)
          .then((_) {}, onError: (_) {}),
    );
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
                  const SizedBox(height: 32),
                  if (uid.isNotEmpty)
                    StreamBuilder<AppUserModel?>(
                      stream: UserService().userStream(uid),
                      builder: (context, snap) {
                        final u = snap.data;
                        final st = u?.parentConsentStatus ?? '';
                        if (st == ParentConsentStatusValue.approved) {
                          return const Text(
                            'Approved — continuing…',
                            style: TextStyle(color: Colors.greenAccent, fontSize: 15),
                          );
                        }
                        if (st == ParentConsentStatusValue.denied) {
                          return const Text(
                            'This request was declined. Go back to enter another parent contact.',
                            style: TextStyle(color: AppColors.brandPink, fontSize: 15),
                          );
                        }
                        return const Row(
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
                                style: TextStyle(color: Colors.white70, fontSize: 15),
                              ),
                            ),
                          ],
                        );
                      },
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
