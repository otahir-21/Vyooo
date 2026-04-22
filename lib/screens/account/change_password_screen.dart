import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/app_gradient_background.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  String? _currentPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;

  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitChangePassword() async {
    if (_isSubmitting) return;
    final current = _currentPasswordController.text;
    final next = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (!_validateInputs(current: current, next: next, confirm: confirm)) {
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await AuthService().changePassword(
      currentPassword: current,
      newPassword: next,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success) {
      _showMessage('Password changed successfully.');
      Navigator.of(context).pop();
      return;
    }
    if (result.message == 'Your current password is not correct.') {
      setState(() => _currentPasswordError = result.message);
      return;
    }
    _showMessage(result.message ?? 'Could not change password. Please try again.');
  }

  bool _validateInputs({
    required String current,
    required String next,
    required String confirm,
  }) {
    String? currentError;
    String? newError;
    String? confirmError;

    if (current.isEmpty) {
      currentError = 'Please enter your current password.';
    }
    if (next.isEmpty) {
      newError = 'Please enter a new password.';
    } else if (next.length < 8) {
      newError = 'New password must be at least 8 characters.';
    } else {
      final hasSpecial = RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\[\]\\\/]').hasMatch(next);
      if (!hasSpecial) {
        newError = 'Must contain at least one special character.';
      } else if (current.isNotEmpty && current == next) {
        newError = 'New password must be different from current password.';
      }
    }
    if (confirm.isEmpty) {
      confirmError = 'Please confirm your new password.';
    } else if (next != confirm) {
      confirmError = 'Passwords do not match.';
    }

    setState(() {
      _currentPasswordError = currentError;
      _newPasswordError = newError;
      _confirmPasswordError = confirmError;
    });
    return currentError == null && newError == null && confirmError == null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        type: GradientType.profile,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAppBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      const Text(
                        'Change\npassword',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          height: 1.05,
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Your new password should be 8 characters long and\nmust contain one special character.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 48),
                      _buildPasswordField(
                        'Current Password',
                        _currentPasswordController,
                        _obscureCurrent,
                        (val) => setState(() => _obscureCurrent = val),
                        errorText: _currentPasswordError,
                        onChanged: () {
                          if (_currentPasswordError != null) {
                            setState(() => _currentPasswordError = null);
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildPasswordField(
                        'New Password',
                        _newPasswordController,
                        _obscureNew,
                        (val) => setState(() => _obscureNew = val),
                        errorText: _newPasswordError,
                        onChanged: () {
                          if (_newPasswordError != null || _confirmPasswordError != null) {
                            setState(() {
                              _newPasswordError = null;
                              _confirmPasswordError = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildPasswordField(
                        'Confirm Password',
                        _confirmPasswordController,
                        _obscureConfirm,
                        (val) => setState(() => _obscureConfirm = val),
                        errorText: _confirmPasswordError,
                        onChanged: () {
                          if (_confirmPasswordError != null) {
                            setState(() => _confirmPasswordError = null);
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () {},
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                      Center(
                        child: SizedBox(
                          width: 250,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitChangePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              minimumSize: const Size(double.infinity, 54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(27),
                              ),
                              elevation: 0,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Text(
                                    'Change Password',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
          ),
          const Expanded(
            child: Text(
              'Login & Security',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const Text(
            'VyooO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(
    String hint,
    TextEditingController controller,
    bool obscure,
    ValueChanged<bool> onToggle, {
    String? errorText,
    required VoidCallback onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1.0,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            onChanged: (_) => onChanged(),
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 20, right: 12),
                child: Icon(
                  Icons.lock_rounded,
                  color: Color(0xFFF81945),
                  size: 20,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 40),
              suffixIcon: IconButton(
                onPressed: () => onToggle(!obscure),
                icon: Icon(
                  obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 20,
                ),
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              errorText,
              style: const TextStyle(
                color: Color(0xFFF56A79),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
