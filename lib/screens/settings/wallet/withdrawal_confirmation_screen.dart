import 'package:flutter/material.dart';
import '../../../core/theme/app_gradients.dart';

class WithdrawalConfirmationScreen extends StatelessWidget {
  const WithdrawalConfirmationScreen({super.key, this.isCrypto = false});

  final bool isCrypto;

  @override
  Widget build(BuildContext context) {
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  children: [
                    _buildReceiveDisplay(),
                    const SizedBox(height: 32),
                    _buildBreakdown(),
                    const SizedBox(height: 40),
                    if (isCrypto)
                      _buildCryptoDetails()
                    else
                      _buildBankDetails(),
                    const SizedBox(height: 48),
                    _buildWithdrawButton(context),
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
                  'Withdraw Funds',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiveDisplay() {
    return Column(
      children: [
        const Text(
          'You will recieve',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            '€ 493.50',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdown() {
    return Column(
      children: [
        _buildSummaryRow('Withdrawal Amount', '\$500'),
        const SizedBox(height: 16),
        _buildSummaryRow(
          'Network Fee (1.5%)',
          '-\$7.50',
          showInfo: true,
          valueColor: const Color(0xFFF81945),
        ),
        const SizedBox(height: 24),
        const Divider(color: Colors.white10),
        const SizedBox(height: 24),
        _buildSummaryRow('Net Amount', '€ 493.50', isHeader: true),
      ],
    );
  }

  Widget _buildBankDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Bank Details'),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.account_balance_rounded,
                color: Colors.blue,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deutsche Bank',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Savings  •  . . . . 4821',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildFieldDisplay(
          'IBAN',
          'DE89 3704 0044 0532 0130 00',
          showCopy: true,
        ),
        const SizedBox(height: 24),
        _buildFieldDisplay('BIC/ SWIFT', 'DEUTDEDB'),
        const SizedBox(height: 24),
        _buildFieldDisplay('Account Holder', 'Alex Morgan'),
        const SizedBox(height: 32),
        const Divider(color: Colors.white10),
        const SizedBox(height: 32),
        _buildFieldDisplay('Transfer Type', 'SEPA Transfer'),
        const SizedBox(height: 24),
        _buildFieldDisplay('Reference', 'WD-20260407-3821', showCopy: true),
        const SizedBox(height: 24),
        _buildFieldDisplay('Estimated Arrival', '1-3 Business Days'),
      ],
    );
  }

  Widget _buildCryptoDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Payout Method'),
        const SizedBox(height: 8),
        const Text(
          'Ethereum (ERC20)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
        _buildFieldDisplay(
          'Destination Address',
          '0x71c4a8f3. . . e9b2976F',
          showCopy: true,
        ),
        const SizedBox(height: 24),
        _buildFieldDisplay('Estimated Arrival', '~ 5 to 10 minutes'),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_rounded, color: Colors.yellow, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Irreversible transaction',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Crypto transactions cannot be reversed. Please double-check the destination address network. Sending to the wrong network will result in permanent loss of funds.',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.3),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildFieldDisplay(
    String label,
    String value, {
    bool showCopy = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(label),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: isCrypto && label == 'Destination Address'
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'monospace',
                        ),
                      ),
                    )
                  : label == 'Reference' || label == 'IBAN'
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
            if (showCopy) ...[
              const SizedBox(width: 8),
              const Icon(Icons.copy_rounded, color: Colors.white38, size: 18),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isHeader = false,
    bool showInfo = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isHeader ? Colors.white : Colors.white54,
                fontSize: isHeader ? 18 : 15,
                fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (showInfo) ...[
              const SizedBox(width: 8),
              const Icon(Icons.info_outline, color: Colors.white24, size: 14),
            ],
          ],
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: isHeader ? 18 : 15,
            fontWeight: isHeader ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildWithdrawButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Final withdrawal logic
        Navigator.popUntil(context, (route) => route.isFirst);
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_rounded, color: Colors.black, size: 20),
            SizedBox(width: 12),
            Text(
              'Withdraw Funds',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
