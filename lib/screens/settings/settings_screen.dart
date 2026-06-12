import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vyooo/core/theme/app_gradients.dart';

import '../../core/models/app_user_model.dart';
import '../../core/profile/creator_monetization.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/subscription/subscription_controller.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/dob_validation.dart';
import '../../core/wrappers/auth_wrapper.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../core/widgets/settings/settings_inner_app_bar.dart';
import '../../features/vr/vr_screen.dart';
import '../account/account_screen.dart';
import '../account/blocked_users_screen.dart';
import '../account/change_password_screen.dart';
import '../account/two_factor_screen.dart';
import '../account/verification_request_screen.dart';
import '../profile/personal_information_screen.dart';
import 'about_screen.dart';
import 'contact_support_screen.dart';
import 'creator_monetization_screen.dart';
import 'downloaded_videos_screen.dart';
import 'notifications_settings_screen.dart';
// Parental consent flow temporarily disabled; restore with the tile below.
// import 'parental_approvals_screen.dart';
import 'revenue_coming_soon_view.dart';
import 'privacy_policy_screen.dart';
import 'report_problem_screen.dart';
import 'saved_posts_screen.dart';
import 'settings_subscriptions_screen.dart';
import 'terms_service_screen.dart';
import 'wallet/wallet_coming_soon_view.dart';
import 'live_stream_monetisation_screen.dart';
import 'preferences/activity_settings_screen.dart';
import 'preferences/archive_settings_screen.dart';
import 'preferences/close_friends_screen.dart';
import 'preferences/comments_privacy_screen.dart';
import 'preferences/data_usage_settings_screen.dart';
import 'preferences/language_settings_screen.dart';
import 'preferences/messages_story_replies_screen.dart';
import 'preferences/story_reels_privacy_screen.dart';
import 'preferences/tags_mentions_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static bool _showFamilyApprovalsTile(AppUserModel? user) {
    if (user == null) return true;
    final dobRaw = (user.dob ?? '').trim();
    if (dobRaw.isEmpty || !DobValidation.isValidDobString(dobRaw)) {
      return true;
    }
    final birth = DobValidation.tryParseIsoDob(dobRaw);
    if (birth == null) return true;
    return !DobValidation.requiresParentalConsent(birth);
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.premiumDark,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAppBar(context),
              Expanded(
                child: uid.isEmpty
                    ? _buildSettingsList(
                        context,
                        showFamilyApprovals: true,
                      )
                    : StreamBuilder<AppUserModel?>(
                        stream: UserService().userStream(uid),
                        builder: (context, snapshot) {
                          return _buildSettingsList(
                            context,
                            user: snapshot.data,
                            showFamilyApprovals:
                                _showFamilyApprovalsTile(snapshot.data),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsList(
    BuildContext context, {
    AppUserModel? user,
    required bool showFamilyApprovals,
  }) {
    final subscription = context.watch<SubscriptionController>();
    final showCreatorMonetization = user != null &&
        (canManageProfileMonetization(
              accountType: user.accountType,
              hasVyoooCreatorPlan: subscription.canOfferSubscriptions,
            ) ||
            user.monetizationEnabled) &&
        isSubscribeEligibleAccountType(user.accountType);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        _sectionHeader('Your account'),
        _settingsGroup([
          _SettingsTile(
            iconPath: 'assets/vyooO_icons/Settings/Account.png',
            label: 'Accounts Center',
            subtitle: 'Password, security, verification',
            onTap: () => _push(context, const AccountScreen()),
          ),
          _SettingsTile(
            iconPath: 'assets/vyooO_icons/Settings/Account.png',
            label: 'Personal information',
            onTap: () => _push(context, const PersonalInformationScreen()),
          ),
          _SettingsTile(
            icon: Icons.lock_outline_rounded,
            label: 'Password & security',
            onTap: () => _push(context, const ChangePasswordScreen()),
          ),
          _SettingsTile(
            icon: Icons.verified_user_outlined,
            label: 'Two-factor authentication',
            onTap: () => _push(context, const TwoFactorScreen()),
          ),
          _SettingsTile(
            icon: Icons.verified_outlined,
            label: 'Request verification',
            onTap: () => _push(context, const VerificationRequestScreen()),
          ),
          _SettingsTile(
            icon: Icons.block_flipped,
            label: 'Blocked accounts',
            onTap: () => _push(context, const BlockedUsersScreen()),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        _sectionHeader('How you use Vyooo'),
        _settingsGroup([
          _SettingsTile(
            iconPath: 'assets/vyooO_icons/Home/Save.png',
            label: 'Saved',
            subtitle: 'Private saved posts',
            onTap: () => _push(context, const SavedPostsScreen()),
          ),
          _SettingsTile(
            icon: Icons.archive_outlined,
            label: 'Archive',
            onTap: () => _push(context, const ArchiveSettingsScreen()),
          ),
          _SettingsTile(
            icon: Icons.history_rounded,
            label: 'Your activity',
            onTap: () => _push(context, const ActivitySettingsScreen()),
          ),
          _SettingsTile(
            iconPath: 'assets/vyooO_icons/Settings/Notification.png',
            label: 'Notifications',
            onTap: () => _push(context, const NotificationSettingsScreen()),
          ),
          _SettingsTile(
            iconPath: 'assets/vyooO_icons/Settings/Downloaded.png',
            label: 'Downloaded videos',
            isPremium: true,
            onTap: () => _push(context, const DownloadedVideosScreen()),
          ),
          _SettingsTile(
            icon: Icons.language_rounded,
            label: 'Language',
            onTap: () => _push(context, const LanguageSettingsScreen()),
          ),
          _SettingsTile(
            icon: Icons.data_usage_rounded,
            label: 'Data usage & media quality',
            onTap: () => _push(context, const DataUsageSettingsScreen()),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        _sectionHeader('Who can see your content'),
        _settingsGroup([
          _SettingsTile(
            icon: Icons.lock_person_outlined,
            label: 'Account privacy',
            subtitle: 'Public or private account',
            onTap: () => _push(context, const PersonalInformationScreen()),
          ),
          _SettingsTile(
            icon: Icons.people_outline_rounded,
            label: 'Close friends',
            onTap: () => _push(context, const CloseFriendsScreen()),
          ),
          _SettingsTile(
            icon: Icons.volume_off_outlined,
            label: 'Muted accounts',
            onTap: () => _push(context, const BlockedUsersScreen()),
          ),
          _SettingsTile(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Messages & story replies',
            onTap: () => _push(context, const MessagesStoryRepliesScreen()),
          ),
          _SettingsTile(
            icon: Icons.tag_outlined,
            label: 'Tags & mentions',
            onTap: () => _push(context, const TagsMentionsScreen()),
          ),
          _SettingsTile(
            icon: Icons.comment_outlined,
            label: 'Comments',
            onTap: () => _push(context, const CommentsPrivacyScreen()),
          ),
          _SettingsTile(
            icon: Icons.slideshow_outlined,
            label: 'Story & reels',
            onTap: () => _push(context, const StoryReelsPrivacyScreen()),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        _sectionHeader('Creator tools'),
        _settingsGroup([
          _SettingsTile(
            iconPath: 'assets/vyooO_icons/Settings/Subscription.png',
            label: 'Subscriptions',
            isPremium: true,
            onTap: () => _push(context, const SettingsSubscriptionsScreen()),
          ),
          if (showCreatorMonetization)
            _SettingsTile(
              iconPath: 'assets/vyooO_icons/Settings/Subscription.png',
              label: 'Creator subscriptions',
              isPremium: true,
              onTap: () => _push(context, const CreatorMonetizationScreen()),
            ),
          _SettingsTile(
            iconPath: 'assets/vyooO_icons/Settings/Wallet.png',
            label: 'Vyooo coin',
            subtitle: 'Coming soon',
            isPremium: true,
            onTap: () => _push(
              context,
              const Scaffold(
                backgroundColor: Colors.black,
                body: WalletComingSoonView(),
              ),
            ),
          ),
          _SettingsTile(
            assetIconPath: 'assets/vyooO_icons/Home/vr.png',
            label: 'VR',
            onTap: () => _push(
              context,
              const Scaffold(
                backgroundColor: Colors.black,
                body: SafeArea(child: VrComingSoonView()),
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.payments_outlined,
            label: 'Revenue',
            subtitle: 'Coming soon',
            isPremium: true,
            onTap: () => _push(
              context,
              const Scaffold(
                backgroundColor: Colors.black,
                body: RevenueComingSoonView(),
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.live_tv_rounded,
            label: 'Live stream monetization',
            onTap: () => _push(context, const LiveStreamMonetisationScreen()),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        _sectionHeader('Support & about'),
        _settingsGroup([
          // Parental consent flow temporarily disabled (min sign-up age is 16);
          // uncomment to restore the parent-side approvals entry.
          // if (showFamilyApprovals)
          //   _SettingsTile(
          //     iconPath: 'assets/vyooO_icons/Settings/About.png',
          //     label: 'Family approvals',
          //     onTap: () => _push(context, const ParentalApprovalsScreen()),
          //   ),
          _SettingsTile(
            iconPath: 'assets/vyooO_icons/Settings/Customer Support.png',
            label: 'Help center',
            onTap: () => _push(context, const ContactSupportScreen()),
          ),
          _SettingsTile(
            iconPath: 'assets/vyooO_icons/Settings/Report a problem.png',
            label: 'Report a problem',
            onTap: () => _push(context, const ReportProblemScreen()),
          ),
          _SettingsTile(
            iconPath: 'assets/vyooO_icons/Settings/About.png',
            label: 'About Vyooo',
            onTap: () => _push(context, const AboutScreen()),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy policy',
            onTap: () => _push(context, const PrivacyPolicyScreen()),
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            label: 'Terms of service',
            onTap: () => _push(context, const TermsServiceScreen()),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        _sectionHeader('Login'),
        _settingsGroup([
          _SettingsTile(
            iconPath: 'assets/vyooO_icons/Settings/Logout.png',
            label: 'Log out',
            isLogout: true,
            onTap: () => _logout(context),
          ),
        ]),
      ],
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        title,
        style: AppTypography.caption.copyWith(
          color: Colors.white.withValues(alpha: 0.55),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _settingsGroup(List<Widget> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: AppSpacing.md + 32 + AppSpacing.sm,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            tiles[i],
          ],
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return const SettingsInnerAppBar(title: 'Settings');
  }

  Future<void> _logout(BuildContext context) async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: AppGradients.authGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Logout',
                style: AppTypography.onboardingSectionTitle.copyWith(
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
              Text(
                'Do you want to logout from your account?',
                style: AppTypography.authDialogOption.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'No, stay',
                      style: AppTypography.authDialogOption,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Yes, logout'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldLogout != true) return;

    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
      (route) => false,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.label,
    required this.onTap,
    this.iconPath,
    this.assetIconPath,
    this.icon,
    this.subtitle,
    this.isPremium = false,
    this.isLogout = false,
  });

  final String label;
  final VoidCallback onTap;
  final String? iconPath;
  final String? assetIconPath;
  final IconData? icon;
  final String? subtitle;
  final bool isPremium;
  final bool isLogout;

  @override
  Widget build(BuildContext context) {
    final accent = isLogout
        ? const Color(0xFFE81E57)
        : Colors.white.withValues(alpha: 0.85);
    final labelColor = isLogout ? const Color(0xFFE81E57) : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md - 2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 32,
                child: Center(child: _buildLeading(accent)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            style: AppTypography.authDialogOption.copyWith(
                              color: labelColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isPremium) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFACC15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'PREMIUM',
                              style: AppTypography.caption.copyWith(
                                color: Colors.black,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle!,
                        style: AppTypography.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isLogout)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(Color color) {
    if (assetIconPath != null) {
      return Image.asset(
        assetIconPath!,
        width: 22,
        height: 22,
        color: color,
      );
    }
    if (iconPath != null) {
      return Directionality(
        textDirection:
            isLogout ? TextDirection.rtl : TextDirection.ltr,
        child: Image.asset(
          iconPath!,
          width: 22,
          height: 22,
          color: color,
        ),
      );
    }
    return Icon(icon ?? Icons.settings_outlined, size: 22, color: color);
  }
}
