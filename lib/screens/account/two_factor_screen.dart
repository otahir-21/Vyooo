import 'package:flutter/material.dart';

import '../auth/verify_code_screen.dart';
import '../../core/widgets/app_gradient_background.dart';

class _CountryDial {
  const _CountryDial({
    required this.flagEmoji,
    required this.dialCode,
    required this.name,
  });

  final String flagEmoji;
  final String dialCode;
  final String name;
}

/// Curated list for phone OTP UI (expand anytime).
const List<_CountryDial> _kPhoneCountryDials = [
  _CountryDial(flagEmoji: '🇬🇧', dialCode: '+44', name: 'United Kingdom'),
  _CountryDial(flagEmoji: '🇺🇸', dialCode: '+1', name: 'United States'),
  _CountryDial(flagEmoji: '🇦🇪', dialCode: '+971', name: 'United Arab Emirates'),
  _CountryDial(flagEmoji: '🇵🇰', dialCode: '+92', name: 'Pakistan'),
  _CountryDial(flagEmoji: '🇮🇳', dialCode: '+91', name: 'India'),
  _CountryDial(flagEmoji: '🇦🇺', dialCode: '+61', name: 'Australia'),
  _CountryDial(flagEmoji: '🇸🇦', dialCode: '+966', name: 'Saudi Arabia'),
  _CountryDial(flagEmoji: '🇪🇬', dialCode: '+20', name: 'Egypt'),
  _CountryDial(flagEmoji: '🇫🇷', dialCode: '+33', name: 'France'),
  _CountryDial(flagEmoji: '🇩🇪', dialCode: '+49', name: 'Germany'),
  _CountryDial(flagEmoji: '🇨🇦', dialCode: '+1', name: 'Canada'),
  _CountryDial(flagEmoji: '🇳🇬', dialCode: '+234', name: 'Nigeria'),
  _CountryDial(flagEmoji: '🇿🇦', dialCode: '+27', name: 'South Africa'),
  _CountryDial(flagEmoji: '🇧🇷', dialCode: '+55', name: 'Brazil'),
  _CountryDial(flagEmoji: '🇯🇵', dialCode: '+81', name: 'Japan'),
];

class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({super.key, this.forLoginPhoneAuth = false});

  final bool forLoginPhoneAuth;

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  late _CountryDial _selected;
  final _phoneController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selected = _kPhoneCountryDials.first;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _openCountryPicker() async {
    final picked = await showModalBottomSheet<_CountryDial>(
      context: context,
      backgroundColor: const Color(0xFF1A0A24),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.62;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Country / region',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: _kPhoneCountryDials.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    itemBuilder: (context, i) {
                      final c = _kPhoneCountryDials[i];
                      final isSel = c.dialCode == _selected.dialCode &&
                          c.name == _selected.name;
                      return ListTile(
                        leading: Text(c.flagEmoji, style: const TextStyle(fontSize: 26)),
                        title: Text(
                          c.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: Text(
                          c.dialCode,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        selected: isSel,
                        selectedTileColor: Colors.white.withValues(alpha: 0.06),
                        onTap: () => Navigator.pop(ctx, c),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selected = picked);
    }
  }

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
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  children: [
                    const Text(
                      'Help us protect your account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Set up two factor authentication and we'll send you a\nnotification to check if it's you if someone logs in from\nanother device that we don't recognise.",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Add Phone number',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This phone number is required to send you authentication\ncodes to ensure complete protection to your account.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildPhoneInput(),
                    const SizedBox(height: 32),
                    if (_errorMessage != null) ...[
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                    ],
                    ElevatedButton(
                      onPressed: _isLoading ? null : _onSendCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Send Code',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
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
                  'Login & Security',
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

  Widget _buildPhoneInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFDE106B).withValues(alpha: 0.5),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openCountryPicker,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_selected.flagEmoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      _selected.dialCode,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _phoneController,
              onChanged: (_) {
                if (_errorMessage == null) return;
                setState(() => _errorMessage = null);
              },
              style: const TextStyle(color: Colors.white, fontSize: 15),
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Enter phone number',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _normalizedPhone() {
    final raw = _phoneController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.isEmpty) return '';
    final local = raw.startsWith('0') ? raw.substring(1) : raw;
    return '${_selected.dialCode}$local';
  }

  Future<void> _onSendCode() async {
    final phone = _normalizedPhone();
    if (phone.isEmpty || !phone.startsWith('+')) {
      setState(() => _errorMessage = 'Enter a valid phone number.');
      return;
    }
    if (!widget.forLoginPhoneAuth) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const VerifyCodeScreen(),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VerifyCodeScreen(
          channel: 'phone',
          phoneNumber: phone,
          maskedPhone: _maskPhoneForDisplay(phone),
          autoSendOnOpen: true,
          forPhoneLogin: true,
        ),
      ),
    );
  }

  String _maskPhoneForDisplay(String value) {
    final t = value.trim();
    if (t.length <= 4) return t;
    final visible = t.substring(t.length - 4);
    return '${'*' * (t.length - 4)}$visible';
  }
}
