import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_gradient_background.dart';
import 'sign_in_screen.dart';
import 'verify_code_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  final AuthService _auth = AuthService();

  static const double _horizontalPadding = 28;
  static const double _logoHeight = 50;
  static const double _spacingBelowLogo = 60;
  static const double _titleFontSize = 38;
  static const double _spacingBelowTitle = 40;
  static const double _inputFontSize = 16;
  static const double _spacingBetweenFields = 24;
  static const double _buttonHeight = 56;
  static const double _buttonRadius = 30;
  static const double _spacingAboveButton = 50;
  static const double _spacingAboveSignIn = 16;
  static const double _dividerSpacing = 30;
  static const double _socialIconSize = 28;
  static const double _socialIconSpacing = 40;
  static const double _bottomSpacing = 30;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top: centered logo
                const SizedBox(height: 8),
                _buildLogo(),
                const SizedBox(height: _spacingBelowLogo),

                // Title
                Text(
                  'Create an\nAccount',
                  style: const TextStyle(
                    color: AppTheme.defaultTextColor,
                    fontSize: _titleFontSize,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: _spacingBelowTitle),

                // Inputs
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUnderlineField(
                        controller: _nameController,
                        icon: Icons.person_outline,
                        hint: 'Name',
                        keyboardType: TextInputType.name,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: _spacingBetweenFields),
                      _buildUnderlineField(
                        controller: _emailController,
                        icon: Icons.mail_outline,
                        hint: 'Email',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: _spacingBetweenFields),
                      _buildUnderlineField(
                        controller: _passwordController,
                        icon: Icons.lock_outline,
                        hint: 'Password',
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppTheme.primary,
                            size: 22,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          style: IconButton.styleFrom(
                            minimumSize: const Size(40, 40),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                      const SizedBox(height: _spacingBetweenFields),
                      _buildUnderlineField(
                        controller: _confirmPasswordController,
                        icon: Icons.lock_outline,
                        hint: 'Confirm Password',
                        obscureText: _obscureConfirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppTheme.primary,
                            size: 22,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          style: IconButton.styleFrom(
                            minimumSize: const Size(40, 40),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ],
                const SizedBox(height: _spacingAboveButton),

                // Register button (full width, centered in column)
                SizedBox(
                  width: double.infinity,
                  height: _buttonHeight,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _onRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.buttonBackground,
                      foregroundColor: AppTheme.buttonTextColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_buttonRadius),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.black,
                              ),
                            ),
                          )
                        : const Text(
                            'Register',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: _spacingAboveSignIn),

                // Already have account
                Center(
                  child: GestureDetector(
                    onTap: _onSignIn,
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.secondaryTextColor,
                          fontWeight: FontWeight.w400,
                        ),
                        children: [
                          TextSpan(text: 'Already have an account? '),
                          TextSpan(
                            text: 'Sign in',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: _dividerSpacing),

                // Divider: — Or sign up with —
                Row(
                  children: [
                    Expanded(child: Container(height: 1, color: White24.value)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Or sign up with',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.hintTextColor,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    Expanded(child: Container(height: 1, color: White24.value)),
                  ],
                ),
                const SizedBox(height: _dividerSpacing),

                // Social icons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSocialIcon(FontAwesomeIcons.google),
                    const SizedBox(width: _socialIconSpacing),
                    _buildSocialIcon(FontAwesomeIcons.apple),
                    const SizedBox(width: _socialIconSpacing),
                    _buildSocialIcon(FontAwesomeIcons.facebook),
                  ],
                ),
                const SizedBox(height: _bottomSpacing),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: SizedBox(
        height: _logoHeight,
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

  Widget _buildUnderlineField({
    TextEditingController? controller,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(
        color: AppTheme.defaultTextColor,
        fontSize: _inputFontSize,
        fontWeight: FontWeight.w400,
      ),
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.primary, size: 22),
        suffixIcon: suffixIcon,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon) {
    return FaIcon(icon, color: AppTheme.primary, size: _socialIconSize);
  }

  Future<void> _onRegister() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    setState(() => _errorMessage = null);
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill in email and password.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }
    if (password.length < 8) {
      setState(() => _errorMessage = 'Password must be at least 8 characters.');
      return;
    }

    setState(() => _isLoading = true);
    final result = await _auth.registerWithEmail(
      email: email,
      password: password,
    );
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.message ?? 'Registration failed.';
      });
      return;
    }
    final user = result.user;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      await UserService().createUserDocument(uid: user.uid, email: email);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Account created but setup failed. Please try again.';
      });
      return;
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const VerifyCodeScreen()));
  }

  void _onSignIn() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SignInScreen()));
  }
}
