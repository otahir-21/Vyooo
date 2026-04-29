import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../services/find_account_service.dart';
import '../../services/mock_find_account_service.dart';
import 'reset_password_otp_screen.dart';

class FindAccountScreen extends StatefulWidget {
  const FindAccountScreen({
    super.key,
    this.findAccountService,
  });

  final FindAccountService? findAccountService;

  @override
  State<FindAccountScreen> createState() => _FindAccountScreenState();
}

class _FindAccountScreenState extends State<FindAccountScreen> {
  static const double _horizontalPadding = 28;
  static const Color _pinkLink = Color(0xFFD10057);

  final _inputController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  FindAccountService get _findAccountService =>
      widget.findAccountService ?? MockFindAccountService();

  final AuthService _auth = AuthService();

  bool get _canContinue => _inputController.text.trim().isNotEmpty;

  bool get _looksLikeEmail => _inputController.text.trim().contains('@');

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    if (!_canContinue || _isLoading) return;
    final value = _inputController.text.trim();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_looksLikeEmail) {
      final result = await _auth.sendPasswordReset(email: value);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (result.success) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ResetPasswordOTPScreen(emailOrUsername: value),
          ),
        );
      } else {
        setState(() => _errorMessage = result.message ?? 'Could not send reset email.');
      }
    } else {
      final result = await _findAccountService.findAccount(value);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (result.found) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ResetPasswordOTPScreen(emailOrUsername: value),
          ),
        );
      } else {
        setState(() => _errorMessage = result.errorMessage ?? 'Account not found');
      }
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
                  padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildLogo(),
                      const SizedBox(height: 60),
                      const Text(
                        'Find your\naccount',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.defaultTextColor,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Enter your Email address or Username',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.secondaryTextColor,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () {
                          // TODO: Can't reset your password flow
                        },
                        child: const Text(
                          "Can't reset your password?",
                          style: TextStyle(
                            fontSize: 14,
                            color: _pinkLink,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildInput(),
                      const SizedBox(height: 30),
                      if (_errorMessage != null) ...[
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      _buildContinueButton(),
                      const SizedBox(height: 30),
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            // TODO: Find by mobile
                          },
                          child: const Text(
                            'Find by Mobile number instead',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.secondaryTextColor,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      _buildDivider(),
                      const SizedBox(height: 20),
                      _buildSocialIcons(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            bottom: 24,
            child: _buildBackButton(),
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

  Widget _buildInput() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                color: AppTheme.defaultTextColor,
                fontSize: 16,
              ),
              decoration: const InputDecoration(
                hintText: 'Email address or Username',
                hintStyle: TextStyle(color: White50.value, fontSize: 16),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          if (_inputController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: AppTheme.primary, size: 22),
              onPressed: () {
                _inputController.clear();
                setState(() {});
              },
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
        onPressed: (_canContinue && !_isLoading) ? _onContinue : null,
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(height: 1, color: White24.value),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: const Text(
            'Or Login with',
            style: TextStyle(
              fontSize: 14,
              color: White50.value,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        Expanded(
          child: Container(height: 1, color: White24.value),
        ),
      ],
    );
  }

  Widget _buildSocialIcons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FaIcon(FontAwesomeIcons.google, color: AppTheme.primary, size: 28),
        const SizedBox(width: 40),
        FaIcon(FontAwesomeIcons.apple, color: AppTheme.primary, size: 28),
        const SizedBox(width: 40),
        FaIcon(FontAwesomeIcons.facebook, color: AppTheme.primary, size: 28),
      ],
    );
  }

  Widget _buildBackButton() {
    return Material(
      elevation: 2,
      shape: const CircleBorder(),
      color: AppTheme.buttonBackground,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(),
        customBorder: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          child: const Icon(
            Icons.arrow_back,
            color: AppTheme.buttonTextColor,
            size: 28,
          ),
        ),
      ),
    );
  }
}
