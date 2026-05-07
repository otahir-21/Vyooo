import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_gradients.dart';
import '../../core/models/app_user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/creator_subscription_service.dart';
import '../../core/services/user_service.dart';
import '../../core/subscription/subscription_controller.dart';
import 'wallet/change_plan_screen.dart';
import 'package:vyooo/core/widgets/app_gradient_background.dart';

class ManageSubscriptionsScreen extends StatefulWidget {
  const ManageSubscriptionsScreen({super.key});

  @override
  State<ManageSubscriptionsScreen> createState() =>
      _ManageSubscriptionsScreenState();
}

class _ManageSubscriptionsScreenState extends State<ManageSubscriptionsScreen> {
  int _selectedTabIndex = 0;
  final List<String> _tabs = ['All Active', 'Paused', 'Cancelled'];
  final UserService _userService = UserService();
  final CreatorSubscriptionService _creatorSubscriptionService =
      CreatorSubscriptionService();
  late final Future<AppUserModel?> _currentUserFuture;

  @override
  void initState() {
    super.initState();
    final uid = AuthService().currentUser?.uid;
    _currentUserFuture = (uid == null || uid.isEmpty)
        ? Future<AppUserModel?>.value(null)
        : _userService.getUser(uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        type: GradientType.premiumDark,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAppBar(context),
              const SizedBox(height: 16),
              _buildTabs(),
              const SizedBox(height: 24),
              Expanded(
                child: Consumer<SubscriptionController>(
                  builder: (context, subscription, _) => FutureBuilder<AppUserModel?>(
                    future: _currentUserFuture,
                    builder: (context, userSnapshot) {
                      final user = userSnapshot.data;
                      final displayName = (user?.displayName ?? '').trim();
                      final username = (user?.username ?? '').trim();
                      final fallbackName = AuthService().currentUser?.email
                              ?.split('@')
                              .first
                              .trim() ??
                          '';
                      final name = displayName.isNotEmpty
                          ? displayName
                          : (fallbackName.isNotEmpty ? fallbackName : 'Your account');
                      final handle = username.isNotEmpty
                          ? '@${username.replaceAll('@', '')}'
                          : '@you';
                      final avatarUrl = (user?.profileImage ?? '').trim();
                      final isActive = subscription.isPaid;
                      final shouldShowCard = switch (_selectedTabIndex) {
                        0 => isActive,
                        1 => false,
                        2 => !isActive,
                        _ => true,
                      };
                      final emptyMessage = switch (_selectedTabIndex) {
                        0 => 'No active subscriptions',
                        1 => 'No paused subscriptions',
                        2 => 'No cancelled subscriptions',
                        _ => 'No subscriptions',
                      };

                      return StreamBuilder<List<CreatorSubscriptionRecord>>(
                        stream: _creatorSubscriptionService
                            .watchForCurrentSubscriber(),
                        builder: (context, creatorSnapshot) {
                          final creatorSubscriptions =
                              creatorSnapshot.data ?? const [];
                          final filteredCreatorSubscriptions = switch (
                            _selectedTabIndex
                          ) {
                            0 => creatorSubscriptions
                                .where((e) => e.isActive)
                                .toList(growable: false),
                            1 => creatorSubscriptions
                                .where((e) => e.isPaused)
                                .toList(growable: false),
                            2 => creatorSubscriptions
                                .where((e) => e.isCancelled)
                                .toList(growable: false),
                            _ => creatorSubscriptions,
                          };
                          final shouldShowPlanCard = switch (_selectedTabIndex) {
                            0 => shouldShowCard,
                            1 => false,
                            2 => !isActive,
                            _ => false,
                          };
                          final hasAnyCards =
                              shouldShowPlanCard ||
                              filteredCreatorSubscriptions.isNotEmpty;

                          return ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            children: [
                              if (shouldShowPlanCard)
                                _buildSubscriptionCard(
                                  name: name,
                                  handle: handle,
                                  status: isActive ? 'Active' : 'Cancelled',
                                  plan: subscription.planDisplayName,
                                  rate: isActive
                                      ? 'Auto-renewing'
                                      : 'No active plan',
                                  nextBilling:
                                      isActive ? 'Managed by app store' : null,
                                  image: avatarUrl,
                                  statusColor: isActive
                                      ? const Color(0xFFF81945)
                                      : Colors.white.withValues(alpha: 0.2),
                                  isCancelled: !isActive,
                                  onChangePlan: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChangePlanScreen(
                                          name: name,
                                          handle: handle,
                                          image: avatarUrl,
                                          currentPlan:
                                              subscription.planDisplayName,
                                          currentRate: isActive
                                              ? 'Auto-renewing'
                                              : 'No active plan',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              for (final record in filteredCreatorSubscriptions)
                                _buildSubscriptionCard(
                                  name: record.creatorName.isNotEmpty
                                      ? record.creatorName
                                      : 'Creator',
                                  handle: record.creatorHandle.isNotEmpty
                                      ? record.creatorHandle
                                      : '@creator',
                                  status: record.isActive
                                      ? 'Active'
                                      : record.isPaused
                                      ? 'Paused'
                                      : 'Cancelled',
                                  plan: 'Creator Subscription',
                                  rate:
                                      '${record.monthlyPriceLabel}/month • ${record.billingCycle}',
                                  nextBilling: record.isActive
                                      ? 'Auto-renewing'
                                      : null,
                                  image: record.creatorAvatarUrl,
                                  statusColor: record.isActive
                                      ? const Color(0xFFF81945)
                                      : Colors.white.withValues(alpha: 0.2),
                                  isPaused: record.isPaused,
                                  isCancelled: record.isCancelled,
                                  onChangePlan: null,
                                  onRemove: () => _showRemoveDialog(
                                    context,
                                    record.creatorName,
                                    record.creatorHandle,
                                    record.creatorAvatarUrl,
                                    onConfirm: () => _creatorSubscriptionService
                                        .cancelSubscription(
                                      creatorId: record.creatorId,
                                    ),
                                  ),
                                  onResume: () => _showResumeDialog(
                                    context,
                                    record.creatorName,
                                    record.creatorHandle,
                                    record.creatorAvatarUrl,
                                    'Creator Subscription',
                                    '${record.monthlyPriceLabel}/month',
                                    'Auto renew',
                                    onConfirm: () => _creatorSubscriptionService
                                        .resumeSubscription(
                                      creatorId: record.creatorId,
                                    ),
                                  ),
                                ),
                              if (!hasAnyCards)
                                Padding(
                                  padding: const EdgeInsets.only(top: 40),
                                  child: Center(
                                    child: Text(
                                      emptyMessage,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 40),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isValidNetworkUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.isAbsolute || uri.host.isEmpty) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Manage Subscriptions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'VyooO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(_tabs.length, (index) {
          bool selected = _selectedTabIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = index),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? const Color(0xFFF81945) : Colors.white10,
                    width: 1,
                  ),
                ),
                child: Text(
                  _tabs[index],
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white60,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSubscriptionCard({
    required String name,
    required String handle,
    required String status,
    required String plan,
    required String rate,
    String? nextBilling,
    required String image,
    required Color statusColor,
    bool isPaused = false,
    bool isCancelled = false,
    VoidCallback? onChangePlan,
    VoidCallback? onRemove,
    VoidCallback? onResume,
  }) {
    final hasImage = _isValidNetworkUrl(image);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white12,
                backgroundImage: hasImage ? NetworkImage(image.trim()) : null,
                child: hasImage
                    ? null
                    : const Icon(
                        Icons.person_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      handle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plan :',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      plan,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Rate :',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rate,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (!isCancelled)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Next Billing :',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        nextBilling ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (!isCancelled)
            Row(
              children: [
                if (onChangePlan != null) ...[
                  Expanded(
                    child: _buildSecondaryButton(
                      label: 'Change Plan',
                      onTap: onChangePlan,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: isPaused
                      ? _buildPrimaryButton(
                          label: 'Resume',
                          onTap: onResume ??
                              () => _showResumeDialog(
                                    context,
                                    name,
                                    handle,
                                    image,
                                    plan,
                                    rate,
                                    nextBilling ?? '',
                                  ),
                        )
                      : _buildSecondaryButton(
                          label: 'Remove',
                          onTap: onRemove ??
                              () => _showRemoveDialog(
                                    context,
                                    name,
                                    handle,
                                    image,
                                  ),
                        ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          gradient: AppGradients.vrGetStartedButtonGradient,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showRemoveDialog(
    BuildContext context,
    String name,
    String handle,
    String image,
    {Future<void> Function()? onConfirm}
  ) {
    final hasImage = _isValidNetworkUrl(image);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Remove Subscription?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white12,
                backgroundImage: hasImage ? NetworkImage(image.trim()) : null,
                child: hasImage
                    ? null
                    : const Icon(
                        Icons.person_rounded,
                        color: Colors.white70,
                      ),
              ),
              const SizedBox(height: 20),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(
                      text:
                          'Are you sure you want to cancel your\nsubscription to ',
                    ),
                    TextSpan(
                      text: handle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(
                      text:
                          '? You will no\nlonger be billed, and your access to premium\nfeatures and live streams will end at the close\nof your current billing period.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Divider(color: Colors.white10, height: 1),
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'No, keep',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const VerticalDivider(color: Colors.white10, thickness: 1),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          if (onConfirm != null) {
                            await onConfirm();
                          }
                        },
                        child: const Text(
                          'Yes, Remove',
                          style: TextStyle(
                            color: Color(0xFFF81945),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResumeDialog(
    BuildContext context,
    String name,
    String handle,
    String image,
    String plan,
    String rate,
    String date,
    {Future<void> Function()? onConfirm}
  ) {
    final hasImage = _isValidNetworkUrl(image);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      'Resume Subscription?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white12,
                          backgroundImage:
                              hasImage ? NetworkImage(image.trim()) : null,
                          child: hasImage
                              ? null
                              : const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white70,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                handle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildResumeRow('Plan', plan),
                    const SizedBox(height: 12),
                    _buildResumeRow('Rate', rate),
                    const SizedBox(height: 12),
                    _buildResumeRow('Date', date),
                    const SizedBox(height: 24),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 16),
                    _buildResumeRow('TOTAL', rate, isTotal: true),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 1),
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'No, Pause',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const VerticalDivider(color: Colors.white10, thickness: 1),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          if (onConfirm != null) {
                            await onConfirm();
                          }
                        },
                        child: const Text(
                          'Yes, Resume',
                          style: TextStyle(
                            color: Color(0xFFF81945),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResumeRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? Colors.white : Colors.white38,
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
