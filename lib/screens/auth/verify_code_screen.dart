import 'package:flutter/material.dart';

import '../../core/models/saved_account.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/otp_session_service.dart';
import '../../core/services/signup_draft_service.dart';
import '../../core/theme/app_padding.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/wrappers/auth_wrapper.dart';
import '../../core/widgets/auth/auth_widgets.dart';

class VerifyCodeScreen extends StatefulWidget {
  const VerifyCodeScreen({
    super.key,
    this.channel = 'email',
    this.maskedEmail = '',
    this.maskedPhone = '',
    this.phoneNumber = '',
    this.autoSendOnOpen = true,
    this.initialErrorMessage,
    this.forPhoneLogin = false,
  });

  final String channel;
  final String maskedEmail;
  final String maskedPhone;
  final String phoneNumber;
  final bool autoSendOnOpen;
  final String? initialErrorMessage;
  final bool forPhoneLogin;

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  final AuthService _auth = AuthService();
  bool _sendInFlight = false;
  bool _verifyInFlight = false;
  String? _errorMessage;
  late String _activeChannel;
  late String _activePhoneNumber;
  String _phoneVerificationId = '';
  int? _phoneResendToken;

  bool get _usePhone => _activeChannel == 'phone';
  int get _otpLength => _usePhone ? 6 : 4;

  String _activeEmailForOtp() {
    final draftEmail = SignupDraftService().current?.email.trim() ?? '';
    if (draftEmail.isNotEmpty) return draftEmail;
    final userEmail = _auth.currentUser?.email?.trim() ?? '';
    return userEmail;
  }

