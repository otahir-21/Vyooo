import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/constants/app_colors.dart';

class CreatorSubscriptionScreen extends StatefulWidget {
  const CreatorSubscriptionScreen({
    super.key,
    required this.name,
    required this.handle,
    required this.avatarUrl,
    this.isVerified = false,
    this.monthlyPrice = 14.99,
    this.onSubscribe,
  });

  final String name;
  final String handle;
  final String avatarUrl;
  final bool isVerified;
  final VoidCallback? onSubscribe;

  /// Monthly base price. 3-month and yearly are derived from this.
  final double monthlyPrice;

  @override
  State<CreatorSubscriptionScreen> createState() =>
      _CreatorSubscriptionScreenState();
}

class _CreatorSubscriptionScreenState
    extends State<CreatorSubscriptionScreen> {
  int _selectedIndex = 2; // Default to 'Yearly' (Best value)
  bool _loading = false;

  String get _monthlyStr =>
      '\$${widget.monthlyPrice.toStringAsFixed(2)}/M';
  String get _threeMonthStr =>
      '\$${(widget.monthlyPrice * 0.80).toStringAsFixed(2)}/M';
  String get _yearlyStr =>
      '\$${(widget.monthlyPrice * 0.567).toStringAsFixed(2)}/M';

  Future<void> _onSubscribe() async {
    setState(() => _loading = true);
    // TODO: wire up RevenueCat purchase for creator subscription product
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Subscribed to ${widget.name}! 🎉'),
        backgroundColor: AppColors.pink,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const Text(
                      'Subscription',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      // Creator avatar
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.white12,
                        backgroundImage: widget.avatarUrl.isNotEmpty
                            ? NetworkImage(widget.avatarUrl)
                            : null,
                        child: widget.avatarUrl.isEmpty
                            ? Text(
                                widget.name.isNotEmpty
                                    ? widget.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700),
                              )
                            : null,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Subscribe to',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.handle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 14,
                            ),
                          ),
                          if (widget.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.pink, size: 16),
                          ],
                        ],
                      ),

                      const SizedBox(height: 36),

                      // Subscription options
                      _SubscriptionOption(
                        title: 'Monthly',
                        price: _monthlyStr,
                        isSelected: _selectedIndex == 0,
                        onTap: () => setState(() => _selectedIndex = 0),
                      ),
                      const SizedBox(height: 10),
                      _SubscriptionOption(
                        title: '3 Months',
                        price: _threeMonthStr,
                        badge: 'Popular',
                        badgeColor: const Color(0xFF22C55E),
                        isSelected: _selectedIndex == 1,
                        onTap: () => setState(() => _selectedIndex = 1),
                      ),
                      const SizedBox(height: 10),
                      _SubscriptionOption(
                        title: 'Yearly',
                        price: _yearlyStr,
                        badge: 'Best value',
                        badgeColor: const Color(0xFFFACC15),
                        isSelected: _selectedIndex == 2,
                        onTap: () => setState(() => _selectedIndex = 2),
                      ),

                      const SizedBox(height: 24),

                      // Benefits card
                      _BenefitsCard(),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: GestureDetector(
                  onTap: _loading
                      ? null
                      : () async {
                          if (widget.onSubscribe != null) {
                            widget.onSubscribe!.call();
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            return;
                          }
                          await _onSubscribe();
                        },
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFFDE106B)),
                          )
                        : const Text(
                            'Subscribe',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Text(
                  'By tapping Subscribe, you will be charged and your subscription will auto-renew for the same price and package length until you cancel via settings, and you agree to our Terms.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 10,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Subscription option row ───────────────────────────────────────────────────

class _SubscriptionOption extends StatelessWidget {
  const _SubscriptionOption({
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: const Color(0xFFDE106B), width: 1.5)
              : Border.all(
                  color: Colors.white.withValues(alpha: 0.12), width: 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFDE106B).withValues(alpha: 0.3),
                    blurRadius: 12,
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: isSelected ? 1.0 : 0.75),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const Spacer(),
            Text(
              price,
              style: TextStyle(
                color: Colors.white.withValues(alpha: isSelected ? 1.0 : 0.75),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Benefits card ─────────────────────────────────────────────────────────────

class _BenefitsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.12)),
            color: Colors.white.withValues(alpha: 0.03),
          ),
          child: const Column(
            children: [
              _BenefitItem(
                icon: FontAwesomeIcons.crown,
                title: 'Subscriber badge',
                subtitle:
                    'Match and chat with people anywhere in the world.',
              ),
              SizedBox(height: 16),
              _BenefitItem(
                icon: FontAwesomeIcons.star,
                title: 'Exclusive Content',
                subtitle:
                    'Match and chat with people anywhere in the world.',
              ),
              SizedBox(height: 16),
              _BenefitItem(
                icon: FontAwesomeIcons.ban,
                title: 'Ad-Free',
                subtitle:
                    'Match and chat with people anywhere in the world.',
              ),
            ],
          ),
        ),
        // Floating label
        Positioned(
          top: -13,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1A0020),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'Included with Subscription',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BenefitItem extends StatelessWidget {
  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FaIcon(icon, color: AppColors.pink, size: 15),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
