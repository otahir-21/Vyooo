import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_padding.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/password_validation.dart';
import '../../core/widgets/auth/auth_widgets.dart';
import 'password_updated_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.emailOrUsername, this.oobCode});

  final String? emailOrUsername;
  final String? oobCode;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _auth = AuthService();

  bool _isLoading = false;
  String? _errorMessage;

  bool get _passwordsMatch =>
      _passwordController.text == _confirmController.text &&
      _confirmController.text.isNotEmpty;

  bool get _isValid =>
      PasswordValidation.isStrong(_passwordController.text) && _passwordsMatch;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
    _confirmController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    if (!_isValid || _isLoading) return;
    final oobCode = widget.oobCode?.trim();
    if (oobCode == null || oobCode.isEmpty) {
      setState(
        () => _errorMessage =
            'Reset link required. Please use the link from your email.',
      );
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await _auth.confirmPasswordReset(
      oobCode: oobCode,
      newPassword: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.success) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PasswordUpdatedScreen()),
      );
    } else {
      setState(
        () => _errorMessage = result.message ?? 'Could not reset password.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            title: 'Reset\npassword',
            subtitle: 'Please enter your new password',
          ),
          const SizedBox(height: AppSpacing.md),
          AuthPasswordField(controller: _passwordController, hint: 'New password'),
          const SizedBox(height: AppSpacing.md),
          _buildValidationChecklist(),
          const SizedBox(height: AppSpacing.xl),
          AuthPasswordField(
            controller: _confirmController,
            hint: 'Confirm Password',
          ),
          if (_confirmController.text.isNotEmpty && !_passwordsMatch) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Passwords do not match',
              style: AppTypography.caption.copyWith(color: Colors.red),
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _errorMessage!,
              style: AppTypography.caption.copyWith(color: Colors.red),
            ),
          ],
          const SizedBox(height: AppSpacing.authCtaTop),
          AuthPrimaryButton(
            label: 'Continue',
            isLoading: _isLoading,
            enabled: _isValid,
            onPressed: _onContinue,
          ),
          SizedBox(height: AuthFloatingNavRow.scrollBottomClearance(context)),
        ],
      ),
    );
  }

  Widget _buildValidationChecklist() {
    final password = _passwordController.text;
    final minLengthOk = PasswordValidation.hasMinLength(password);
    final specialOk = PasswordValidation.hasSpecialCharacter(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCheckItem('At least 8 characters', minLengthOk),
        const SizedBox(height: AppSpacing.sm),
        _buildCheckItem('Contains a special character', specialOk),
      ],
    );
  }

  Widget _buildCheckItem(String label, bool met) {
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle : Icons.circle_outlined,
          size: 18,
          color: met ? Colors.green : AppTheme.lightSecondaryText,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: met ? Colors.green : AppTheme.lightMutedBody,
          ),
        ),
      ],
    );
  }
}
