import 'package:flutter/material.dart';
import 'package:vyooo/core/widgets/app_gradient_background.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  int _selectedTabIndex = 0;
  final List<String> _tabs = [
    'All',
    'Live Streams',
    'Subscriptions',
    'Withdrawals',
  ];

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
              _buildFilterAndTotal(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    const SizedBox(height: 16),
                    _buildSectionHeader('Today'),
                    _buildTransactionItem(
                      name: 'Tech Talk Live',
                      type: 'Live Stream',
                      amount: '€ 45.99',
                      status: 'Settled',
                      accentColor: const Color(0xFFF81945),
                      icon: Icons.video_camera_back_rounded,
                      onTap: () => _showReceipt(context),
                    ),
                    _buildTransactionItem(
                      name: 'New Subscriber',
                      type: '@jess__d • Annual Plan',
                      amount: '€ 102.99',
                      status: 'Settled',
                      accentColor: const Color(0xFF627EEA),
                      icon: Icons.subscriptions,
                      onTap: () => _showReceipt(context),
                    ),
                    _buildTransactionItem(
                      name: 'Withdrawal',
                      type: 'Apple pay',
                      amount: '+ € 1000',
                      status: 'Settled',
                      isWithdrawal: true,
                      onTap: () => _showReceipt(context),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Yesterday'),
                    _buildTransactionItem(
                      name: 'Tech Talk Live',
                      type: 'Live Stream',
                      amount: '€ 45.99',
                      status: 'Settled',
                      accentColor: const Color(0xFFF81945),
                      icon: Icons.video_camera_back_rounded,
                      onTap: () => _showReceipt(context),
                    ),
                    _buildTransactionItem(
                      name: 'New Subscriber',
                      type: '@jess__d • Annual Plan',
                      amount: '€ 102.99',
                      status: 'Settled',
                      accentColor: const Color(0xFF627EEA),
                      icon: Icons.subscriptions,
                      onTap: () => _showReceipt(context),
                    ),
                    _buildTransactionItem(
                      name: 'Withdrawal',
                      type: 'Cryptocurrency',
                      amount: '+ € 1000',
                      status: 'Pending',
                      isCrypto: true,
                      isWithdrawal: true,
                      onTap: () => _showReceipt(context),
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
                  'Transaction History',
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
                      ? const Color(0xFFF81945)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? Colors.transparent : Colors.white10,
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

  Widget _buildFilterAndTotal() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: const Row(
              children: [
                Text(
                  'This month',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white38,
                  size: 18,
                ),
              ],
            ),
          ),
          RichText(
            text: const TextSpan(
              style: TextStyle(color: Colors.white60, fontSize: 14),
              children: [
                TextSpan(text: 'Total : '),
                TextSpan(
                  text: '-€ 245.50',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTransactionItem({
    required String name,
    required String type,
    required String amount,
    required String status,
    String? image,
    IconData? icon,
    Color? accentColor,
    bool isWithdrawal = false,
    bool isCrypto = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            if (image != null)
              CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(image),
                backgroundColor: Colors.white10,
              )
            else
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isWithdrawal
                      ? Colors.black
                      : (accentColor?.withValues(alpha: 0.1) ?? Colors.white10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon ?? (isCrypto ? Icons.currency_bitcoin : Icons.apple),
                  color:
                      accentColor ??
                      (isCrypto ? const Color(0xFF627EEA) : Colors.white),
                  size: 24,
                ),
              ),
            const SizedBox(width: 16),
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
                  const SizedBox(height: 4),
                  Text(
                    type,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: TextStyle(
                    color: isWithdrawal
                        ? const Color(0xFF4ADE80)
                        : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: TextStyle(
                    color: status == 'Pending'
                        ? const Color(0xFFFACC15)
                        : Colors.white.withValues(alpha: 0.3),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReceipt(BuildContext context) {
    showDialog(context: context, builder: (context) => const ReceiptDialog());
  }
}

class ReceiptDialog extends StatelessWidget {
  const ReceiptDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 32,
                    backgroundImage: NetworkImage(
                      'https://i.pravatar.cc/150?u=dana',
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dana Kim',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Subscription',
                          style: TextStyle(color: Colors.white54, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      const Icon(
                        Icons.report_gmailerrorred_rounded,
                        color: Color(0xFFF81945),
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Report',
                        style: TextStyle(
                          color: const Color(0xFFF81945).withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Colors.white10, height: 1),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildDetailRow('Duration', '20 Mar- 20 June,2026'),
                  const SizedBox(height: 20),
                  _buildDetailRow('Rate', '€ 7.99'),
                  const SizedBox(height: 20),
                  _buildDetailRow('Payment Status', 'Settled'),
                  const SizedBox(height: 20),
                  _buildDetailRow('Date', '15 March, 2026'),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    '€ 7.99',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
