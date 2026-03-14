import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/wrappers/auth_wrapper.dart';
import '../account/account_screen.dart';

/// Settings screen for standard user: list with icons, PREMIUM tags, Logout in red.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAppBar(context),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0D020D),
                      Color(0xFF2D072D),
                      Color(0xFF4D0B3D),
                      Color(0xFF7D124D),
                    ],
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.lg,
                  ),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.input),
                      ),
                      child: Column(
                        children: [
                          _SettingsTile(
                            icon: Icons.person_outline_rounded,
                            label: 'Account',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const AccountScreen(),
                                ),
                              );
                            },
                          ),
                          _divider(),
                          _SettingsTile(
                            icon: FontAwesomeIcons.crown,
                            label: 'Subscriptions',
                            isPremium: true,
                            onTap: () {},
                          ),
                          _divider(),
                          _SettingsTile(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'VyooO Payout',
                            isPremium: true,
                            onTap: () {},
                          ),
                          _divider(),
                          _SettingsTile(
                            icon: Icons.download_rounded,
                            label: 'Downloaded Videos',
                            isPremium: true,
                            onTap: () {},
                          ),
                          _divider(),
                          _SettingsTile(
                            icon: Icons.notifications_outlined,
                            label: 'Notifications',
                            onTap: () {},
                          ),
                          _divider(),
                          _SettingsTile(
                            icon: Icons.support_agent_rounded,
                            label: 'Contact Support',
                            onTap: () {},
                          ),
                          _divider(),
                          _SettingsTile(
                            icon: Icons.report_problem_outlined,
                            label: 'Report Problem',
                            onTap: () {},
                          ),
                          _divider(),
                          _SettingsTile(
                            icon: Icons.info_outline_rounded,
                            label: 'About',
                            onTap: () {},
                          ),
                          _divider(),
                          _SettingsTile(
                            icon: Icons.logout_rounded,
                            label: 'Logout',
                            isLogout: true,
                            onTap: () => _logout(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: Colors.white,
              size: 32,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          const Expanded(
            child: Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Text(
            'VyooO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withValues(alpha: 0.1),
      indent: 56,
      endIndent: AppSpacing.md,
    );
  }

  Future<void> _logout(BuildContext context) async {
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
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPremium = false,
    this.isLogout = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPremium;
  final bool isLogout;

  @override
  Widget build(BuildContext context) {
    final color = isLogout ? AppColors.deleteRed : Colors.white;
    final labelColor = isLogout ? AppColors.deleteRed : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: color.withValues(alpha: isLogout ? 1.0 : 0.9),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: labelColor.withValues(alpha: isLogout ? 1.0 : 0.95),
                    fontSize: 16,
                    fontWeight: isLogout ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
              if (isPremium) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lightGold,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'PREMIUM',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: color.withValues(alpha: isLogout ? 1.0 : 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
