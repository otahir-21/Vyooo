import 'package:flutter/material.dart';
import '../../../core/theme/app_gradients.dart';

class ChangePlanScreen extends StatefulWidget {
  const ChangePlanScreen({
    super.key,
    required this.name,
    required this.handle,
    required this.image,
    required this.currentPlan,
    required this.currentRate,
  });

  final String name;
  final String handle;
  final String image;
  final String currentPlan;
  final String currentRate;

  @override
  State<ChangePlanScreen> createState() => _ChangePlanScreenState();
}

class _ChangePlanScreenState extends State<ChangePlanScreen> {
  int _selectedPlanIndex =
      1; // Default to '3 Months' as shown in middle screenshot

  final List<Map<String, dynamic>> _plans = [
    {'title': 'Monthly', 'price': '4.99', 'total': '4.99', 'label': null},
    {
      'title': '3 Months',
      'price': '7.99',
      'total': '23.97',
      'label': 'Popular',
    },
    {
      'title': 'Yearly',
      'price': '8.50',
      'total': '102.00',
      'label': 'Best value',
    },
  ];

  @override
  Widget build(BuildContext context) {
    String buttonLabel = 'Upgrade to Monthly';
    if (_selectedPlanIndex == 0) {
      buttonLabel = 'Downgrade to Monthly';
    } else if (_selectedPlanIndex == 1) {
      buttonLabel = 'Current plan';
    } else if (_selectedPlanIndex == 2) {
      buttonLabel = 'Upgrade to Yearly';
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppGradients.authGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAppBar(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    const SizedBox(height: 20),
                    _buildProfileHeader(),
                    const SizedBox(height: 32),
                    const Text(
                      'Select New Plan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(_plans.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildPlanOption(index),
                      );
                    }),
                    const SizedBox(height: 8),
                    if (_selectedPlanIndex == 2) _buildSavingsBanner(),
                    const SizedBox(height: 24),
                    _buildActionButton(
                      buttonLabel,
                      isCurrentPlan: _selectedPlanIndex == 1,
                    ),
                    const SizedBox(height: 20),
                    _buildDisclaimer(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                SizedBox(width: 12),
                Text(
                  'Change plan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundImage: NetworkImage(widget.image),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.check_circle, color: Color(0xFFF81945), size: 18),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          widget.handle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF81945).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFF81945).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFFF81945),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.currentPlan} Plan - € ${widget.currentRate}/mo',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanOption(int index) {
    bool selected = _selectedPlanIndex == index;
    bool isCurrent = index == 1; // Quarterly is current
    final plan = _plans[index];

    return GestureDetector(
      onTap: () => setState(() => _selectedPlanIndex = index),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFFF81945)
                : Colors.white.withValues(alpha: 0.08),
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFFF81945).withValues(alpha: 0.2),
                    blurRadius: 15,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  plan['title'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (plan['label'] != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: index == 2
                          ? const Color(0xFFFACC15)
                          : const Color(0xFF4ADE80),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      plan['label'],
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '€ ${plan['price']}/M',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (isCurrent || selected) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF81945),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Current plan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    '€ ${plan['total']} Total',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSavingsBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF4ADE80).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.stars, color: Color(0xFF4ADE80), size: 18),
          SizedBox(width: 12),
          Text(
            'Switch to Annual and save \$24 a year vs Quarterly',
            style: TextStyle(
              color: Color(0xFF4ADE80),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, {bool isCurrentPlan = false}) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: isCurrentPlan
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: isCurrentPlan ? Colors.white54 : Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 11,
            height: 1.4,
          ),
          children: [
            const TextSpan(
              text:
                  'By tapping Subscribe, you will be charged and your subscription will auto-renew for the same price and package length until you cancel via settings, and you agree to our ',
            ),
            TextSpan(
              text: 'Terms',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                decoration: TextDecoration.underline,
              ),
            ),
            const TextSpan(text: '.'),
          ],
        ),
      ),
    );
  }
}
