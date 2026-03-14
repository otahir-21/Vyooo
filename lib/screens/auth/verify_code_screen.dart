import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../core/wrappers/auth_wrapper.dart';
import 'create_username_screen.dart';

class _BackspaceIntent extends Intent {
  const _BackspaceIntent();
}

class VerifyCodeScreen extends StatefulWidget {
  const VerifyCodeScreen({
    super.key,
    this.maskedEmail = 'Ada******@gmail.com',
    this.isLoginFlow = false,
  });

  final String maskedEmail;
  final bool isLoginFlow;

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  static const int _otpLength = 4;
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());
    for (int i = 0; i < _otpLength; i++) {
      _controllers[i].addListener(() => _onOtpChanged(i));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _onOtpChanged(int index) {
    final text = _controllers[index].text;
    if (text.length == 1) {
      if (index < _otpLength - 1) {
        _focusNodes[index + 1].requestFocus();
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.auth,
        child: SafeArea(
          child: Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.backspace): _BackspaceIntent(),
            },
            child: Actions(
              actions: {
                _BackspaceIntent: CallbackAction<_BackspaceIntent>(
                  onInvoke: (_) {
                    for (int i = 0; i < _otpLength; i++) {
                      if (_focusNodes[i].hasFocus &&
                          _controllers[i].text.isEmpty &&
                          i > 0) {
                        _focusNodes[i - 1].requestFocus();
                        break;
                      }
                    }
                    return null;
                  },
                ),
              },
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),

                      // Logo
                      _buildLogo(),
                      const SizedBox(height: 60),

                      // Title
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

                      // Subtitle
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

                      // Masked email
                      Text(
                        widget.maskedEmail,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFD10057),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),

                      // OTP boxes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          _otpLength,
                          (i) => _buildOtpBox(i),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Resend section
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

                      // Verify button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isOtpComplete ? _onVerify : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.buttonBackground,
                              foregroundColor: AppTheme.buttonTextColor,
                              disabledBackgroundColor: Colors.white.withValues(
                                alpha: 0.4,
                              ),
                              disabledForegroundColor:
                                  AppTheme.secondaryTextColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
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

                      // Try Another Way
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

  void _onResendCode() {
    // TODO: implement resend OTP
  }

  void _onVerify() {
    if (widget.isLoginFlow) {
      // Route through AuthWrapper so Firestore onboardingCompleted is respected
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
        (route) => false,
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const CreateUsernameScreen()),
      );
    }
  }

  void _onTryAnotherWay() {
    if (widget.isLoginFlow) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pop();
    }
  }
}
