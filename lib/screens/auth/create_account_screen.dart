import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:country_picker/country_picker.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/otp_session_service.dart';
import '../../core/services/signup_draft_service.dart';
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
  static const String _otpChannelEmail = 'email';
  static const String _otpChannelPhone = 'phone';
  static const String _signupMethodEmail = 'email';
  static const String _signupMethodPhone = 'phone';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  String? _errorMessage;
  String _selectedCountryDialCode = '44';
  String _selectedCountryFlag = '🇬🇧';
  String _selectedSignupMethod = _signupMethodEmail;

  final AuthService _auth = AuthService();

  static const double _horizontalPadding = 28;
  static const double _titleFontSize = 48;
  static const double _spacingBelowTitle = 40;
  static const double _inputFontSize = 16;
  static const double _spacingBetweenFields = 24;
  static const double _buttonHeight = 56;
  static const double _buttonRadius = 30;
  static const double _spacingAboveButton = 50;
  static const double _spacingAboveSignIn = 16;
  static const double _dividerSpacing = 30;
  static const double _socialIconSize = 24;
  static const double _socialIconContainerSize = 40;
  static const double _socialIconSpacing = 40;
  static const double _bottomSpacing = 30;

  @override
  void initState() {
    super.initState();
    _phoneFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _phoneController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _phoneFocusNode.dispose();
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
                const SizedBox(height: 20),
                _buildLogo(),
                // Title
                Text(
                  'Create an\nAccount',
                  style: const TextStyle(
                    color: AppTheme.defaultTextColor,
                    fontSize: _titleFontSize,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 18),
                _buildSignupMethodToggle(),
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
                        controller: _surnameController,
                        icon: Icons.person_outline,
                        hint: 'Surname',
                        keyboardType: TextInputType.name,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: _spacingBetweenFields),
                      if (_selectedSignupMethod == _signupMethodEmail)
                        _buildUnderlineField(
                          controller: _emailController,
                          icon: Icons.mail_outline,
                          hint: 'Email',
                          keyboardType: TextInputType.emailAddress,
                        )
                      else
                        _buildPhoneField(),
                      const SizedBox(height: _spacingBetweenFields),
                      _buildUnderlineField(
                        controller: _passwordController,
                        icon: Icons.lock_outline,
                        hint: 'Password',
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? CupertinoIcons.eye_slash
                                : CupertinoIcons.eye,
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
                                ? CupertinoIcons.eye_slash
                                : CupertinoIcons.eye,
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
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _horizontalPadding,
                  ),
                  child: SizedBox(
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
                                  Colors.white,
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

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      focusNode: _phoneFocusNode,
      style: const TextStyle(
        color: AppTheme.defaultTextColor,
        fontSize: _inputFontSize,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
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

  Widget _buildSignupMethodToggle() {
    final isEmail = _selectedSignupMethod == _signupMethodEmail;
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
              onTap: () => setState(() => _selectedSignupMethod = _signupMethodEmail),
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
              onTap: () => setState(() => _selectedSignupMethod = _signupMethodPhone),
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

  Widget _buildUnderlineField({
    TextEditingController? controller,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    Widget? suffixIcon,
    FocusNode? focusNode,
    VoidCallback? onTap,
    bool showPrefixIcon = true,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      style: const TextStyle(
        color: AppTheme.defaultTextColor,
        fontSize: _inputFontSize,
        fontWeight: FontWeight.w400,
      ),
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      onTap: onTap,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: showPrefixIcon
            ? Icon(icon, color: AppTheme.primary, size: 22)
            : null,
        suffixIcon: suffixIcon,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
      ),
    );
  }

  Widget _buildSocialIcon(FaIconData icon) {
    final isGoogle = icon == FontAwesomeIcons.google;
    final isApple = icon == FontAwesomeIcons.apple;
    return GestureDetector(
      onTap: isGoogle
          ? _onGoogleSignIn
          : isApple
          ? _onAppleSignIn
          : null,
      child: SizedBox(
        width: _socialIconContainerSize,
        height: _socialIconContainerSize,
        child: Center(
          child: (isGoogle && _isGoogleLoading) || (isApple && _isAppleLoading)
              ? SizedBox(
                  width: _socialIconSize,
                  height: _socialIconSize,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
                  ),
                )
              : FaIcon(icon, color: AppTheme.primary, size: _socialIconSize),
        ),
      ),
    );
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

  Future<void> _onRegister() async {
    final typedEmail = _emailController.text.trim();
    final firstName = _nameController.text.trim();
    final surname = _surnameController.text.trim();
    final name = '$firstName $surname'.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    final phone = _normalizedPhone();
    final otpChannel = _selectedSignupMethod == _signupMethodPhone
        ? _otpChannelPhone
        : _otpChannelEmail;
    final email = otpChannel == _otpChannelEmail
        ? typedEmail
        : _emailForPhoneSignup(phone);

    setState(() => _errorMessage = null);
    if (firstName.isEmpty) {
      setState(() => _errorMessage = 'Please enter your name.');
      return;
    }
    if (surname.isEmpty) {
      setState(() => _errorMessage = 'Please enter your surname.');
      return;
    }
    if (otpChannel == _otpChannelEmail) {
      if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
        setState(() => _errorMessage = 'Please enter a valid email address.');
        return;
      }
    } else {
      if (phone.isEmpty || !phone.startsWith('+') || phone.length < 8) {
        setState(() => _errorMessage = 'Please enter a valid phone number.');
        return;
      }
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your password.');
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
    if (otpChannel == _otpChannelPhone) {
      try {
        await OtpSessionService().setSignupOtpPreference(
          channel: otpChannel,
          destination: phone,
        );
        SignupDraftService().save(
          SignupDraft(
            name: name,
            email: email,
            phoneNumber: phone,
            password: password,
            channel: otpChannel,
          ),
        );
        if (!mounted) return;
        final route = MaterialPageRoute(
          builder: (_) => VerifyCodeScreen(
            channel: otpChannel,
            maskedEmail: _maskEmailForDisplay(email),
            phoneNumber: phone,
            maskedPhone: _maskPhoneForDisplay(phone),
            autoSendOnOpen: true,
          ),
        );
        Navigator.of(context).pushReplacement(route);
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'Could not open number verification. ${e.toString().replaceFirst('Exception: ', '')}';
        });
        return;
      }
    }

    try {
      setState(() => _isLoading = true);
      if (otpChannel != _otpChannelPhone) {
        final anonResult = await _auth.ensureAnonymousSession();
        if (!mounted) return;
        if (!anonResult.success) {
          setState(() {
            _isLoading = false;
            _errorMessage =
                anonResult.message ?? 'Could not start verification.';
          });
          return;
        }
      }
      await OtpSessionService().setSignupOtpPreference(
        channel: otpChannel,
        destination: otpChannel == _otpChannelEmail ? email : phone,
      );
      SignupDraftService().save(
        SignupDraft(
          name: name,
          email: email,
          phoneNumber: phone,
          password: password,
          channel: otpChannel,
        ),
      );
      if (!mounted) return;
      final initialOtpError = '';
      // Always attempt OTP from Verify screen so user can retry there
      // instead of being blocked on register submit.
      final autoSendOnOpen = true;
      setState(() => _isLoading = false);
      if (!mounted) return;
      final route = MaterialPageRoute(
        builder: (_) => VerifyCodeScreen(
          channel: otpChannel,
          maskedEmail: _maskEmailForDisplay(email),
          phoneNumber: otpChannel == _otpChannelPhone ? phone : '',
          maskedPhone: otpChannel == _otpChannelPhone
              ? _maskPhoneForDisplay(phone)
              : '',
          autoSendOnOpen: autoSendOnOpen,
          initialErrorMessage: initialOtpError,
        ),
      );
      Navigator.of(context).pushReplacement(route);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Could not continue verification. ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  String _emailForPhoneSignup(String phone) {
    final normalized = phone.toLowerCase().trim();
    if (normalized.isEmpty) return '';
    // Phone-mode accounts still need a valid email credential in Firebase link flow.
    final safe = normalized.replaceAll(RegExp(r'[^a-z0-9+]'), '');
    return '${safe.replaceAll('+', 'p')}-phone@vyooo.app';
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

  String _maskEmailForDisplay(String value) {
    final t = value.trim();
    final at = t.indexOf('@');
    if (at <= 0 || at >= t.length - 1) return t;
    final local = t.substring(0, at);
    final domain = t.substring(at + 1);
    if (local.length <= 1) return '***@$domain';
    return '${local[0]}${'*' * (local.length - 1)}@$domain';
  }

  String _maskPhoneForDisplay(String value) {
    final t = value.trim();
    if (t.length <= 4) return t;
    final visible = t.substring(t.length - 4);
    return '${'*' * (t.length - 4)}$visible';
  }

  void _onSignIn() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SignInScreen()));
  }
}
