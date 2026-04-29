import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/app_gradient_background.dart';
import '../../core/config/app_links.dart';
import '../../core/subscription/membership_tier.dart';
import '../../core/subscription/subscription_controller.dart';
import '../../core/subscription/subscription_package_mapper.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key, this.showRestoreButton = true});

  final bool showRestoreButton;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  int _selectedIndex = 1; // Default to 'Subscriber' (Popular)
  Offerings? _offerings;

  /// Start true so the first frame doesn’t flash “couldn’t reach store” before [ _loadOfferings] runs.
  bool _fetchingOfferings = true;
  bool _closingForActivePlan = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initScreenState());
  }

  Future<void> _initScreenState() async {
    if (!mounted) return;
    final controller = context.read<SubscriptionController>();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isPaid = await controller.reconcilePaidStatus(firebaseUid: uid);
    if (!mounted) return;
    if (isPaid) {
      setState(() => _closingForActivePlan = true);
      Navigator.of(context).pop();
      return;
    }
    await _loadOfferings();
  }

  MembershipTier _selectedTierFromIndex(int index) {
    switch (index) {
      case 0:
        return MembershipTier.standard;
      case 1:
        return MembershipTier.subscriber;
      case 2:
        return MembershipTier.creator;
      default:
        return MembershipTier.none;
    }
  }

  Future<void> _handlePurchase(
    SubscriptionController controller, {
    required int selectedIndex,
    Package? standardPkg,
    Package? subscriberPkg,
    Package? creatorPkg,
  }) async {
    final pkg = selectedIndex == 0
        ? standardPkg
        : selectedIndex == 1
        ? subscriberPkg
        : creatorPkg;
    if (pkg == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plans not available yet. Try again shortly.'),
        ),
      );
      return;
    }
    final selectedTier = _selectedTierFromIndex(selectedIndex);
    if (controller.currentTier == selectedTier) {
      Navigator.of(context).pop();
      return;
    }
    try {
      final purchased = await controller.purchase(pkg);
      if (!mounted) return;
      if (purchased) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription activated! Welcome 🎉')),
        );
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            controller.purchaseError ?? 'Purchase failed. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> _loadOfferings() async {
    setState(() => _fetchingOfferings = true);
    final controller = context.read<SubscriptionController>();
    final results = await controller.fetchOfferings();
    if (mounted) {
      setState(() {
        _offerings = results;
        _fetchingOfferings = false;
      });
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open link.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_closingForActivePlan) {
      return const Scaffold(
        body: ColoredBox(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(color: Color(0xFFDE106B)),
          ),
        ),
      );
    }
    final controller = context.watch<SubscriptionController>();
    // Only block the screen during purchase — not while fetching offerings (that hid all plans).
    final isPurchasing = controller.isLoading;

    final offering = SubscriptionPackageMapper.resolveCurrentOffering(
      _offerings,
    );
    Package? standardPkg;
    Package? subscriberPkg;
    Package? creatorPkg;

    if (offering != null) {
      final mapped = SubscriptionPackageMapper.fromOffering(offering);
      standardPkg = mapped.standard;
      subscriberPkg = mapped.subscriber;
      creatorPkg = mapped.creator;
    }

    final plansLoaded =
        offering != null && offering.availablePackages.isNotEmpty;
    final plansLoadFailed =
        !_fetchingOfferings && _offerings != null && !plansLoaded;
    final offeringsUnreachable = !_fetchingOfferings && _offerings == null;

    final selectedForDisclosure = _selectedIndex == 0
        ? standardPkg
        : _selectedIndex == 1
        ? subscriberPkg
        : creatorPkg;
    final isPaidPlanSelected =
        selectedForDisclosure != null &&
        selectedForDisclosure.storeProduct.price > 0;
    final alreadyHasPaidPlan = controller.isPaid;

    return Scaffold(
      body: Stack(
        children: [
          AppGradientBackground(
            type: GradientType.premiumDark,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact =
                    constraints.maxWidth < 390 || constraints.maxHeight < 780;
                final logoSize = isCompact ? 40.0 : 48.0;
                final titleSize = isCompact ? 28.0 : 32.0;
                final subtitleSize = isCompact ? 13.0 : 14.0;
                final sectionGap = isCompact ? 28.0 : 40.0;
                final tableGap = isCompact ? 28.0 : 48.0;
                final legalSize = isCompact ? 9.0 : 10.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Restore & Close (stay pinned; rest scrolls)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (widget.showRestoreButton)
                            TextButton(
                              onPressed: () => controller.restorePurchases(),
                              child: const Text(
                                'Restore',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: isCompact ? 8 : 12),
                            Center(
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Vyoo',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: logoSize,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -1,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'O',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: logoSize,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: -1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: isCompact ? 24 : 36),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Text(
                                'Choose your plan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(height: isCompact ? 8 : 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Text(
                                'Stream Exclusive Live streams, Immersive VR\nContent, also Monetize Content and many more',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: subtitleSize,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            if (_fetchingOfferings) ...[
                              SizedBox(height: isCompact ? 12 : 16),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24),
                                child: LinearProgressIndicator(
                                  minHeight: 3,
                                  color: Color(0xFFDE106B),
                                  backgroundColor: Colors.white12,
                                ),
                              ),
                            ],
                            if (plansLoadFailed || offeringsUnreachable) ...[
                              SizedBox(height: isCompact ? 12 : 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.amber.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          offeringsUnreachable
                                              ? 'We couldn’t reach the App Store for plans. Check your connection and try again.'
                                              : 'Subscription products aren’t available yet from the store. Confirm RevenueCat offerings or try again shortly.',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.9,
                                            ),
                                            fontSize: isCompact ? 12.0 : 13.0,
                                            height: 1.35,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        TextButton.icon(
                                          onPressed: _fetchingOfferings
                                              ? null
                                              : _loadOfferings,
                                          icon: const Icon(
                                            Icons.refresh,
                                            color: Color(0xFFDE106B),
                                            size: 20,
                                          ),
                                          label: const Text(
                                            'Retry loading plans',
                                            style: TextStyle(
                                              color: Color(0xFFDE106B),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            SizedBox(height: sectionGap),
                            _PlanCardsRow(
                              compact: isCompact,
                              selectedIndex: _selectedIndex,
                              onSelect: (i) =>
                                  setState(() => _selectedIndex = i),
                              standardPkg: standardPkg,
                              subscriberPkg: subscriberPkg,
                              creatorPkg: creatorPkg,
                            ),
                            SizedBox(height: tableGap),
                            _FeatureComparisonTable(compact: isCompact),
                            SizedBox(height: isCompact ? 16 : 20),
                            _UpgradeButton(
                              compact: isCompact,
                              selectedIndex: _selectedIndex,
                              title: alreadyHasPaidPlan
                                  ? 'Current plan: ${controller.planDisplayName}'
                                  : 'Upgrade',
                              disabled:
                                  alreadyHasPaidPlan &&
                                  controller.currentTier ==
                                      _selectedTierFromIndex(_selectedIndex),
                              isLoading: isPurchasing,
                              onPressed: () => _handlePurchase(
                                controller,
                                selectedIndex: _selectedIndex,
                                standardPkg: standardPkg,
                                subscriberPkg: subscriberPkg,
                                creatorPkg: creatorPkg,
                              ),
                            ),
                            SizedBox(height: isCompact ? 10 : 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: _SubscriptionLegalFooter(
                                fontSize: legalSize,
                                isPaidPlanSelected: isPaidPlanSelected,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(
                                top: isCompact ? 8 : 10,
                                bottom: isCompact ? 24 : 32,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TextButton(
                                    onPressed: () => _openExternalUrl(
                                      AppLinks.privacyPolicy,
                                    ),
                                    child: Text(
                                      'Privacy Policy',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                        fontSize: legalSize + 1,
                                        decoration: TextDecoration.underline,
                                        decorationColor: Colors.white54,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '·',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.4,
                                      ),
                                      fontSize: legalSize + 2,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        _openExternalUrl(AppLinks.termsOfUse),
                                    child: Text(
                                      'Terms of Use',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                        fontSize: legalSize + 1,
                                        decoration: TextDecoration.underline,
                                        decorationColor: Colors.white54,
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
                  ],
                );
              },
            ),
          ),
          if (isPurchasing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFDE106B)),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanCardsRow extends StatelessWidget {
  const _PlanCardsRow({
    required this.compact,
    required this.selectedIndex,
    required this.onSelect,
    required this.standardPkg,
    required this.subscriberPkg,
    required this.creatorPkg,
  });

  final bool compact;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Package? standardPkg;
  final Package? subscriberPkg;
  final Package? creatorPkg;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlanCard(
            compact: compact,
            displayTitle: _planTitle(standardPkg, 'Standard'),
            priceLine: _priceLine(standardPkg, fallback: 'FREE'),
            periodLine: _periodLine(standardPkg, isFreeFallback: true),
            pricePerUnitLine: _pricePerMonthLine(standardPkg),
            isSelected: selectedIndex == 0,
            onTap: () => onSelect(0),
          ),
          SizedBox(width: compact ? 6 : 8),
          _PlanCard(
            compact: compact,
            displayTitle: _planTitle(subscriberPkg, 'Subscriber'),
            priceLine: _priceLine(subscriberPkg, fallback: '—'),
            periodLine: _periodLine(subscriberPkg),
            pricePerUnitLine: _pricePerMonthLine(subscriberPkg),
            badge: 'Popular',
            badgeColor: const Color(0xFF22C55E),
            isSelected: selectedIndex == 1,
            onTap: () => onSelect(1),
          ),
          SizedBox(width: compact ? 6 : 8),
          _PlanCard(
            compact: compact,
            displayTitle: _planTitle(creatorPkg, 'Creator'),
            priceLine: _priceLine(creatorPkg, fallback: '—'),
            periodLine: _periodLine(creatorPkg),
            pricePerUnitLine: _pricePerMonthLine(creatorPkg),
            badge: 'Best value',
            badgeColor: const Color(0xFFFACC15),
            isSelected: selectedIndex == 2,
            onTap: () => onSelect(2),
          ),
        ],
      ),
    );
  }

  static String _planTitle(Package? pkg, String fallbackLabel) {
    final t = pkg?.storeProduct.title.trim();
    if (t == null || t.isEmpty) return fallbackLabel;
    return t;
  }

  static String _priceLine(Package? pkg, {required String fallback}) {
    return pkg?.storeProduct.priceString ?? fallback;
  }

  static String? _periodLine(Package? pkg, {bool isFreeFallback = false}) {
    final p = pkg?.storeProduct.subscriptionPeriod;
    final label = subscriptionPeriodDisplay(p);
    if (label != null) return label;
    if (isFreeFallback) return 'No recurring subscription';
    return null;
  }

  static String? _pricePerMonthLine(Package? pkg) {
    if (pkg == null) return null;
    final s = pkg.storeProduct.pricePerMonthString;
    if (s == null || s.isEmpty) return null;
    if (pkg.storeProduct.price <= 0) return null;
    return '$s / mo';
  }
}

/// ISO 8601 duration from StoreKit / Play (e.g. P1M, P1Y).
String? subscriptionPeriodDisplay(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final m = RegExp(r'^P(\d+)([DMWY])$').firstMatch(iso);
  if (m == null) return iso;
  final n = int.tryParse(m.group(1)!) ?? 1;
  final u = m.group(2)!;
  final unit = switch (u) {
    'D' => n == 1 ? 'day' : 'days',
    'W' => n == 1 ? 'week' : 'weeks',
    'M' => n == 1 ? 'month' : 'months',
    'Y' => n == 1 ? 'year' : 'years',
    _ => '',
  };
  return n == 1 ? '1 $unit' : '$n $unit';
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.compact,
    required this.displayTitle,
    required this.priceLine,
    this.periodLine,
    this.pricePerUnitLine,
    this.badge,
    this.badgeColor,
    required this.isSelected,
    required this.onTap,
  });

  final bool compact;

  /// Store product title when available (Apple subscription display name).
  final String displayTitle;
  final String priceLine;
  final String? periodLine;
  final String? pricePerUnitLine;
  final String? badge;
  final Color? badgeColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final titleSize = compact ? 11.0 : 12.0;
    final priceSize = compact ? 14.0 : 16.0;
    // Fixed height: a Stack with only Positioned children gets near-zero height inside a Row
    // when vertical constraints are loose, which hid all plan text (badges still drew).
    final cardHeight = compact ? 132.0 : 148.0;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: cardHeight,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 12 : 16,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF5A214D)
                : const Color(0xFF4A183D),
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: const Color(0xFFE81E57), width: 2)
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFE81E57).withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (badge != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 7 : 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                SizedBox(height: compact ? 18 : 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      priceLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: priceSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: compact ? 6 : 8),
                    Text(
                      displayTitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleSize + 2,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
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
}

class _SubscriptionLegalFooter extends StatelessWidget {
  const _SubscriptionLegalFooter({
    required this.fontSize,
    required this.isPaidPlanSelected,
  });

  final double fontSize;
  final bool isPaidPlanSelected;

  @override
  Widget build(BuildContext context) {
    final body = isPaidPlanSelected
        ? 'When you continue, a subscription purchase may be completed. '
              'The price and billing period for each plan are shown above. '
              'Payment is charged to your Apple ID. The subscription renews automatically '
              'for the same price and duration until you turn off auto-renew in '
              'Settings → Apple ID → Subscriptions at least 24 hours before the period ends.'
        : 'Standard may be offered at no charge. Subscriber and Creator are auto-renewing '
              'subscriptions: price and period are shown above. When you purchase a paid plan, '
              'payment is charged to your Apple ID and the subscription renews until canceled '
              'in Settings → Apple ID → Subscriptions.';

    return Text(
      body,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.55),
        fontSize: fontSize,
        height: 1.35,
      ),
    );
  }
}

