import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/otp_session_service.dart';
import '../../core/services/signup_draft_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/wrappers/auth_wrapper.dart';
import '../../core/widgets/app_gradient_background.dart';

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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.auth,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: _onBack,
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                      tooltip: 'Back',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildLogo(),
                  const SizedBox(height: 60),
                  const Text(
                    'Verify Code',
                    style: TextStyle(
                      color: AppTheme.defaultTextColor,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _usePhone
                        ? "Please enter the code we've just sent to your number"
                        : "Please enter the code we've just sent to email",
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.secondaryTextColor,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _usePhone
                        ? (widget.maskedPhone.isEmpty
                              ? 'your phone number'
                              : widget.maskedPhone)
                        : (widget.maskedEmail.isEmpty
                              ? 'your email'
                              : widget.maskedEmail),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFD10057),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(_otpLength, (i) => _buildOtpBox(i)),
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          "Didn't receive OTP?",
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.secondaryTextColor,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _onResendCode,
                          child: const Text(
                            'Resend Code',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                              decorationColor: AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isOtpComplete && !_verifyInFlight
                            ? _onVerify
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.buttonBackground,
                          foregroundColor: AppTheme.buttonTextColor,
                          disabledBackgroundColor: Colors.white.withValues(
                            alpha: 0.4,
                          ),
                          disabledForegroundColor: AppTheme.secondaryTextColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _verifyInFlight
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.buttonTextColor,
                                ),
                              )
                            : const Text(
                                'Verify',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!widget.forPhoneLogin && _usePhone)
                    Center(
                      child: GestureDetector(
                        onTap: _onSwitchVerificationMethod,
                        child: const Text(
                          'Try Another Way',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.secondaryTextColor,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _isOtpComplete {
    for (final c in _controllers) {
      if (c.text.isEmpty) return false;
    }
    return true;
  }

  Widget _buildLogo() {
    return Center(
      child: SizedBox(
        height: 100,
        child: Image.asset(
          'assets/BrandLogo/vyooo_white_transparent.png',
          fit: BoxFit.contain,
          errorBuilder: (_, error, stackTrace) => const Text(
            'VyooO',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 42,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return ListenableBuilder(
      listenable: _focusNodes[index],
      builder: (_, _) {
        final hasFocus = _focusNodes[index].hasFocus;
        return Container(
          width: _usePhone ? 48 : 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: hasFocus
                ? Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5)
                : null,
          ),
          alignment: Alignment.center,
          child: TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            maxLength: 1,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onTap: () {
              // Makes replacing a wrong digit one tap on mobile keyboards.
              _controllers[index].selection = TextSelection(
                baseOffset: 0,
                extentOffset: _controllers[index].text.length,
              );
            },
            onChanged: (value) {
              if (value.isNotEmpty && index < _otpLength - 1) {
                _focusNodes[index + 1].requestFocus();
              }
              if (mounted) setState(() {});
            },
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 32,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: '-',
              hintStyle: TextStyle(
                color: AppTheme.primary.withValues(alpha: 0.5),
                fontSize: 32,
                fontWeight: FontWeight.w600,
              ),
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        );
      },
    );
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
        _errorMessage =
            result.message ??
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
      if (draft != null) {
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
    // [CreateAccountScreen] opens this screen with [pushReplacement], so there is
    // no route to pop and [AuthWrapper] is no longer in the tree. [signOut] alone
    // would not rebuild the UI; reset the root back to [AuthWrapper].
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