  @override
  void initState() {
    super.initState();
    _activeChannel = widget.channel.trim().toLowerCase();
    _activePhoneNumber = widget.phoneNumber.trim();
    _errorMessage = widget.initialErrorMessage?.trim().isNotEmpty == true
        ? widget.initialErrorMessage!.trim()
        : null;
    _controllers = List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());
    if (widget.autoSendOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendOtp());
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthLightScaffold(
      padding: AppPadding.authFormHorizontal,
      stackChildren: [
        AuthFloatingBackButton(
          onPressed: _onBack,
          alwaysShowBack: true,
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.sm),
          const AuthScreenHeader(
            centerAlign: true,
            titleTextAlign: TextAlign.start,
            title: 'Verify\nCode',
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _usePhone
                ? "Please enter the code we've just sent to your number"
                : "Please enter the code we've just sent to email",
            style: AppTypography.authSmallBody.copyWith(
              color: AppTheme.lightMutedBody,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _destinationLabel(),
              style: AppTypography.authAccentLink,
              textAlign: TextAlign.start,
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _errorMessage!,
              style: AppTypography.caption.copyWith(color: Colors.red),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AuthOtpInputRow(
            length: _otpLength,
            controllers: _controllers,
            focusNodes: _focusNodes,
            boxSize: _usePhone ? 48 : AppSizes.authOtpBoxSize,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Column(
              children: [
                Text(
                  "Didn't receive OTP?",
                  style: AppTypography.authSmallBody.copyWith(
                    color: AppTheme.lightMutedBody,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                GestureDetector(
                  onTap: _onResendCode,
                  child: Text(
                    'Resend Code',
                    style: AppTypography.authSmallBodyBold.copyWith(
                      color: AppTheme.lightOnSurface,
                      decoration: TextDecoration.underline,
                      decorationColor: AppTheme.lightOnSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!widget.forPhoneLogin && _usePhone) ...[
            const SizedBox(height: AppSpacing.md),
            Center(
              child: GestureDetector(
                onTap: _onSwitchVerificationMethod,
                child: Text(
                  'Try another way',
                  style: AppTypography.authSmallBody.copyWith(
                    color: AppTheme.lightMutedBody,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.authCtaTop),
          AuthPrimaryButton(
            label: 'Verify',
            isLoading: _verifyInFlight,
            enabled: _isOtpComplete,
            onPressed: _onVerify,
          ),
          SizedBox(height: AuthFloatingNavRow.scrollBottomClearance(context)),
        ],
      ),
    );
  }

  String _destinationLabel() {
    if (_usePhone) {
      return widget.maskedPhone.isEmpty
          ? 'your phone number'
          : widget.maskedPhone;
    }
    return widget.maskedEmail.isEmpty ? 'your email' : widget.maskedEmail;
  }

  bool get _isOtpComplete {
    for (final c in _controllers) {
      if (c.text.isEmpty) return false;
    }
    return true;
  }

  Future<void> _sendOtp() async {
    if (_sendInFlight || !mounted) return;
    SignupDraftService().current;
    setState(() {
      _sendInFlight = true;
      _errorMessage = null;
    });
    final email = _activeEmailForOtp();
    if (!_usePhone && email.isEmpty) {
      setState(() {
        _sendInFlight = false;
        _errorMessage = 'Email is missing. Go back and register again.';
      });
      return;
    }
    final result = _usePhone
        ? await _auth.requestPhoneSignInOtp(
            phoneNumber: _activePhoneNumber,
            forceResendingToken: _phoneResendToken,
            onCodeSent: (verificationId, resendToken) {
              _phoneVerificationId = verificationId;
              _phoneResendToken = resendToken;
            },
          )
        : await _auth.sendSignupEmailOtp(email: email);
    if (!mounted) return;
    if (_usePhone &&
        result.success &&
        _phoneVerificationId.trim().isEmpty &&
        _auth.currentUser != null) {
      setState(() => _sendInFlight = false);
      await _finishAfterSuccessfulVerification();
      return;
    }
    setState(() {
      _sendInFlight = false;
      if (!result.success) {
        _errorMessage = result.message ??
            (_usePhone
                ? 'Could not send phone code.'
                : 'Could not send code.');
      }
    });
  }

  void _onResendCode() {
    if (_sendInFlight || _verifyInFlight) return;
    _sendOtp();
  }

  Future<void> _onVerify() async {
    if (!_isOtpComplete || _verifyInFlight) return;
    final code = _controllers.map((c) => c.text).join();
    setState(() {
      _verifyInFlight = true;
      _errorMessage = null;
    });
    final email = _activeEmailForOtp();
    if (!_usePhone && email.isEmpty) {
      setState(() {
        _verifyInFlight = false;
        _errorMessage = 'Email is missing. Go back and register again.';
      });
      return;
    }
    final result = _usePhone
        ? await _auth.verifyPhoneSignInOtp(
            verificationId: _phoneVerificationId,
            smsCode: code,
          )
        : await _auth.verifySignupEmailOtp(code, email: email);
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _verifyInFlight = false;
        _errorMessage = result.message ?? 'Verification failed.';
      });
      return;
    }
    await _finishAfterSuccessfulVerification();
  }

  Future<void> _finishAfterSuccessfulVerification() async {
    try {
      final draft = SignupDraftService().current;
      String? signupEmail;
      String? signupPassword;
      if (draft != null) {
        signupEmail = draft.email.trim();
        signupPassword = draft.password;
        final complete = await _auth.completeSignupAfterOtp(
          name: draft.name,
          email: draft.email,
          password: draft.password,
          phoneNumber: draft.phoneNumber,
        );
        if (!mounted) return;
        if (!complete.success) {
          final raw = (complete.message ?? '').trim();
          final friendly = raw.toLowerCase().contains('try again in a moment')
              ? 'Could not verify account right now. Please tap Resend Code and try again.'
              : (raw.isEmpty ? 'Could not finalize account.' : raw);
          setState(() {
            _verifyInFlight = false;
            _errorMessage = friendly;
          });
          return;
        }
        SignupDraftService().clear();
      }
      final currentUid = _auth.currentUser?.uid ?? '';
      if (currentUid.isNotEmpty) {
        await OtpSessionService().markTrustedDeviceForUid(currentUid);
      }
      if (signupEmail != null &&
          signupEmail.isNotEmpty &&
          signupPassword != null &&
          signupPassword.isNotEmpty) {
        await _auth.registerLoggedInAccount(
          loginType: SavedAccountLoginType.password,
          email: signupEmail,
          password: signupPassword,
        );
      }
      await OtpSessionService().clearOtpRequirement();
      await OtpSessionService().clearSignupOtpPreference();
      setState(() => _verifyInFlight = false);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verifyInFlight = false;
        _errorMessage =
            'Could not verify account right now. Please tap Resend Code and try again.';
      });
    }
  }

  Future<void> _onSwitchVerificationMethod() async {
    if (_verifyInFlight || _sendInFlight) return;
    if (!_usePhone) return;
    final target = 'email';
    final prefs = OtpSessionService();
    final draft = SignupDraftService().current;
    final destination = (draft?.email ?? _auth.currentUser?.email ?? '');
    await prefs.setSignupOtpPreference(
      channel: target,
      destination: destination,
    );
    if (!mounted) return;
    setState(() {
      _activeChannel = target;
      _errorMessage = null;
      for (final c in _controllers) {
        c.clear();
      }
    });
  }

  Future<void> _onBack() async {
    if (_verifyInFlight) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    final embeddedInAuthWrapper =
        context.findAncestorWidgetOfExactType<AuthWrapper>() != null;
    SignupDraftService().clear();
    final otpSession = OtpSessionService();
    otpSession.abortEmailLoginHandshake();
    await otpSession.clearSignupOtpPreference();
    await otpSession.clearOtpRequirement();
    await _auth.signOut();
    if (!mounted) return;
    if (!embeddedInAuthWrapper) {
      await nav.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    }
  }
}
