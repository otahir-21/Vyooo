import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_user_model.dart';
import '../../core/profile/creator_monetization.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/creator_monetization_service.dart';
import '../../core/services/user_service.dart';
import '../../core/subscription/subscription_controller.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../core/widgets/settings/settings_inner_app_bar.dart';

/// Lets Creator-plan users enable subscriptions on their public profile.
class CreatorMonetizationScreen extends StatefulWidget {
  const CreatorMonetizationScreen({super.key});

  @override
  State<CreatorMonetizationScreen> createState() =>
      _CreatorMonetizationScreenState();
}

class _CreatorMonetizationScreenState extends State<CreatorMonetizationScreen> {
  final CreatorMonetizationService _monetizationService =
      CreatorMonetizationService();
  bool _saving = false;

  Future<void> _onToggle(bool value, AppUserModel user) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _monetizationService.setMonetizationEnabled(enabled: value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Subscriptions are now visible on your profile.'
                : 'Subscriptions are hidden from your profile.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid ?? '';
    final hasVyoooCreatorPlan =
        context.watch<SubscriptionController>().canOfferSubscriptions;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.premiumDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SettingsInnerAppBar(title: 'Creator subscriptions'),
            Expanded(
              child: uid.isEmpty
                  ? const Center(
                      child: Text(
                        'Sign in to manage creator subscriptions.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : StreamBuilder<AppUserModel?>(
                      stream: UserService().userStream(uid),
                      builder: (context, snapshot) {
                        final user = snapshot.data;
                        if (user == null && snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white54,
                            ),
                          );
                        }
                        if (user == null) {
                          return const Center(
                            child: Text(
                              'Profile unavailable.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          );
                        }

                        final eligible =
                            isSubscribeEligibleAccountType(user.accountType);
                        final hasCreatorAccess = canManageProfileMonetization(
                          accountType: user.accountType,
                          hasVyoooCreatorPlan: hasVyoooCreatorPlan,
                        );
                        if (!eligible) {
                          return _MessageCard(
                            title: 'Business or creator account required',
                            body:
                                'Switch to a business or public creator account type in Personal information before enabling subscriptions.',
                          );
                        }
                        if (!hasCreatorAccess) {
                          return _MessageCard(
                            title: 'Creator plan required',
                            body:
                                'Upgrade to the Creator plan to let fans subscribe to your profile, or use a business account.',
                          );
                        }

                        return ListView(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Enable subscriptions',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  user.monetizationEnabled
                                      ? 'Fans see Subscribe on your profile and your gold creator badge.'
                                      : 'Your profile shows Follow only until you turn this on.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.65),
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                                value: user.monetizationEnabled,
                                onChanged: _saving
                                    ? null
                                    : (v) => _onToggle(v, user),
                                activeThumbColor: Colors.white,
                                activeTrackColor: const Color(0xFFF81945),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
