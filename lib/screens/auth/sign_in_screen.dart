import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/otp_session_service.dart';
import '../../core/theme/app_padding.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_gradient_background.dart';
import 'create_account_screen.dart';
import 'find_account_screen.dart';
import 'verify_code_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _isAppleLoading = false;
  String? _errorMessage;

  final AuthService _auth = AuthService();

  String _maskEmailForDisplay(String email) {
    final t = email.trim();
    final at = t.indexOf('@');
    if (at <= 0 || at >= t.length - 1) return t;
    final local = t.substring(0, at);
    final domain = t.substring(at + 1);
    if (local.length <= 1) return '***@$domain';
    return '${local[0]}${'*' * (local.length - 1)}@$domain';
  }

  bool get _canLogin =>
      _usernameController.text.trim().isNotEmpty &&
      _passwordController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (!_canLogin || _isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await _auth.signInWithEmail(
      email: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.success) {
      final otpResult = await _auth.sendSignupEmailOtp();
      if (!mounted) return;
      if (!otpResult.success) {
        await OtpSessionService().clearOtpRequirement();
        await _auth.signOut();
        if (!mounted) return;
        setState(() {
          _errorMessage = otpResult.message ?? 'Could not send verification code.';
        });
        return;
      }
      final uid = result.user?.uid ?? _auth.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        await OtpSessionService().requireOtpForUid(uid);
      }
      if (!mounted) return;
      final email = _usernameController.text.trim();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerifyCodeScreen(
            maskedEmail: _maskEmailForDisplay(email),
            autoSendOnOpen: false,
          ),
        ),
      );
      return;
    } else {
      setState(() => _errorMessage = result.message ?? 'Login failed');
    }
  }

  Future<void> _onAppleSignIn() async {
    if (_isAppleLoading || _isLoading) return;
    setState(() {
      _isAppleLoading = true;
      _errorMessage = null;
    });
    final result = await _auth.signInWithApple();
    if (!mounted) return;
    setState(() => _isAppleLoading = false);
    if (result.success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (result.message != null && result.message!.isNotEmpty) {
      setState(() => _errorMessage = result.message);
    }
  }

  void _onRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CreateAccountScreen()),
    );
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
              padding: AppPadding.authFormHorizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: AppSpacing.sm),
                  _buildLogo(),
                  SizedBox(
                    height: AppSpacing.xl + AppSpacing.xl + AppSpacing.sm,
                  ),
                  const Text(
                    'Welcome\nBack',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.defaultTextColor,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xl + AppSpacing.md),
                  _buildUsernameField(),
                  AppPadding.sectionGap,
                  _buildPasswordField(),
                  SizedBox(height: AppSpacing.xl - AppSpacing.xs),
                  _buildRememberRow(),
                  SizedBox(height: AppSpacing.xl + AppSpacing.md),
                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                    SizedBox(height: AppSpacing.sm),
                  ],
                  _buildLoginButton(),
                  AppPadding.itemGap,
                  _buildRegisterRedirect(),
                  SizedBox(height: AppSpacing.xl + AppSpacing.sm),
                  _buildDivider(),
                  SizedBox(height: AppSpacing.xl - AppSpacing.xs),
                  _buildSocialIcons(),
                  SizedBox(height: AppSpacing.xl + AppSpacing.sm),
                ],
              ),
            ),
          ),
        ),
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

  Widget _buildUsernameField() {
    return TextFormField(
      controller: _usernameController,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(
        color: AppTheme.defaultTextColor,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      decoration: const InputDecoration(
        hintText: 'Email',
        prefixIcon: Icon(Icons.mail_outline, color: AppTheme.primary, size: 22),
        suffixIconConstraints: BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      onChanged: (_) => setState(() {}),
      obscureText: _obscurePassword,
      style: const TextStyle(
        color: AppTheme.defaultTextColor,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        hintText: 'Password',
        prefixIcon: const Icon(
          Icons.lock_outline,
          color: AppTheme.primary,
          size: 22,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: AppTheme.primary,
            size: 22,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          style: IconButton.styleFrom(
            minimumSize: const Size(40, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
      ),
    );
  }

  Widget _buildRememberRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _rememberMe,
                onChanged: (v) => setState(() => _rememberMe = v ?? false),
                activeColor: AppTheme.primary,
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected))
                    return AppTheme.primary;
                  return Colors.transparent;
                }),
                side: const BorderSide(color: AppTheme.primary),
                shape: const CircleBorder(),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Remember me',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.primary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const FindAccountScreen(),
              ),
            );
          },
          child: const Text(
            'Forgot Password?',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: (_canLogin && !_isLoading) ? _onLogin : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.buttonBackground,
          foregroundColor: AppTheme.buttonTextColor,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.4),
          disabledForegroundColor: AppTheme.secondaryTextColor,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
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
                'Login',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildRegisterRedirect() {
    return Center(
      child: GestureDetector(
        onTap: _onRegister,
        child: const Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.primary,
              fontWeight: FontWeight.w400,
            ),
            children: [
              TextSpan(text: "Don't have an account? "),
              TextSpan(
                text: 'Register Here',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: White24.value)),
        Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.storyItem,
            right: AppSpacing.storyItem,
          ),
          child: const Text(
            'Or sign in with',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.primary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: White24.value)),
      ],
    );
  }

  Widget _buildSocialIcons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FaIcon(FontAwesomeIcons.google, color: AppTheme.primary, size: 28),
        const SizedBox(width: 40),
        GestureDetector(
          onTap: _onAppleSignIn,
          child: _isAppleLoading
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
                  ),
                )
              : const FaIcon(
                  FontAwesomeIcons.apple,
                  color: AppTheme.primary,
                  size: 28,
                ),
        ),
        const SizedBox(width: 40),
        FaIcon(FontAwesomeIcons.facebook, color: AppTheme.primary, size: 28),
      ],
    );
  }
}
