import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/otp_session_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_gradient_background.dart';

class VerifyCodeScreen extends StatefulWidget {
  const VerifyCodeScreen({
    super.key,
    this.maskedEmail = '',
    this.autoSendOnOpen = true,
  });

  final String maskedEmail;
  final bool autoSendOnOpen;

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  static const int _otpLength = 4;
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  final AuthService _auth = AuthService();
  bool _sendInFlight = false;
  bool _verifyInFlight = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
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
                  const SizedBox(height: 20),
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
                  const Text(
                    "Please enter the code we've just sent to email",
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.secondaryTextColor,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.maskedEmail.isEmpty ? 'your email' : widget.maskedEmail,
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
                        onPressed: _isOtpComplete && !_verifyInFlight ? _onVerify : null,
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
                  Center(
                    child: GestureDetector(
                      onTap: _onTryAnotherWay,
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
        height: 50,
        child: Image.asset(
          'assets/BrandLogo/Vyooo logo (2).png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Text(
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
      builder: (_, __) {
        final hasFocus = _focusNodes[index].hasFocus;
        return Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: hasFocus
                ? Border.all(color: Colors.white.withOpacity(0.4), width: 1.5)
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
                color: AppTheme.primary.withOpacity(0.5),
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
    setState(() {
      _sendInFlight = true;
      _errorMessage = null;
    });
    final result = await _auth.sendSignupEmailOtp();
    if (!mounted) return;
    setState(() {
      _sendInFlight = false;
      if (!result.success) {
        _errorMessage = result.message ?? 'Could not send code.';
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
    final result = await _auth.verifySignupEmailOtp(code);
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _verifyInFlight = false;
        _errorMessage = result.message ?? 'Verification failed.';
      });
      return;
    }
    await OtpSessionService().clearOtpRequirement();
    setState(() => _verifyInFlight = false);
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _onTryAnotherWay() async {
    if (_verifyInFlight) return;
    await _auth.signOut();
    // AuthWrapper shows CreateAccountScreen when signed out.
  }
}
