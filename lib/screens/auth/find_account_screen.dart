import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_padding.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/auth/auth_widgets.dart';
import '../../services/find_account_service.dart';
import '../../services/mock_find_account_service.dart';
import 'reset_password_otp_screen.dart';

class FindAccountScreen extends StatefulWidget {
  const FindAccountScreen({super.key, this.findAccountService});

  final FindAccountService? findAccountService;

  @override
  State<FindAccountScreen> createState() => _FindAccountScreenState();
}

class _FindAccountScreenState extends State<FindAccountScreen> {
  static const _methodEmail = 'email';
  static const _methodPhone = 'phone';

  final _inputController = TextEditingController();
  final _phoneController = TextEditingController();
  final _auth = AuthService();

  bool _isLoading = false;
  String? _errorMessage;
  String _selectedMethod = _methodEmail;
  String _selectedCountryDialCode = '44';
  String _selectedCountryFlag = '🇬🇧';

  FindAccountService get _findAccountService =>
      widget.findAccountService ?? MockFindAccountService();

  bool get _isEmailMethod => _selectedMethod == _methodEmail;

  bool get _canContinue => _isEmailMethod
      ? _inputController.text.trim().isNotEmpty
      : _normalizedPhone().isNotEmpty;

  bool get _looksLikeEmail => _inputController.text.trim().contains('@');

  @override
  void dispose() {
    _inputController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    if (!_canContinue || _isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_isEmailMethod) {
      final value = _inputController.text.trim();
      if (_looksLikeEmail) {
        final result = await _auth.sendPasswordReset(email: value);
        if (!mounted) return;
        setState(() => _isLoading = false);
        if (result.success) {
          _openOtp(value);
        } else {
          setState(
            () => _errorMessage = result.message ?? 'Could not send reset email.',
          );
        }
      } else {
        final result = await _findAccountService.findAccount(value);
        if (!mounted) return;
        setState(() => _isLoading = false);
        if (result.found) {
          _openOtp(value);
        } else {
          setState(
            () => _errorMessage = result.errorMessage ?? 'Account not found',
          );
        }
      }
      return;
    }

    final phone = _normalizedPhone();
    var email = await UserService().resolveEmailForPhone(phone);
    email ??= _emailForPhoneLogin(phone);
    if (!mounted) return;
    if (email.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No account found with this phone number.';
      });
      return;
    }
    final result = await _auth.sendPasswordReset(email: email);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.success) {
      _openOtp(email, displayPhone: phone);
    } else {
      setState(
        () => _errorMessage = result.message ?? 'Could not send reset code.',
      );
    }
  }

  void _openOtp(String emailOrUsername, {String? displayPhone}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResetPasswordOTPScreen(
          emailOrUsername: emailOrUsername,
          displayPhone: displayPhone,
        ),
      ),
    );
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
          AuthScreenHeader(
            centerAlign: true,
            titleTextAlign: TextAlign.start,
            title: 'Find your\naccount',
            subtitle: _isEmailMethod
                ? 'Enter your Email address or Username'
                : 'Enter your Mobile number',
            subtitleTextAlign: TextAlign.start,
            belowSubtitle: [
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () {
                    // TODO: alternate recovery when user cannot reset password
                  },
                  child: Text(
                    "Can't reset your password?",
                    style: AppTypography.authAccentLink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_isEmailMethod)
            AuthLoginIdentifierField(
              controller: _inputController,
              hint: 'Email address or Username',
              onChanged: (_) => setState(() {}),
            )
          else
            AuthPhoneField(
              controller: _phoneController,
              countryFlag: _selectedCountryFlag,
              countryDialCode: _selectedCountryDialCode,
              onCountryTap: _pickCountry,
              onChanged: (_) => setState(() {}),
            ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
            Text(
              _errorMessage!,
              style: AppTypography.caption.copyWith(color: Colors.red),
            ),
          ],
          const SizedBox(height: AppSpacing.authCtaTop),
          AuthPrimaryButton(
            label: 'Continue',
            isLoading: _isLoading,
            enabled: _canContinue,
            onPressed: _onContinue,
          ),
          const SizedBox(height: AppSpacing.md),
          GestureDetector(
            onTap: () => setState(() {
              _selectedMethod =
                  _isEmailMethod ? _methodPhone : _methodEmail;
              _errorMessage = null;
            }),
            child: Text(
              _isEmailMethod
                  ? 'Find by Mobile number instead'
                  : 'Find by Email, Username instead',
              style: AppTypography.authSmallBody.copyWith(
                color: AppTheme.lightMutedBody,
              ),
            ),
          ),
          SizedBox(height: AuthFloatingNavRow.scrollBottomClearance(context)),
        ],
      ),
    );
  }

  void _pickCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      favorite: const ['GB', 'AE'],
      countryListTheme: CountryListThemeData(
        backgroundColor: AppTheme.lightScaffoldBackground,
        textStyle: const TextStyle(color: AppTheme.lightOnSurface),
        inputDecoration: InputDecoration(
          labelText: 'Search country',
          labelStyle: const TextStyle(color: AppTheme.lightSecondaryText),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppTheme.lightUnfocusedUnderline),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppTheme.lightFocusedUnderline),
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
