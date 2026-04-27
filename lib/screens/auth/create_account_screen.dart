import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:country_picker/country_picker.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/otp_session_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_gradient_background.dart';
import 'sign_in_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  static const String _otpChannelEmail = 'email';
  static const String _otpChannelWhatsApp = 'whatsapp';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  String? _errorMessage;
  String _selectedCountryCode = 'GB';
  String _selectedCountryDialCode = '44';
  String _selectedCountryFlag = '🇬🇧';

  final AuthService _auth = AuthService();

  static const double _horizontalPadding = 28;
  static const double _logoHeight = 50;
  static const double _spacingBelowLogo = 60;
  static const double _titleFontSize = 48;
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
    _phoneController.dispose();
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
    final dialCode = '+$_selectedCountryDialCode';
    return TextFormField(
      controller: _phoneController,
      style: const TextStyle(
        color: AppTheme.defaultTextColor,
        fontSize: _inputFontSize,
        fontWeight: FontWeight.w400,
      ),
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        hintText: 'Phone Number',
        prefixIcon: GestureDetector(
          onTap: _pickCountry,
          child: Container(
            width: 98,
            alignment: Alignment.center,
            child: Text(
              '$_selectedCountryFlag $dialCode',
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
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
        height: _logoHeight,
        child: Image.asset(
          'assets/BrandLogo/Vyooo logo (2).png',
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
    final isGoogle = icon == FontAwesomeIcons.google;
    final isApple = icon == FontAwesomeIcons.apple;
    return GestureDetector(
      onTap: isGoogle
          ? _onGoogleSignIn
          : isApple
              ? _onAppleSignIn
              : null,
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
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    final phone = _normalizedPhone();

    setState(() => _errorMessage = null);
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your name.');
      return;
    }
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
    final otpChannel = await _showVerificationMethodDialog();
    if (!mounted || otpChannel == null) return;
    if (otpChannel == _otpChannelWhatsApp &&
        (phone.isEmpty || !phone.startsWith('+') || phone.length < 8)) {
      setState(() {
        _errorMessage = 'Please enter a valid phone number for WhatsApp OTP.';
      });
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
    if (otpChannel == _otpChannelWhatsApp) {
      final otpResult = await _auth.sendSignupWhatsAppOtp(phoneNumber: phone);
      if (!mounted) return;
      if (!otpResult.success) {
        setState(() {
          _isLoading = false;
          _errorMessage = otpResult.message ?? 'Could not send WhatsApp OTP.';
        });
        return;
      }
    }
    await OtpSessionService().setSignupOtpPreference(
      channel: otpChannel,
      destination: otpChannel == _otpChannelWhatsApp ? phone : email,
    );
    setState(() => _isLoading = false);
    // AuthWrapper shows VerifyCodeScreen until email OTP is verified.
  }

  Future<String?> _showVerificationMethodDialog() {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A0A24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Verify your account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how you want to receive OTP.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.74),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              _verificationMethodTile(
                icon: Icons.mark_email_unread_outlined,
                title: 'Email OTP',
                subtitle: _emailController.text.trim().isEmpty
                    ? 'Use your email address'
                    : _emailController.text.trim(),
                onTap: () => Navigator.of(ctx).pop(_otpChannelEmail),
              ),
              const SizedBox(height: 10),
              _verificationMethodTile(
                icon: FontAwesomeIcons.whatsapp,
                title: 'WhatsApp OTP',
                subtitle: _normalizedPhone().isEmpty
                    ? 'Use your phone number'
                    : _normalizedPhone(),
                onTap: () => Navigator.of(ctx).pop(_otpChannelWhatsApp),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _verificationMethodTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: White24.value),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
          ],
        ),
      ),
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
          _selectedCountryCode = c.countryCode;
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

  void _onSignIn() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SignInScreen()));
  }
}
