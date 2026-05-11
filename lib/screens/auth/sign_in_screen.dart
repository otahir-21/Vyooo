import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:country_picker/country_picker.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/otp_session_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_padding.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_gradient_background.dart';
import 'create_account_screen.dart';
import 'find_account_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  static const String _loginMethodEmail = 'email';
  static const String _loginMethodPhone = 'phone';

  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  String? _errorMessage;
  String _selectedLoginMethod = _loginMethodEmail;
  String _selectedCountryDialCode = '44';
  String _selectedCountryFlag = '🇬🇧';

  final AuthService _auth = AuthService();

  bool get _canLogin =>
      _selectedLoginMethod == _loginMethodPhone
          ? (_normalizedPhone().isNotEmpty &&
              _passwordController.text.trim().isNotEmpty)
          : (_usernameController.text.trim().isNotEmpty &&
              _passwordController.text.trim().isNotEmpty);

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (_selectedLoginMethod == _loginMethodPhone) {
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
      final trusted = uid.isNotEmpty
          ? await otpSession.isTrustedDeviceForUid(uid)
          : false;
      if (uid.isNotEmpty && !trusted) {
        await otpSession.requireOtpForUid(uid);
      } else {
        await otpSession.clearOtpRequirement();
        if (uid.isNotEmpty) {
          await otpSession.markTrustedDeviceForUid(uid);
        } else {
          otpSession.abortEmailLoginHandshake();
        }
      }
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    } else {
      otpSession.abortEmailLoginHandshake();
      setState(() => _errorMessage = result.message ?? 'Login failed');
    }
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
        _errorMessage = 'No account found with this phone number.';
      });
      return;
    }
    final result = await _auth.signInWithEmail(
      email: resolvedEmail,
      password: _passwordController.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
    if (result.success) {
      OtpSessionService().abortEmailLoginHandshake();
      await OtpSessionService().clearOtpRequirement();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
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
      Navigator.of(context).popUntil((route) => route.isFirst);
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
                  SizedBox(height: AppSpacing.lg),
                  _buildLoginMethodToggle(),
                  SizedBox(height: AppSpacing.xl + AppSpacing.md),
                  if (_selectedLoginMethod == _loginMethodEmail) ...[
                    _buildUsernameField(),
                    AppPadding.sectionGap,
                    _buildPasswordField(),
                    SizedBox(height: AppSpacing.xl - AppSpacing.xs),
                    _buildRememberRow(),
                  ] else ...[
                    _buildPhoneField(),
                    AppPadding.sectionGap,
                    _buildPasswordField(),
                    SizedBox(height: AppSpacing.xl - AppSpacing.xs),
                    _buildRememberRow(),
                  ],
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
        height: 100,
        child: Image.asset(
          'assets/BrandLogo/vyooo_white_transparent.png',
          fit: BoxFit.contain,
          errorBuilder: (_, error, stackTrace) => const Text(
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
        hintText: 'Email, Username or Name',
        prefixIcon: Icon(Icons.mail_outline, color: AppTheme.primary, size: 22),
        suffixIconConstraints: BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(
        color: AppTheme.defaultTextColor,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        hintText: 'Phone Number',
        prefixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.phone_outlined, color: AppTheme.primary, size: 22),
            const SizedBox(width: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _pickCountry,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                child: Text(
                  '$_selectedCountryFlag +$_selectedCountryDialCode',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
          ],
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
    );
  }

  Widget _buildLoginMethodToggle() {
    final isEmail = _selectedLoginMethod == _loginMethodEmail;
    return Container(
      height: 54,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedLoginMethod = _loginMethodEmail),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isEmail ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Text(
                  'Email',
                  style: TextStyle(
                    color: isEmail
                        ? Colors.black.withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.82),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedLoginMethod = _loginMethodPhone),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isEmail ? Colors.transparent : Colors.white,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Text(
                  'Phone',
                  style: TextStyle(
                    color: isEmail
                        ? Colors.white.withValues(alpha: 0.82)
                        : Colors.black.withValues(alpha: 0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
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
                  if (states.contains(WidgetState.selected)) {
                    return AppTheme.primary;
                  }
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
            : Text(
                _selectedLoginMethod == _loginMethodPhone ? 'Continue' : 'Login',
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
    Widget iconFrame(Widget child) {
      return SizedBox(
        width: 28,
        height: 28,
        child: Center(child: child),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _onGoogleSignIn,
          child: _isGoogleLoading
              ? iconFrame(
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  ),
                )
              : iconFrame(
                  const FaIcon(
                    FontAwesomeIcons.google,
                    color: AppTheme.primary,
                    size: 24,
                  ),
                ),
        ),
        const SizedBox(width: 40),
        GestureDetector(
          onTap: _onAppleSignIn,
          child: _isAppleLoading
              ? iconFrame(
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  ),
                )
              : iconFrame(
                  const FaIcon(
                    FontAwesomeIcons.apple,
                    color: AppTheme.primary,
                    size: 26,
                  ),
                ),
        ),
        const SizedBox(width: 40),
        iconFrame(
          const FaIcon(
            FontAwesomeIcons.facebook,
            color: AppTheme.primary,
            size: 24,
          ),
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
