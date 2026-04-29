import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/app_gradients.dart';
import 'withdrawal_confirmation_screen.dart';

class WithdrawFundsScreen extends StatefulWidget {
  const WithdrawFundsScreen({super.key});

  @override
  State<WithdrawFundsScreen> createState() => _WithdrawFundsScreenState();
}

class _WithdrawFundsScreenState extends State<WithdrawFundsScreen> {
  int _selectedTierIndex = 0; // 0 for Bank, 1 for Crypto
  final TextEditingController _amountController = TextEditingController(
    text: "500",
  );
  bool _saveCardInfo = false;

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
                    horizontal: 20,
                    vertical: 16,
                  ),
                  children: [
                    _buildAvailableBalance(),
                    const SizedBox(height: 24),
                    _buildToggle(),
                    const SizedBox(height: 24),
                    if (_selectedTierIndex == 0)
                      _buildBankTransferForm()
                    else
                      _buildCryptoTransferForm(),
                    const SizedBox(height: 32),
                    _buildReviewButton(),
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

  Widget _buildAvailableBalance() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available to Withdraw',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              '€ 460325',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildToggleItem('Bank Transfer', 0)),
          Expanded(child: _buildToggleItem('CryptoCurrency', 1)),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String label, int index) {
    bool selected = _selectedTierIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTierIndex = index),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white60,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBankTransferForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'By selecting Bank Transfer, you agree that funds will be credited to your account within 1–3 business days. A processing fee of 1.5% applies.',
          style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 32),
        _buildAmountInput(),
        const SizedBox(height: 32),
        _buildFormFieldLabel('Cardholder Name'),
        const SizedBox(height: 8),
        _buildTextField(
          hint: 'Mike Jordan',
          suffixIcon: FontAwesomeIcons.ccMastercard,
        ),
        const SizedBox(height: 20),
        _buildFormFieldLabel('Routing Number'),
        const SizedBox(height: 8),
        _buildTextField(hint: '0000  0000  0000  0000'),
        const SizedBox(height: 20),
        _buildFormFieldLabel('Card Number'),
        const SizedBox(height: 8),
        _buildTextField(hint: '4312  0245  5488  0345'),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormFieldLabel('CVV'),
                  const SizedBox(height: 8),
                  _buildTextField(hint: '255'),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormFieldLabel('Expires'),
                  const SizedBox(height: 8),
                  _buildTextField(hint: '03/2022'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSaveCheckbox(),
      ],
    );
  }

  Widget _buildCryptoTransferForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAmountInput(),
        const SizedBox(height: 32),
        _buildFormFieldLabel('Select Network'),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildNetworkChip('Ethereum', 'ERC-20', const Color(0xFF627EEA)),
              const SizedBox(width: 12),
              _buildNetworkChip('Polygon', 'MATIC', const Color(0xFF8247E5)),
              const SizedBox(width: 12),
              _buildNetworkChip('Solana', 'SOL', const Color(0xFF14F195)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildFormFieldLabel('Wallet Address'),
        const SizedBox(height: 8),
        _buildTextField(hint: 'Ox. . .', suffixIcon: Icons.copy_rounded),
        const SizedBox(height: 24),
        _buildFormFieldLabel('Memo/ Destination Tag (Optional)'),
        const SizedBox(height: 8),
        _buildTextField(hint: 'Required for some exchanges', maxLines: 3),
        const SizedBox(height: 24),
        _buildImportantNotice(),
      ],
    );
  }

  Widget _buildAmountInput() {
    return Column(
      children: [
        const Center(
          child: Text(
            'Enter Amount',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '€',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 16),
            IntrinsicWidth(
              child: TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '0',
                  hintStyle: TextStyle(color: Colors.white24),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(
          width: 180,
          child: Divider(color: Colors.white24, thickness: 1),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['€ 100', '€ 500', '€ 1K', 'Max'].map((amount) {
            bool selected = amount == '€ 500';
            return GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFF81945)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  amount,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNetworkChip(String name, String code, Color color) {
    bool selected = name == 'Ethereum';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFFF81945) : Colors.white10,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              name[0],
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            code,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildImportantNotice() {
    return Container(
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
                  'Important',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Please ensure you select the correct network and enter a valid address. Withdrawals sent to the wrong address or network cannot be recovered.',
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
    );
  }

  Widget _buildFormFieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    Object? suffixIcon,
    int maxLines = 1,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24),
          suffixIcon: suffixIcon == null
              ? null
              : suffixIcon is FaIconData
                  ? FaIcon(
                      suffixIcon,
                      color: suffixIcon == FontAwesomeIcons.ccMastercard
                          ? Colors.orange
                          : Colors.white38,
                      size: 20,
                    )
                  : Icon(
                      suffixIcon as IconData,
                      color: Colors.white38,
                      size: 20,
                    ),
        ),
      ),
    );
  }

  Widget _buildSaveCheckbox() {
    return GestureDetector(
      onTap: () => setState(() => _saveCardInfo = !_saveCardInfo),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _saveCardInfo ? const Color(0xFFF81945) : Colors.white10,
              borderRadius: BorderRadius.circular(6),
            ),
            child: _saveCardInfo
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : null,
          ),
          const SizedBox(width: 12),
          const Text(
            'Save card information',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                WithdrawalConfirmationScreen(isCrypto: _selectedTierIndex == 1),
          ),
        );
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
            Text(
              'Review Withdrawal',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: 12),
            Icon(Icons.arrow_forward_rounded, color: Colors.black),
          ],
        ),
      ),
    );
  }
}
