import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_gradient_background.dart';
import 'sign_in_screen.dart';

class PasswordUpdatedScreen extends StatelessWidget {
  const PasswordUpdatedScreen({super.key});

  static const double _horizontalPadding = 28;

  void _onGoToLogin(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const SignInScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.auth,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),
                _buildLogo(),
                const SizedBox(height: 60),
                const Text(
                  'Password Updated',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.defaultTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                _buildIllustration(),
                const SizedBox(height: 60),
                _buildGoToLoginButton(context),
                const Spacer(),
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

  Widget _buildIllustration() {
    return Center(
      child: Image.asset(
        'assets/images/illustration.png',
        height: 230,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox(
          height: 230,
          child: Center(
            child: Icon(
              Icons.check_circle_outline,
              size: 120,
              color: AppTheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoToLoginButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () => _onGoToLogin(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.buttonBackground,
          foregroundColor: AppTheme.buttonTextColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: const Text(
          'Go to Login',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
