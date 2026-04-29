import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_links.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_padding.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../core/widgets/onboarding_progress_bar.dart';
import '../../services/onboarding_storage.dart';
import '../../core/wrappers/main_nav_wrapper.dart';

class OnboardingCompleteScreen extends StatelessWidget {
  const OnboardingCompleteScreen({super.key});

  static const Color _linkColor = Color(0xFFD10057);

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _onAccept(BuildContext context) async {
    final uid = AuthService().currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        await UserService().updateUserProfile(
          uid: uid,
          onboardingCompleted: true,
        );
      } catch (_) {
        // Still complete onboarding and go to Home so user isn't stuck
        await OnboardingStorage.setComplete(true);
        if (!context.mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainNavWrapper()),
          (route) => false,
        );
        return;
      }
    }
    await OnboardingStorage.setComplete(true);
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MainNavWrapper()),
      (route) => false,
    );
  }

  Future<void> _onDecline(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A0030),
        title: const Text(
          'Exit onboarding?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to exit onboarding?',
          style: TextStyle(color: White70.value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: White70.value)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Exit', style: TextStyle(color: _linkColor)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.profile,
        child: SafeArea(
          child: Padding(
            padding: AppPadding.authFormHorizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: AppSpacing.xl - AppSpacing.xs),
                IconButton(
                  onPressed: () => _onBack(context),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                  tooltip: 'Back',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
                _buildLogo(),
                AppPadding.itemGap,
                const OnboardingProgressBar(progress: 1.0),
                SizedBox(height: AppSpacing.xl + AppSpacing.md),
                const Text(
                  "You're all set!",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.defaultTextColor,
                  ),
                ),
                SizedBox(height: AppSpacing.xl - AppSpacing.xs),
                _buildDescription(context),
                SizedBox(height: AppSpacing.xl + AppSpacing.md),
                const Spacer(),
                _buildAcceptButton(context),
                AppPadding.itemGap,
                _buildDeclineButton(context),
                SizedBox(height: AppSpacing.xl - AppSpacing.xs),
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

  Widget _buildDescription(BuildContext context) {
    const baseStyle = TextStyle(
      fontSize: 14,
      color: AppTheme.secondaryTextColor,
      height: 1.5,
      fontWeight: FontWeight.w400,
    );
    const linkStyle = TextStyle(
      fontSize: 14,
      color: _linkColor,
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(
            text:
                "Tap Agree & Continue to start your VyooO experience.\nBy continuing, you confirm that you've read and accepted our ",
          ),
          TextSpan(
            text: 'Terms of Use',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => _openUrl(AppLinks.termsOfUse),
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => _openUrl(AppLinks.privacyPolicy),
          ),
          const TextSpan(
            text: '.\nPlease review the links above for more details.',
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () => _onAccept(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.buttonBackground,
          foregroundColor: AppTheme.buttonTextColor,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
        ),
        child: const Text(
          'I Accept',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDeclineButton(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => _onDecline(context),
        child: const Text(
          'Decline',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.secondaryTextColor,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Future<void> _onBack(BuildContext context) async {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    await AuthService().signOut();
  }
}
