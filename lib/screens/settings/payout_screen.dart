import 'package:flutter/material.dart';
import '../../core/theme/app_gradients.dart';
import 'live_stream_revenue_screen.dart';
import 'subscription_revenue_screen.dart';

class PayoutScreen extends StatefulWidget {
  const PayoutScreen({super.key});

  @override
  State<PayoutScreen> createState() => _PayoutScreenState();
}

class _PayoutScreenState extends State<PayoutScreen> {
  String _selectedPeriod = 'This month';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.authGradient,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAppBar(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    const SizedBox(height: 24),
                    // Total Earnings header row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Earnings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        _PeriodDropdown(
                          value: _selectedPeriod,
                          onChanged: (v) => setState(() => _selectedPeriod = v!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Big earnings pill
                    Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        '€ 460325',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Revenue navigation rows
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
                      ),
                      child: Column(
                        children: [
                          _NavRow(
                            label: 'Live stream Revenue',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => const LiveStreamRevenueScreen()),
                            ),
                          ),
                          Divider(height: 1, thickness: 1, color: Colors.white.withValues(alpha: 0.15)),
                          _NavRow(
                            label: 'Subscription Revenue',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => const SubscriptionRevenueScreen()),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                    // Payout Summary section
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Payout Summary',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Summary rows
                    const _SummaryRow(label: 'Content Earnings', value: '€ 460325', isHeader: true),
                    const SizedBox(height: 20),
                    const _SummaryRow(label: 'Additional earnings', value: '€ 3100.40', isHeader: true),
                    const SizedBox(height: 12),
                    const _SummaryRow(label: 'Sponsers', value: '€ 2900.40', isSubRow: true),
                    const SizedBox(height: 28),
                    const _SummaryRow(label: 'Platform & Processing', value: '€ 3100.40', isHeader: true),
                    const SizedBox(height: 12),
                    const _SummaryRow(label: 'Commission', value: '€ 900.40', isSubRow: true),
                    const SizedBox(height: 8),
                    const _SummaryRow(label: 'Estimated tax', value: '€ 1002.40', isSubRow: true),
                    const SizedBox(height: 8),
                    const _SummaryRow(label: 'Payment processing', value: '€ 579.66', isSubRow: true),
                    const SizedBox(height: 24),
                    const Divider(color: Colors.white24, thickness: 1),
                    const SizedBox(height: 24),
                    const _SummaryRow(
                      label: 'Estimated Payout',
                      value: '€ 460325',
                      isHeader: true,
                      valueColor: Color(0xFF4ADE80),
                    ),
                    const SizedBox(height: 48),
                    // Withdraw button
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Withdraw',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                      ),
                    ),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                SizedBox(width: 16),
                Text(
                  'VyooO Payouts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
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
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Period Dropdown ────────────────────────────────────────────────────────

class _PeriodDropdown extends StatelessWidget {
  const _PeriodDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF2D072D),
          icon: const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 20),
          ),
          isDense: true,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          items: const [
            DropdownMenuItem(value: 'This month', child: Text('This month')),
            DropdownMenuItem(value: 'Last month', child: Text('Last month')),
            DropdownMenuItem(value: 'This year', child: Text('This year')),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─── Navigation Row ─────────────────────────────────────────────────────────

class _NavRow extends StatelessWidget {
  const _NavRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Summary Row ─────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isHeader = false,
    this.isSubRow = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool isHeader;
  final bool isSubRow;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final double fontSize = isHeader ? 17 : 14;
    final FontWeight fontWeight = isHeader ? FontWeight.w700 : FontWeight.w400;
    final Color textColor = isSubRow ? Colors.white.withValues(alpha: 0.5) : Colors.white;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: fontWeight,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? textColor,
            fontSize: fontSize,
            fontWeight: fontWeight,
          ),
        ),
      ],
    );
  }
}

