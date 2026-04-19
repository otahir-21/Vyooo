import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/password_validation.dart';
import '../../core/widgets/app_gradient_background.dart';
import 'password_updated_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.emailOrUsername, this.oobCode});

  final String? emailOrUsername;

  /// Code from Firebase password reset email link. Required for confirmPasswordReset.
  final String? oobCode;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  static const double _horizontalPadding = 28;

  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
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

  final AuthService _auth = AuthService();

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
        MaterialPageRoute(builder: (context) => const PasswordUpdatedScreen()),
      );
    } else {
      setState(
        () => _errorMessage = result.message ?? 'Could not reset password.',
      );
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
            child: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _horizontalPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildLogo(),
                      const SizedBox(height: 60),
                      const Text(
                        'Reset\npassword',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.defaultTextColor,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Please enter your new password',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.secondaryTextColor,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildPasswordField(),
                      const SizedBox(height: 12),
                      _buildValidationChecklist(),
                      const SizedBox(height: 24),
                      _buildConfirmField(),
                      if (_confirmController.text.isNotEmpty &&
                          !_passwordsMatch) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'Passwords do not match',
                          style: TextStyle(fontSize: 12, color: Colors.red),
                        ),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ],
                      const SizedBox(height: 30),
                      _buildContinueButton(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(right: 24, bottom: 24, child: _buildFloatingButton()),
        ],
      ),
    );
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

  Widget _buildPasswordField() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: AppColors.brandPink, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(
                color: AppTheme.defaultTextColor,
                fontSize: 16,
              ),
              decoration: const InputDecoration(
                hintText: 'New Password',
                hintStyle: TextStyle(color: White50.value, fontSize: 16),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: AppTheme.primary,
              size: 22,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
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
        const SizedBox(height: 6),
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
          color: met ? Colors.green : White40.value,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: met ? Colors.green : White50.value,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmField() {
    final mismatch = _confirmController.text.isNotEmpty && !_passwordsMatch;
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: mismatch ? Border.all(color: Colors.red, width: 1.5) : null,
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: AppColors.brandPink, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _confirmController,
              obscureText: _obscureConfirm,
              style: const TextStyle(
                color: AppTheme.defaultTextColor,
                fontSize: 16,
              ),
              decoration: const InputDecoration(
                hintText: 'Confirm Password',
                hintStyle: TextStyle(color: White50.value, fontSize: 16),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _obscureConfirm ? Icons.visibility_off : Icons.visibility,
              color: AppTheme.primary,
              size: 22,
            ),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: (_isValid && !_isLoading) ? _onContinue : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.buttonBackground,
          foregroundColor: AppTheme.buttonTextColor,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.4),
          disabledForegroundColor: AppTheme.secondaryTextColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              )
            : const Text(
                'Continue',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildFloatingButton() {
    return Material(
      elevation: 2,
      shape: const CircleBorder(),
      color: _isValid
          ? AppTheme.buttonBackground
          : Colors.white.withValues(alpha: 0.4),
      child: InkWell(
        onTap: _isValid && !_isLoading ? _onContinue : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          child: Icon(
            Icons.arrow_forward,
            color: _isValid ? AppTheme.buttonTextColor : White50.value,
            size: 28,
          ),
        ),
      ),
    );
  }
}
