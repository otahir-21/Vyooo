import 'package:country_picker/country_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/parent_consent_constants.dart';
import '../../core/onboarding/parental_submit_handoff.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/parental_consent_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_theme.dart' show AppTheme, White24;
import '../../core/utils/dob_validation.dart';
import '../../core/widgets/app_gradient_background.dart';

/// Collects parent/guardian contact so a minor can send a consent request.
///
/// After a successful Firestore batch, [ParentalSubmitHandoff] drives the gate to
/// [ParentalPendingScreen] immediately so we do not depend on snapshot stream latency.
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
  final GlobalKey _errorScrollKey = GlobalKey();
  /// Same defaults as [CreateAccountScreen] phone signup.
  String _selectedCountryDialCode = '44';
  String _selectedCountryFlag = '🇬🇧';
  bool _submitting = false;
  String? _error;

  /// Inline error + snackbar + scroll so failures are never silent or off-screen.
  void _presentSubmitError(String message) {
    setState(() {
      _submitting = false;
      _error = message;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(height: 1.35, fontSize: 15),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: AppTheme.primary,
            onPressed: () => messenger.hideCurrentSnackBar(),
          ),
        ),
      );
      final ctx = _errorScrollKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.15,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
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

  /// [OnboardingRouteResolver] can send minors here while Firestore still has
  /// `not_required` / empty gate; [minorParentInviteSubmit] rules require
  /// `pending_contact` on the user doc before the batch runs.
  Future<void> _ensureMinorInviteGateOnServer(String uid) async {
    final user = await UserService().getUser(uid, server: true);
    if (user == null) {
      throw StateError('Could not load your profile. Check your connection and try again.');
    }
    final dobRaw = (user.dob ?? '').trim();
    if (dobRaw.isEmpty || !DobValidation.isValidDobString(dobRaw)) {
      throw StateError('Add your date of birth first, then return here to send the parent request.');
    }
    final birth = DobValidation.tryParseIsoDob(dobRaw)!;
    if (!DobValidation.requiresParentalConsent(birth)) {
      throw StateError('Parent approval is only required if you are under 16.');
    }
    final st = user.parentConsentStatus.trim().toLowerCase();
    if (st == ParentConsentStatusValue.approved) {
      throw StateError('This account is already approved by a parent or guardian.');
    }
    if (st == ParentConsentStatusValue.pending) {
      final cid = user.parentConsentId.trim();
      if (cid.isNotEmpty) {
        throw StateError(
          'A parent request is already in progress. If you still see this form, close and reopen the app.',
        );
      }
    }
    if (st == ParentConsentStatusValue.pendingContact ||
        st == ParentConsentStatusValue.denied) {
      return;
    }
    await UserService().updateUserProfile(
      uid: uid,
      parentConsentStatus: ParentConsentStatusValue.pendingContact,
    );
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
        _presentSubmitError('Set a username first, then try again.');
        return;
      }
      await _ensureMinorInviteGateOnServer(uid);
      if (!mounted) return;
      final id = await ParentalConsentService().createPendingRequest(
        minorUid: uid,
        minorUsername: username,
        parentEmail: _email.text,
        parentPhoneRaw: _normalizedParentPhone(),
      );
      if (!mounted) return;

      // Batch commit succeeded: arm after this frame so [notifyListeners] is not
      // nested inside [ParentContactScreen.setState], and [_UserDocGateState]'s
      // dedicated listener reliably rebuilds to [ParentalPendingScreen].
      setState(() {
        _submitting = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ParentalSubmitHandoff.instance.arm(minorUid: uid, consentId: id);
      });
    } catch (e) {
      if (!mounted) return;
      final message =
          e is StateError ? (e.message) : _consentErrorMessage(e);
      _presentSubmitError(message);
    }
  }

  String _consentErrorMessage(Object e) {
    if (e is FirebaseException) {
      final suffix = kDebugMode ? ' (${e.code})' : '';
      switch (e.code) {
        case 'permission-denied':
          return 'We could not send your parent request because the server rejected it '
              '(missing permission). This is usually fixed by updating VyooO from the '
              'app store. You can also try again in a moment or check your Wi‑Fi / mobile '
              'data. If it keeps happening, contact VyooO support.$suffix';
        case 'unavailable':
        case 'deadline-exceeded':
          return 'The network timed out while sending your request. Check your connection '
              'and tap Send request again.$suffix';
        case 'failed-precondition':
        case 'aborted':
          return 'The request could not be completed. Please try again.$suffix';
        case 'resource-exhausted':
          return 'Too many attempts right now. Wait a minute and try again.$suffix';
        default:
          final m = e.message?.trim();
          if (m != null && m.isNotEmpty) {
            return kDebugMode ? '$m (${e.code})' : m;
          }
          return 'Something went wrong. Please try again.$suffix';
      }
    }
    return e
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '');
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
        body: AppGradientBackground(
              type: GradientType.dob,
              child: SafeArea(
                minimum: const EdgeInsets.only(bottom: 20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final mq = MediaQuery.of(context);
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        28,
                        0,
                        28,
                        // Room below [Send request]: safe area already clears nav bar;
                        // add a fixed gutter plus IME inset when the keyboard is open.
                        32 + mq.viewInsets.bottom,
                      ),
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
                                    onPressed: _submitting ? null : _onBack,
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
                                      : 'Because you are under 16, a parent or guardian must approve your VyooO account. Enter their email or mobile number (tap the flag to choose country, same as signing up with phone). They approve in their VyooO app (Settings → Family approvals); you do not verify them.',
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
                                    key: _errorScrollKey,
                                    _error!,
                                    style: const TextStyle(
                                      color: AppColors.brandPink,
                                      fontSize: 14,
                                      height: 1.4,
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
                                    onPressed: _submitting ? null : _submit,
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
