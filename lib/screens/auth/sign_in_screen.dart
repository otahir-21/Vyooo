import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';

import '../../core/models/saved_account.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/otp_session_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../core/widgets/auth/auth_widgets.dart';
import '../../core/wrappers/auth_wrapper.dart';
import 'create_account_screen.dart';
import 'find_account_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.addingAccount = false});

  /// When true, user is adding another account without removing saved ones.
  final bool addingAccount;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  static const _loginMethodEmail = 'email';
  static const _loginMethodPhone = 'phone';

  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = AuthService();

  bool _rememberMe = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  String? _errorMessage;
  String _selectedLoginMethod = _loginMethodPhone;
  String _selectedCountryDialCode = '44';
  String _selectedCountryFlag = '🇬🇧';

  bool get _isEmailLogin => _selectedLoginMethod == _loginMethodEmail;

  bool get _canLogin =>
      _isEmailLogin
          ? (_usernameController.text.trim().isNotEmpty &&
              _passwordController.text.trim().isNotEmpty)
          : (_normalizedPhone().isNotEmpty &&
              _passwordController.text.trim().isNotEmpty);

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onFieldChanged(_) => setState(() {});

  Future<void> _onLogin() async {
    if (!_isEmailLogin) {
      await _onPhoneLogin();
      return;
    }
    if (!_canLogin || _isLoading) return;
    final otpSession = OtpSessionService();
    otpSession.startEmailLoginHandshake();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final identifier = _usernameController.text.trim();
    final resolvedEmail = await UserService().resolveEmailForLoginIdentifier(
      identifier,
    );
    if (!mounted) return;
    if (resolvedEmail == null || resolvedEmail.isEmpty) {
      otpSession.abortEmailLoginHandshake();
      setState(() {
        _isLoading = false;
        _errorMessage =
            'No account found with this email/username/name. Usernames are case-sensitive.';
      });
      return;
    }
    final result = await _auth.signInWithEmail(
      email: resolvedEmail,
      password: _passwordController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.success) {
      final uid = result.user?.uid ?? '';
      await otpSession.clearOtpRequirement();
      if (uid.isNotEmpty) {
        await otpSession.markTrustedDeviceForUid(uid);
      } else {
        otpSession.abortEmailLoginHandshake();
      }
      await _auth.registerLoggedInAccount(
        loginType: SavedAccountLoginType.password,
        email: resolvedEmail,
        password: _passwordController.text.trim(),
      );
      if (!mounted) return;
      _finishSuccessfulLogin();
      return;
    }
    otpSession.abortEmailLoginHandshake();
    final raw = result.message ?? 'Login failed';
    setState(() {
      _errorMessage = _emailLoginFailureMessage(raw, identifier);
    });
  }

  Future<void> _onPhoneLogin() async {
    if (!_canLogin || _isLoading) return;
    final phone = _normalizedPhone();
    if (phone.isEmpty || !phone.startsWith('+') || phone.length < 8) {
      setState(() => _errorMessage = 'Please enter a valid phone number.');
      return;
    }
    if (_passwordController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your password.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    var resolvedEmail = await UserService().resolveEmailForPhone(phone);
    resolvedEmail ??= _emailForPhoneLogin(phone);
    if (!mounted) return;
    if (resolvedEmail.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No account found with this phone number. If you are a '
            'parent or guardian, create a Vyooo account with this number first '
            '(same number your child entered), then sign in.';
      });
      return;
    }
    final result = await _auth.signInWithEmail(
      email: resolvedEmail,
      password: _passwordController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.success) {
      OtpSessionService().abortEmailLoginHandshake();
      await OtpSessionService().clearOtpRequirement();
      await _auth.registerLoggedInAccount(
        loginType: SavedAccountLoginType.password,
        email: resolvedEmail,
        password: _passwordController.text.trim(),
      );
      if (!mounted) return;
      _finishSuccessfulLogin();
      return;
    }
    setState(() => _errorMessage = result.message ?? 'Login failed');
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
      await _auth.registerLoggedInAccount(
        loginType: SavedAccountLoginType.apple,
      );
      if (!mounted) return;
      _finishSuccessfulLogin();
    } else if (result.message != null && result.message!.isNotEmpty) {
      setState(() => _errorMessage = result.message);
    }
  }

  Future<void> _onGoogleSignIn() async {
    if (_isGoogleLoading || _isAppleLoading || _isLoading) return;
    OtpSessionService().abortEmailLoginHandshake();
    await OtpSessionService().clearOtpRequirement();
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });
    final result = await _auth.signInWithGoogle();
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);
    if (result.success) {
      await _auth.registerLoggedInAccount(
        loginType: SavedAccountLoginType.google,
      );
      if (!mounted) return;
      _finishSuccessfulLogin();
    } else if (result.message != null && result.message!.isNotEmpty) {
      setState(() => _errorMessage = result.message);
    }
  }

  void _finishSuccessfulLogin() {
    if (widget.addingAccount) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _onRegister() {
    final raw = _usernameController.text.trim();
    final initialEmail =
        raw.contains('@') && !raw.startsWith('@') ? raw.toLowerCase() : null;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateAccountScreen(initialEmail: initialEmail),
      ),
    );
  }

  static const _kNoAuthAccountForEmail = 'No account found.';

  String _emailLoginFailureMessage(String base, String identifierTrimmed) {
    final looksLikeEmail =
        identifierTrimmed.contains('@') && !identifierTrimmed.startsWith('@');
    if (!looksLikeEmail) return base;
    if (base == _kNoAuthAccountForEmail) {
      return 'This email is not registered on Vyooo yet. If you are a parent or '
          'guardian responding to a consent request, tap Register Here and create '
          'an account using the same email your child entered, then sign in here.';
    }
    if (base.startsWith('Invalid email or password')) {
      return '$base If you have never signed up, use Register Here first (parents: '
          'use the same email your child used).';
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.authFlow,
        child: AuthCenteredScrollBody(
          children: [
            AuthScreenHeader(
              centerAlign: true,
              titleTextAlign: TextAlign.start,
              title: widget.addingAccount ? 'Add\nAccount' : 'Welcome\nBack',
            ),
            const SizedBox(height: AppSpacing.md),
            AuthSegmentedToggle(
                leftLabel: 'Phone',
                rightLabel: 'Email',
                isLeftSelected: !_isEmailLogin,
                onLeftTap: () =>
                    setState(() => _selectedLoginMethod = _loginMethodPhone),
                onRightTap: () =>
                    setState(() => _selectedLoginMethod = _loginMethodEmail),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _buildForm(),
              const SizedBox(height: AppSpacing.xl - AppSpacing.xs),
              AuthRememberForgotRow(
                rememberMe: _rememberMe,
                onRememberMeChanged: (v) => setState(() => _rememberMe = v),
                onForgotPasswordTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FindAccountScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl + AppSpacing.md),
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: AppTypography.caption.copyWith(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              AuthPrimaryButton(
                label: _isEmailLogin ? 'Login' : 'Continue',
                isLoading: _isLoading,
                enabled: _canLogin,
                onPressed: _onLogin,
              ),
              const SizedBox(height: AppSpacing.md),
              AuthLinkPrompt(
                prompt: "Don't have an account? ",
                actionLabel: 'Register Here',
                onActionTap: _onRegister,
              ),
              const SizedBox(height: AppSpacing.authDividerBlock),
              const AuthLabeledDivider(label: 'Or sign in with'),
              const SizedBox(height: AppSpacing.authDividerBlock),
              AuthSocialSignInRow(
                isGoogleLoading: _isGoogleLoading,
                isAppleLoading: _isAppleLoading,
                onGoogleTap: _onGoogleSignIn,
                onAppleTap: _onAppleSignIn,
              ),
              const SizedBox(height: AppSpacing.authDividerBlock),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return AuthFieldColumn(
      children: [
        if (_isEmailLogin)
          AuthLoginIdentifierField(
            controller: _usernameController,
            onChanged: _onFieldChanged,
          )
        else
          AuthPhoneField(
            controller: _phoneController,
            countryFlag: _selectedCountryFlag,
            countryDialCode: _selectedCountryDialCode,
            onCountryTap: _pickCountry,
            onChanged: _onFieldChanged,
          ),
        AuthPasswordField(
          controller: _passwordController,
          onChanged: _onFieldChanged,
        ),
      ],
    );
  }

  void _pickCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      favorite: const ['GB', 'AE'],
      countryListTheme: CountryListThemeData(
        backgroundColor: const Color(0xFF12081C),
        textStyle: const TextStyle(color: Colors.white),
        inputDecoration: InputDecoration(
          labelText: 'Search country',
          labelStyle: TextStyle(color: AppTheme.secondaryTextColor),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: White24.value),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppTheme.primary),
          ),
        ),
      ),
      onSelect: (Country c) {
        if (!mounted) return;
        setState(() {
          _selectedCountryDialCode = c.phoneCode;
          _selectedCountryFlag = c.flagEmoji;
        });
      },
    );
  }

  String _normalizedPhone() {
    final raw = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.isEmpty) return '';
    final local = raw.startsWith('0') ? raw.substring(1) : raw;
    return '+$_selectedCountryDialCode$local';
  }

  String _emailForPhoneLogin(String phone) {
    final normalized = phone.toLowerCase().trim();
    if (normalized.isEmpty) return '';
    final safe = normalized.replaceAll(RegExp(r'[^a-z0-9+]'), '');
    return '${safe.replaceAll('+', 'p')}-phone@vyooo.app';
  }
}
