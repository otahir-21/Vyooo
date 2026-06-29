import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_padding.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/auth/auth_widgets.dart';
import 'reset_password_screen.dart';

/// OTP step for password reset — navigates to [ResetPasswordScreen] after verify.
class ResetPasswordOTPScreen extends StatefulWidget {
  const ResetPasswordOTPScreen({
    super.key,
    this.emailOrUsername,
    this.oobCode,
    this.displayPhone,
  });

  final String? emailOrUsername;
  final String? displayPhone;

  /// Code from Firebase password reset email link. Pass through to [ResetPasswordScreen].
  final String? oobCode;

  @override
  State<ResetPasswordOTPScreen> createState() => _ResetPasswordOTPScreenState();
}

class _ResetPasswordOTPScreenState extends State<ResetPasswordOTPScreen> {
  static const _otpLength = 4;

  final _auth = AuthService();
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  bool _verifyInFlight = false;
  bool _resendInFlight = false;
  String? _errorMessage;

  bool get _isEmail =>
      widget.emailOrUsername?.trim().contains('@') ?? false;

  String get _otpCode => _controllers.map((c) => c.text).join();

  bool get _isOtpComplete => _otpCode.length == _otpLength;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());
    final preset = widget.oobCode?.trim();
    if (preset != null && preset.isNotEmpty) {
      _prefillOtp(preset);
    }
  }

  void _prefillOtp(String code) {
    final digits = code.replaceAll(RegExp(r'\D'), '');
    for (var i = 0; i < _otpLength && i < digits.length; i++) {
      _controllers[i].text = digits[i];
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

  String? _maskedDestination() {
    if (widget.displayPhone != null && widget.displayPhone!.trim().isNotEmpty) {
      final phone = widget.displayPhone!.trim();
      if (phone.length <= 4) return phone;
      return '${'*' * (phone.length - 4)}${phone.substring(phone.length - 4)}';
    }
    final raw = widget.emailOrUsername?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (!_isEmail) return raw;
    final at = raw.indexOf('@');
    if (at <= 1) return raw;
    return '${raw[0]}***${raw.substring(at)}';
  }

  Future<void> _onResend() async {
    if (_resendInFlight || !_isEmail) return;
    final email = widget.emailOrUsername!.trim();
    setState(() {
      _resendInFlight = true;
      _errorMessage = null;
    });
    final result = await _auth.sendPasswordReset(email: email);
    if (!mounted) return;
    setState(() {
      _resendInFlight = false;
      if (!result.success) {
        _errorMessage = result.message ?? 'Could not resend code.';
      }
    });
  }

  Future<void> _onVerify() async {
    if (!_isOtpComplete || _verifyInFlight) return;
    final code = _otpCode;

    setState(() {
      _verifyInFlight = true;
      _errorMessage = null;
    });

    final result = await _auth.verifyPasswordResetCode(code);
    if (!mounted) return;
    setState(() => _verifyInFlight = false);

    if (!result.success) {
      setState(() => _errorMessage = result.message ?? 'Invalid code. Try again.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(
          emailOrUsername: widget.emailOrUsername,
          oobCode: code,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destination = _maskedDestination();

    return AuthLightScaffold(
      padding: AppPadding.authFormHorizontal,
      stackChildren: [
        AuthFloatingBackButton(onPressed: () => Navigator.of(context).pop()),
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
            _isEmail
                ? "Please enter the code we've just sent to your email"
                : "Please enter the code we've just sent to your number",
            style: AppTypography.authSmallBody.copyWith(
              color: AppTheme.lightMutedBody,
            ),
          ),
          if (destination != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(destination, style: AppTypography.authAccentLink),
          ],
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
                  onTap: _resendInFlight || !_isEmail ? null : _onResend,
                  child: Text(
                    _resendInFlight ? 'Sending…' : 'Resend Code',
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
}
