import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/subscription/subscription_controller.dart';
import 'creator_subscription_screen.dart';

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
      for (final pkg in _offerings!.current!.availablePackages) {
        final id = pkg.identifier.toLowerCase();
        if (id.contains('standard')) {
          standardPkg = pkg;
        } else if (id.contains('subscriber')) {
          subscriberPkg = pkg;
        } else if (id.contains('creator')) {
          creatorPkg = pkg;
        }
      }
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
              child: Column(
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
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'VyooO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                      ),
                    ),
                  ),

                  // Title & Subtitle
                  const SizedBox(height: 48),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Choose your plan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Stream Exclusive Live streams, Immersive VR\nContent, also Monetize Content and many more',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),

                  // Plan Cards
                  const SizedBox(height: 40),
                  _PlanCardsRow(
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
                  const SizedBox(height: 48),
                  const Expanded(child: _FeatureComparisonTable()),

                  // Bottom Action
                  const SizedBox(height: 16),
                  _UpgradeButton(
                    selectedIndex: _selectedIndex,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CreatorSubscriptionScreen(
                            name: 'Matt Rife',
                            handle: '@mattrife_x',
                            avatarUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?q=80&w=1287&auto=format&fit=crop',
                            isVerified: true,
                            onSubscribe: () {
                              if (_selectedIndex == 0 && standardPkg != null) {
                                controller.purchaseStandard(standardPkg);
                              } else if (_selectedIndex == 1 && subscriberPkg != null) {
                                controller.purchaseSubscriber(subscriberPkg);
                              } else if (_selectedIndex == 2 && creatorPkg != null) {
                                controller.purchaseCreator(creatorPkg);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),

                  // Legal text
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'By tapping Continue, you will be charged, your subscription will auto-renew for the same price and package length until you cancel via App Store settings, and you agree to our Terms.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
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
    required this.selectedIndex,
    required this.onSelect,
    required this.standardPrice,
    required this.subscriberPrice,
    required this.creatorPrice,
  });

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
            title: 'Standard',
            price: standardPrice,
            isSelected: selectedIndex == 0,
            onTap: () => onSelect(0),
          ),
          const SizedBox(width: 8),
          _PlanCard(
            title: 'Subscriber',
            price: subscriberPrice,
            badge: 'Popular',
            badgeColor: const Color(0xFF22C55E),
            isSelected: selectedIndex == 1,
            onTap: () => onSelect(1),
          ),
          const SizedBox(width: 8),
          _PlanCard(
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
    required this.title,
    required this.price,
    this.badge,
    this.badgeColor,
    required this.isSelected,
    required this.onTap,
  });

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
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: const Color(0xFFDE106B), width: 2)
                : Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFDE106B).withOpacity(0.5),
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
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (badge != null) const SizedBox(height: 16),
                    Text(
                      price,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
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
  const _FeatureComparisonTable();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                const Expanded(flex: 3, child: SizedBox()),
                _headerLabel('Standard'),
                _headerLabel('Subscriber'),
                _headerLabel('Creator'),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _FeatureRow(
                  'Watch live content',
                  'Credit card',
                  'After 12 hours',
                  'Watch Instantly',
                ),
                _FeatureRow('Create Profile', false, true, true),
                _FeatureRow('Verification', false, true, true),
                _FeatureRow('Upload content', false, true, true),
                _FeatureRow('Monetize content', false, false, true),
                _FeatureRow('Offer subscriptions', false, false, true),
                _FeatureRow(
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

  Widget _headerLabel(String label) {
    return Expanded(
      flex: 2,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow(this.feature, this.standard, this.subscriber, this.creator);

  final String feature;
  final dynamic standard;
  final dynamic subscriber;
  final dynamic creator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              feature,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
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
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : const Icon(Icons.close, color: Colors.white, size: 16);
    } else {
      content = Text(
        value.toString(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w400,
        ),
      );
    }
    return Expanded(flex: 2, child: Center(child: content));
  }
}

class _UpgradeButton extends StatelessWidget {
  const _UpgradeButton({required this.selectedIndex, required this.onPressed});

  final int selectedIndex;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FaIcon(
                FontAwesomeIcons.crown,
                color: Color(0xFFDE106B),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Upgrade',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
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