class _FeatureComparisonTable extends StatelessWidget {
  const _FeatureComparisonTable({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF350A2A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16,
              vertical: compact ? 12 : 16,
            ),
            child: Row(
              children: [
                const Expanded(flex: 3, child: SizedBox()),
                _headerLabel('Standard', compact),
                _headerLabel('Subscriber', compact),
                _headerLabel('Creator', compact),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          // Intrinsic-height rows: parent [SingleChildScrollView] scrolls the full list
          // (Monetize / Offer subscriptions / Video Quality, etc.).
          _FeatureRow(
            compact: compact,
            'Watch live content',
            'Credit card',
            'After 12 hours',
            'Watch Instantly',
          ),
          _FeatureRow('Create Profile', false, true, true, compact: compact),
          _FeatureRow('Verification', false, true, true, compact: compact),
          _FeatureRow('Upload content', false, true, true, compact: compact),
          _FeatureRow('Monetize content', false, false, true, compact: compact),
          _FeatureRow(
            'Offer subscriptions',
            false,
            false,
            true,
            compact: compact,
          ),
          _FeatureRow(
            compact: compact,
            'Video Quality',
            'SD (480p)',
            'Full HD (1080p)',
            'Upto 4K',
          ),
        ],
      ),
    );
  }

  Widget _headerLabel(String label, bool compact) {
    return Expanded(
      flex: 2,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow(
    this.feature,
    this.standard,
    this.subscriber,
    this.creator, {
    required this.compact,
  });

  final String feature;
  final dynamic standard;
  final dynamic subscriber;
  final dynamic creator;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 10 : 12,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              feature,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          _valueCell(standard),
          _valueCell(subscriber),
          _valueCell(creator),
        ],
      ),
    );
  }

  Widget _valueCell(dynamic value) {
    Widget content;
    if (value is bool) {
      content = value
          ? Icon(Icons.check, color: Colors.white, size: compact ? 14 : 16)
          : Icon(Icons.close, color: Colors.white, size: compact ? 14 : 16);
    } else {
      content = Text(
        value.toString(),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w400,
        ),
      );
    }
    return Expanded(flex: 2, child: Center(child: content));
  }
}

class _UpgradeButton extends StatelessWidget {
  const _UpgradeButton({
    required this.compact,
    required this.selectedIndex,
    required this.onPressed,
    required this.title,
    this.disabled = false,
    this.isLoading = false,
  });

  final bool compact;
  final int selectedIndex;
  final VoidCallback onPressed;
  final String title;
  final bool disabled;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: (isLoading || disabled) ? null : onPressed,
        child: Container(
          height: compact ? 44 : 48,
          decoration: BoxDecoration(
            color: disabled ? Colors.white54 : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: isLoading
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFFDE106B),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.crown,
                      color: Color(0xFFDE106B),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: compact ? 14 : 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
