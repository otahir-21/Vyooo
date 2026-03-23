import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CreatorSubscriptionScreen extends StatefulWidget {
  const CreatorSubscriptionScreen({
    super.key,
    required this.name,
    required this.handle,
    required this.avatarUrl,
    this.isVerified = false,
    this.onSubscribe,
  });

  final String name;
  final String handle;
  final String avatarUrl;
  final bool isVerified;
  final VoidCallback? onSubscribe;

  @override
  State<CreatorSubscriptionScreen> createState() => _CreatorSubscriptionScreenState();
}

class _CreatorSubscriptionScreenState extends State<CreatorSubscriptionScreen> {
  int _selectedIndex = 2; // Default to 'Yearly' (Best value)

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
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
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
                      // Creator Profile
                      Center(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundImage: widget.avatarUrl.isNotEmpty 
                                ? NetworkImage(widget.avatarUrl) 
                                : null,
                              backgroundColor: Colors.grey[800],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Subscribe to',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  widget.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (widget.isVerified) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFFEF4444), size: 18),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.handle,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 40),

                      // Subscription Options
                      _SubscriptionOption(
                        title: 'Monthly',
                        price: '\$14.99/M',
                        isSelected: _selectedIndex == 0,
                        onTap: () => setState(() => _selectedIndex = 0),
                      ),
                      const SizedBox(height: 12),
                      _SubscriptionOption(
                        title: '3 Months',
                        price: '\$11.99/M',
                        badge: 'Popular',
                        badgeColor: const Color(0xFF22C55E),
                        isSelected: _selectedIndex == 1,
                        onTap: () => setState(() => _selectedIndex = 1),
                      ),
                      const SizedBox(height: 12),
                      _SubscriptionOption(
                        title: 'Yearly',
                        price: '\$8.50/M',
                        badge: 'Best value',
                        badgeColor: const Color(0xFFFACC15),
                        isSelected: _selectedIndex == 2,
                        onTap: () => setState(() => _selectedIndex = 2),
                      ),

                      const SizedBox(height: 24),

                      // Benefits Section
                      _BenefitsCard(),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // Bottom Area
              _SubscribeButton(onPressed: widget.onSubscribe),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'By tapping Subscribe, you will be charged and your subscription will auto-renew for the same price and package length until you cancel via settings, and you agree to our Terms.',
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
    );
  }
}

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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: isSelected 
            ? Border.all(color: const Color(0xFFDE106B), width: 2)
            : Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFFDE106B).withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 0,
            )
          ] : null,
        ),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            const Spacer(),
            Text(
              price,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
            border: Border.all(color: Colors.white.withOpacity(0.15)),
            color: Colors.white.withOpacity(0.02),
          ),
          child: Column(
            children: [
              _BenefitItem(
                title: 'Subscriber badge',
                subtitle: 'Match and chat with people anywhere in the world.',
              ),
              const SizedBox(height: 16),
              _BenefitItem(
                title: 'Exclusive Content',
                subtitle: 'Match and chat with people anywhere in the world.',
              ),
              const SizedBox(height: 16),
              _BenefitItem(
                title: 'Ad-Free',
                subtitle: 'Match and chat with people anywhere in the world.',
              ),
            ],
          ),
        ),
        Positioned(
          top: -12,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.5)),
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
  const _BenefitItem({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: FaIcon(FontAwesomeIcons.crown, color: Color(0xFFDE106B), size: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
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

class _SubscribeButton extends StatelessWidget {
  const _SubscribeButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: const Text(
            'Subscribe',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
