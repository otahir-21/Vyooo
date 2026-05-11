import 'dart:async';

import 'package:country_picker/country_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/app_user_model.dart';
import '../../core/models/parent_consent_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/parental_consent_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_theme.dart' show AppTheme, White24;
import '../../core/widgets/app_gradient_background.dart';

/// Collects parent/guardian contact so a minor can send a consent request.
class ParentContactScreen extends StatefulWidget {
  const ParentContactScreen({
    super.key,
    this.previousDenied = false,
  });

  final bool previousDenied;

  @override
  State<ParentContactScreen> createState() => _ParentContactScreenState();
}

class _ParentContactScreenState extends State<ParentContactScreen> {
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _phoneFocusNode = FocusNode();
  /// Same defaults as [CreateAccountScreen] phone signup.
  String _selectedCountryDialCode = '44';
  String _selectedCountryFlag = '🇬🇧';
  bool _submitting = false;
  String? _error;
  /// After Firestore confirms pending consent, [AuthWrapper] swaps to [ParentalPendingScreen].
  /// Never use [Navigator.pushReplacement] here: it can replace the root [AuthWrapper] route.
  bool _awaitingGateHandoff = false;
  Timer? _handoffTimeout;

  @override
  void dispose() {
    _handoffTimeout?.cancel();
    _email.dispose();
    _phone.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  void _pickCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      favorite: const ['GB', 'AE'],
      countryListTheme: CountryListThemeData(
        backgroundColor: const Color(0xFF12081C),
        textStyle: const TextStyle(color: Colors.white),
        inputDecoration: InputDecoration(
          labelText: 'Search country',
          labelStyle: TextStyle(color: AppTheme.secondaryTextColor),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: White24.value),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppTheme.primary),
          ),
        ),
      ),
      onSelect: (Country c) {
        if (!mounted) return;
        setState(() {
          _selectedCountryDialCode = c.phoneCode;
          _selectedCountryFlag = c.flagEmoji;
        });
      },
    );
  }

  /// Matches [CreateAccountScreen._normalizedPhone] for consistent E.164-style input.
  String _normalizedParentPhone() {
    final raw = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.isEmpty) return '';
    final local = raw.startsWith('0') ? raw.substring(1) : raw;
    return '+$_selectedCountryDialCode$local';
  }

  Widget _buildParentPhoneField() {
    return TextField(
      controller: _phone,
      focusNode: _phoneFocusNode,
      keyboardType: TextInputType.phone,
      style: const TextStyle(color: Colors.white),
      decoration: _decoration(
        'Phone number',
        prefixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _pickCountry,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Text(
                  '$_selectedCountryFlag +$_selectedCountryDialCode',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final user = await UserService().getUser(uid);
      final username = (user?.username ?? '').trim();
      if (username.isEmpty) {
        setState(() {
          _submitting = false;
          _error = 'Set a username first, then try again.';
        });
        return;
      }
      final consentGate = (user?.parentConsentStatus ?? '').trim();
      if (consentGate != ParentConsentStatusValue.pendingContact &&
          consentGate != ParentConsentStatusValue.denied) {
        setState(() {
          _submitting = false;
          _error =
              'Your account is not ready for this step yet. Go back to date of birth, tap Continue so it saves, then open this screen again to send the parent request.';
        });
        return;
      }
      final id = await ParentalConsentService().createPendingRequest(
        minorUid: uid,
        minorUsername: username,
        parentEmail: _email.text,
        parentPhoneRaw: _normalizedParentPhone(),
      );
      if (!mounted) return;

      // Wait until Firestore (server) shows pending + this consent id so [AuthWrapper]
      // will not immediately rebuild back to [ParentContactScreen].
      final userSvc = UserService();
      AppUserModel? fresh;
      for (var i = 0; i < 6; i++) {
        fresh = await userSvc.getUser(uid, server: true);
        final st = (fresh?.parentConsentStatus ?? '').trim().toLowerCase();
        final cid = (fresh?.parentConsentId ?? '').trim();
        if (st == ParentConsentStatusValue.pending &&
            cid.isNotEmpty &&
            cid == id) {
          break;
        }
        await Future<void>.delayed(Duration(milliseconds: 120 * (i + 1)));
        if (!mounted) return;
      }
      if (!mounted) return;
      final st = (fresh?.parentConsentStatus ?? '').trim().toLowerCase();
      final cid = (fresh?.parentConsentId ?? '').trim();
      if (st != ParentConsentStatusValue.pending || cid != id) {
        setState(() {
          _submitting = false;
          _error =
              'The request was sent but your profile did not update yet. Check your connection, wait a few seconds, and tap Send request again.';
        });
        return;
      }

      _handoffTimeout?.cancel();
      _handoffTimeout = Timer(const Duration(seconds: 18), () {
        if (!mounted || !_awaitingGateHandoff) return;
        setState(() => _awaitingGateHandoff = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Still here? Your request may already be pending — try closing and reopening the app.',
            ),
          ),
        );
      });
      setState(() {
        _submitting = false;
        _awaitingGateHandoff = true;
      });
    } catch (e) {
      if (!mounted) return;
      _handoffTimeout?.cancel();
      setState(() {
        _submitting = false;
        _awaitingGateHandoff = false;
        _error = _consentErrorMessage(e);
      });
    }
  }

  String _consentErrorMessage(Object e) {
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') {
        return 'Could not send the request (blocked by server rules). '
            'Go back to date of birth, tap Continue again so it saves, then return here. '
            'If this keeps happening, update the app.';
      }
      final m = e.message?.trim();
      if (m != null && m.isNotEmpty) return m;
      return e.code;
    }
    return e.toString().replaceFirst('Bad state: ', '').replaceFirst('Exception: ', '');
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
    return PopScope(
      canPop: Navigator.of(context).canPop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            AppGradientBackground(
              type: GradientType.dob,
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: IconButton(
                                    onPressed: (_submitting ||
                                            _awaitingGateHandoff)
                                        ? null
                                        : _onBack,
                                    icon: const Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      color: Colors.white,
                                      size: 19,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Center(
                                  child: SizedBox(
                                    height: 72,
                                    child: Image.asset(
                                      'assets/BrandLogo/vyooo_white_transparent.png',
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Text(
                                        'VyooO',
                                        style: TextStyle(
                                          color: AppTheme.primary,
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                Text(
                                  widget.previousDenied
                                      ? 'Parent declined last time'
                                      : 'Parent or guardian',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.defaultTextColor,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  widget.previousDenied
                                      ? 'Enter another email or phone for a parent or guardian who can approve your account.'
                                      : 'Because you are under 16, a parent or guardian must approve your VyooO account. Enter their email or mobile number (tap the flag to choose country, same as signing up with phone). They can create a VyooO account when they open the approval link from Settings → Family approvals.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.45,
                                    color: Colors.white.withValues(alpha: 0.82),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                TextField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  autocorrect: false,
                                  style: const TextStyle(color: Colors.white),
                                  decoration:
                                      _decoration('Parent email (optional)'),
                                ),
                                const SizedBox(height: 14),
                                _buildParentPhoneField(),
                                if (_error != null) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: AppColors.brandPink,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: (_submitting ||
                                            _awaitingGateHandoff)
                                        ? null
                                        : _submit,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.buttonBackground,
                                      foregroundColor: AppTheme.buttonTextColor,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                    child: _submitting
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Send request'),
                                  ),
                                ),
                                SizedBox(
                                  height: 8 +
                                      MediaQuery.viewPaddingOf(context)
                                          .bottom,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_awaitingGateHandoff) _buildHandoffOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildHandoffOverlay() {
    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.5),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
                SizedBox(height: 22),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    'Request sent. Opening waiting screen…',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint, {Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
      prefixIcon: prefixIcon,
      prefixIconConstraints: prefixIcon != null
          ? const BoxConstraints(minWidth: 0, minHeight: 0)
          : null,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.brandPink),
      ),
    );
  }
}
