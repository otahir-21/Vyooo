import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../core/widgets/auth/auth_widgets.dart';
import '../../services/find_account_service.dart';
import '../../services/mock_find_account_service.dart';
import 'reset_password_otp_screen.dart';

class FindAccountScreen extends StatefulWidget {
  const FindAccountScreen({super.key, this.findAccountService});

  final FindAccountService? findAccountService;

  @override
  State<FindAccountScreen> createState() => _FindAccountScreenState();
}

class _FindAccountScreenState extends State<FindAccountScreen> {
  final _inputController = TextEditingController();
  final _auth = AuthService();

  bool _isLoading = false;
  String? _errorMessage;

  FindAccountService get _findAccountService =>
      widget.findAccountService ?? MockFindAccountService();

  bool get _canContinue => _inputController.text.trim().isNotEmpty;

  bool get _looksLikeEmail => _inputController.text.trim().contains('@');

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    if (!_canContinue || _isLoading) return;
    final value = _inputController.text.trim();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_looksLikeEmail) {
      final result = await _auth.sendPasswordReset(email: value);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (result.success) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ResetPasswordOTPScreen(emailOrUsername: value),
          ),
        );
      } else {
        setState(
          () => _errorMessage = result.message ?? 'Could not send reset email.',
        );
      }
    } else {
      final result = await _findAccountService.findAccount(value);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (result.found) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ResetPasswordOTPScreen(emailOrUsername: value),
          ),
        );
      } else {
        setState(() => _errorMessage = result.errorMessage ?? 'Account not found');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          AppGradientBackground(
            type: GradientType.auth,
            child: AuthCenteredScrollBody(
              children: [
                AuthScreenHeader(
                  centerAlign: true,
                  titleTextAlign: TextAlign.start,
                  title: 'Find your\naccount',
                  subtitle: 'Enter your Email address or Username',
                  belowSubtitle: [
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () {
                          // TODO: Can't reset your password flow
                        },
                        child: const Text(
                          "Can't reset your password?",
                          style: AppTypography.authAccentLink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                AuthLoginIdentifierField(
                  controller: _inputController,
                  hint: 'Email address or Username',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.xxl),
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: AppTypography.caption.copyWith(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                AuthPrimaryButton(
                  label: 'Continue',
                  isLoading: _isLoading,
                  enabled: _canContinue,
                  onPressed: _onContinue,
                ),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () {
                      // TODO: Find by mobile
                    },
                    child: const Text(
                      'Find by Mobile number instead',
                      style: AppTypography.authSmallBody,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.authDividerBlock),
              ],
            ),
          ),
          Positioned(
            left: 24,
            bottom: 24,
            child: AuthFloatingCircleButton.back(
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
