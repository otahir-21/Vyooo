import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:country_picker/country_picker.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/otp_session_service.dart';
import '../../core/services/signup_draft_service.dart';
import '../../core/theme/app_padding.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../core/widgets/auth/auth_widgets.dart';
import '../../core/widgets/vyooo_brand_logo.dart';
import 'sign_in_screen.dart';
import 'verify_code_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  static const _otpChannelEmail = 'email';
  static const _otpChannelPhone = 'phone';
  static const _signupMethodEmail = 'email';
  static const _signupMethodPhone = 'phone';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _auth = AuthService();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  String? _errorMessage;
  String _selectedCountryDialCode = '44';
  String _selectedCountryFlag = '🇬🇧';
  String _selectedSignupMethod = _signupMethodPhone;

  bool get _isEmailSignup => _selectedSignupMethod == _signupMethodEmail;

  @override
  void initState() {
    super.initState();
    final pre = widget.initialEmail?.trim();
    if (pre != null && pre.isNotEmpty && pre.contains('@')) {
      _emailController.text = pre;
      _selectedSignupMethod = _signupMethodEmail;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
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
        type: GradientType.authFlow,
        child: SingleChildScrollView(
          padding: AppPadding.authFormHorizontal,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.sm),
                _buildHeader(),
                const SizedBox(height: AppSpacing.md),
                AuthSegmentedToggle(
                  leftLabel: 'Phone',
                  rightLabel: 'Email',
                  isLeftSelected: !_isEmailSignup,
                  onLeftTap: () => setState(
                    () => _selectedSignupMethod = _signupMethodPhone,
                  ),
                  onRightTap: () => setState(
                    () => _selectedSignupMethod = _signupMethodEmail,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _buildForm(),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
                  Text(
                    _errorMessage!,
                    style: AppTypography.caption.copyWith(color: Colors.red),
                  ),
                ],
                const SizedBox(height: AppSpacing.authCtaTop),
                AuthPrimaryButton(
                  label: 'Register',
                  isLoading: _isLoading,
                  onPressed: _onRegister,
                ),
                const SizedBox(height: AppSpacing.md),
                AuthLinkPrompt(
                  prompt: 'Already have an account? ',
                  actionLabel: 'Sign in',
                  onActionTap: _onSignIn,
                ),
                const SizedBox(height: AppSpacing.authDividerBlock),
                const AuthLabeledDivider(label: 'Or sign up with'),
                const SizedBox(height: AppSpacing.authDividerBlock),
                _buildSocialRow(),
                const SizedBox(height: AppSpacing.authDividerBlock),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VyoooBrandLogo(size: AppSizes.authLogoHeight),
        const SizedBox(height: AppSpacing.md),
        const Text('Create an\nAccount', style: AppTypography.authHeadline),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: AuthFieldColumn(
        children: [
          AuthNameField(controller: _nameController),
          AuthSurnameField(controller: _surnameController),
          if (_isEmailSignup)
            AuthEmailField(controller: _emailController)
          else
            AuthPhoneField(
              controller: _phoneController,
              countryFlag: _selectedCountryFlag,
              countryDialCode: _selectedCountryDialCode,
              onCountryTap: _pickCountry,
            ),
          AuthPasswordField(controller: _passwordController),
          AuthPasswordField(
            controller: _confirmPasswordController,
            hint: 'Confirm Password',
          ),
        ],
      ),
    );
  }

  Widget _buildSocialRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AuthSocialIconButton(
          icon: FontAwesomeIcons.google,
          isLoading: _isGoogleLoading,
          onTap: _onGoogleSignIn,
        ),
        const SizedBox(width: AppSpacing.socialRowGap),
        AuthSocialIconButton(
          icon: FontAwesomeIcons.apple,
          isLoading: _isAppleLoading,
          onTap: _onAppleSignIn,
        ),
        const SizedBox(width: AppSpacing.socialRowGap),
        AuthSocialIconButton(icon: FontAwesomeIcons.facebook),
      ],
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
    final error = _validateRegistration();
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    final typedEmail = _emailController.text.trim();
    final firstName = _nameController.text.trim();
    final surname = _surnameController.text.trim();
    final name = '$firstName $surname'.trim();
    final password = _passwordController.text.trim();
    final phone = _normalizedPhone();
    final otpChannel =
        _isEmailSignup ? _otpChannelEmail : _otpChannelPhone;
    final email =
        otpChannel == _otpChannelEmail ? typedEmail : _emailForPhoneSignup(phone);

    setState(() => _errorMessage = null);

    try {
      if (otpChannel == _otpChannelPhone) {
        await _openVerifyFlow(
          channel: otpChannel,
          email: email,
          phone: phone,
          name: name,
          password: password,
        );
        return;
      }

      setState(() => _isLoading = true);
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

      await _openVerifyFlow(
        channel: otpChannel,
        email: email,
        phone: phone,
        name: name,
        password: password,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Could not continue verification. ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  String? _validateRegistration() {
    final firstName = _nameController.text.trim();
    final surname = _surnameController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();
    final phone = _normalizedPhone();
    final email = _emailController.text.trim();

    if (firstName.isEmpty) return 'Please enter your name.';
    if (surname.isEmpty) return 'Please enter your surname.';
    if (_isEmailSignup) {
      if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
        return 'Please enter a valid email address.';
      }
    } else if (phone.isEmpty || !phone.startsWith('+') || phone.length < 8) {
      return 'Please enter a valid phone number.';
    }
    if (password.isEmpty) return 'Please enter your password.';
    if (password != confirm) return 'Passwords do not match.';
    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    return null;
  }

  Future<void> _openVerifyFlow({
    required String channel,
    required String email,
    required String phone,
    required String name,
    required String password,
  }) async {
    try {
      await OtpSessionService().setSignupOtpPreference(
        channel: channel,
        destination: channel == _otpChannelEmail ? email : phone,
      );
      SignupDraftService().save(
        SignupDraft(
          name: name,
          email: email,
          phoneNumber: phone,
          password: password,
          channel: channel,
        ),
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => VerifyCodeScreen(
          channel: channel,
          maskedEmail: _maskEmailForDisplay(email),
          phoneNumber: channel == _otpChannelPhone ? phone : '',
          maskedPhone: channel == _otpChannelPhone
              ? _maskPhoneForDisplay(phone)
              : '',
          autoSendOnOpen: true,
        ),
      ),
    );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Could not open number verification. ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  String _emailForPhoneSignup(String phone) {
    final normalized = phone.toLowerCase().trim();
    if (normalized.isEmpty) return '';
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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
    );
  }
}
