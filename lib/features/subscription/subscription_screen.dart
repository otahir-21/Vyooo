import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

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
  bool _fetchingOfferings = false;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
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
        const SnackBar(content: Text('Plans not available yet. Try again shortly.')),
      );
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
        SnackBar(content: Text(controller.purchaseError ?? 'Purchase failed. Please try again.')),
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

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SubscriptionController>();
    final isLoading = controller.isLoading || _fetchingOfferings;

    // Map packages if available
    Package? standardPkg;
    Package? subscriberPkg;
    Package? creatorPkg;

    if (_offerings?.current != null) {
      final mapped = SubscriptionPackageMapper.fromOffering(_offerings!.current);
      standardPkg = mapped.standard;
      subscriberPkg = mapped.subscriber;
      creatorPkg = mapped.creator;
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
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
                stops: [0.0, 0.4, 0.7, 1.0],
              ),
            ),
            child: SafeArea(
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
                  // Restore & Close
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
                  // Logo
                      SizedBox(height: isCompact ? 16 : 24),
                      Center(
                        child: Text(
                      'VyooO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: logoSize,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1,
                          ),
                        ),
                      ),

                  // Title & Subtitle
                      SizedBox(height: isCompact ? 30 : 48),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Stream Exclusive Live streams, Immersive VR\nContent, also Monetize Content and many more',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: subtitleSize,
                        height: 1.4,
                      ),
                    ),
                  ),

                  // Plan Cards
                      SizedBox(height: sectionGap),
                  _PlanCardsRow(
                        compact: isCompact,
                    selectedIndex: _selectedIndex,
                    onSelect: (i) => setState(() => _selectedIndex = i),
                    standardPrice:
                        standardPkg?.storeProduct.priceString ?? 'FREE',
                    subscriberPrice:
                        subscriberPkg?.storeProduct.priceString ?? '\$4.99/M',
                    creatorPrice:
                        creatorPkg?.storeProduct.priceString ?? '\$19.99/M',
                  ),

                  // Comparison Table
                      SizedBox(height: tableGap),
                      Expanded(child: _FeatureComparisonTable(compact: isCompact)),

                  // Bottom Action
                      SizedBox(height: isCompact ? 12 : 16),
                  _UpgradeButton(
                        compact: isCompact,
                    selectedIndex: _selectedIndex,
                    isLoading: isLoading,
                    onPressed: () => _handlePurchase(
                      controller,
                      selectedIndex: _selectedIndex,
                      standardPkg: standardPkg,
                      subscriberPkg: subscriberPkg,
                      creatorPkg: creatorPkg,
                    ),
                  ),

                  // Legal text
                      SizedBox(height: isCompact ? 10 : 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'By tapping Continue, you will be charged, your subscription will auto-renew for the same price and package length until you cancel via App Store settings, and you agree to our Terms.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: legalSize,
                      ),
                    ),
                  ),
                      SizedBox(height: isCompact ? 14 : 24),
                    ],
                  );
                },
              ),
            ),
          ),
          if (isLoading)
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
    required this.standardPrice,
    required this.subscriberPrice,
    required this.creatorPrice,
  });

  final bool compact;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String standardPrice;
  final String subscriberPrice;
  final String creatorPrice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _PlanCard(
            compact: compact,
            title: 'Standard',
            price: standardPrice,
            isSelected: selectedIndex == 0,
            onTap: () => onSelect(0),
          ),
          SizedBox(width: compact ? 6 : 8),
          _PlanCard(
            compact: compact,
            title: 'Subscriber',
            price: subscriberPrice,
            badge: 'Popular',
            badgeColor: const Color(0xFF22C55E),
            isSelected: selectedIndex == 1,
            onTap: () => onSelect(1),
          ),
          SizedBox(width: compact ? 6 : 8),
          _PlanCard(
            compact: compact,
            title: 'Creator',
            price: creatorPrice,
            badge: 'Best value',
            badgeColor: const Color(0xFFFACC15),
            isSelected: selectedIndex == 2,
            onTap: () => onSelect(2),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.compact,
    required this.title,
    required this.price,
    this.badge,
    this.badgeColor,
    required this.isSelected,
    required this.onTap,
  });

  final bool compact;
  final String title;
  final String price;
  final String? badge;
  final Color? badgeColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: compact ? 92 : 100,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: const Color(0xFFDE106B), width: 2)
                : Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFDE106B).withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              if (badge != null)
                Positioned(
                  top: 8,
                  left: 8,
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
                        color: Colors.black,
                        fontSize: compact ? 7 : 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (badge != null) SizedBox(height: compact ? 14 : 16),
                    Text(
                      price,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 14 : 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: compact ? 3 : 4),
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 13 : 14,
                        fontWeight: FontWeight.w600,
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

class _FeatureComparisonTable extends StatelessWidget {
  const _FeatureComparisonTable({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
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
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
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
                _FeatureRow('Offer subscriptions', false, false, true, compact: compact),
                _FeatureRow(
                  compact: compact,
                  'Video Quality',
                  'SD (480p)',
                  'Full HD (1080p)',
                  'Upto 4K',
                ),
              ],
            ),
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
  const _FeatureRow(this.feature, this.standard, this.subscriber, this.creator, {required this.compact});

  final String feature;
  final dynamic standard;
  final dynamic subscriber;
  final dynamic creator;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: compact ? 10 : 12),
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
    this.isLoading = false,
  });

  final bool compact;
  final int selectedIndex;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: isLoading ? null : onPressed,
        child: Container(
          height: compact ? 44 : 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: isLoading
              ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFDE106B))))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const FaIcon(FontAwesomeIcons.crown, color: Color(0xFFDE106B), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Upgrade',
                      style: TextStyle(color: Colors.black, fontSize: compact ? 16 : 18, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
