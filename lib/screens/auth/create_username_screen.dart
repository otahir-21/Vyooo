import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../services/mock_username_service.dart';
import '../../services/username_service.dart';
import '../../services/username_validation.dart';
import '../onboarding/select_dob_screen.dart';

class CreateUsernameScreen extends StatefulWidget {
  const CreateUsernameScreen({super.key, this.usernameService});

  final UsernameService? usernameService;

  @override
  State<CreateUsernameScreen> createState() => _CreateUsernameScreenState();
}

class _CreateUsernameScreenState extends State<CreateUsernameScreen> {
  static const double _horizontalPadding = 28;
  static const double _progressFill = 0.25;
  static const Duration _debounceDuration = Duration(milliseconds: 500);
  static const Duration _borderAnimationDuration = Duration(milliseconds: 200);

  late final TextEditingController _usernameController;
  Timer? _debounceTimer;
  bool _isChecking = false;
  bool? _available;
  List<String> _suggestions = [];
  UsernameService get _usernameService =>
      widget.usernameService ?? MockUsernameService();

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _usernameController.removeListener(_onUsernameChanged);
    _usernameController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    final raw = _usernameController.text;
    final normalized = UsernameValidation.normalize(raw);
    if (normalized != raw) {
      _usernameController
        ..removeListener(_onUsernameChanged)
        ..text = normalized
        ..selection = TextSelection.collapsed(offset: normalized.length)
        ..addListener(_onUsernameChanged);
      return;
    }
    _availabilityFromLength(normalized.length);
    if (UsernameValidation.shouldCheckAvailability(normalized)) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(
        _debounceDuration,
        () => _checkAvailability(normalized),
      );
    }
  }

  void _availabilityFromLength(int length) {
    if (length < UsernameValidation.minLengthForCheck) {
      setState(() {
        _available = null;
        _suggestions = [];
      });
    }
  }

  Future<void> _checkAvailability(String username) async {
    setState(() {
      _isChecking = true;
      _available = null;
      _suggestions = [];
    });
    try {
      final result = await _usernameService.checkAvailability(username);
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _available = result.available;
        _suggestions = result.suggestions;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _available = null;
        _suggestions = [];
      });
    }
  }

  void _applySuggestion(String suggestion) {
    _usernameController
      ..removeListener(_onUsernameChanged)
      ..text = suggestion
      ..selection = TextSelection.collapsed(offset: suggestion.length)
      ..addListener(_onUsernameChanged);
    _checkAvailability(suggestion);
  }

  /// Allow Next when username has valid format (3+ chars, letters/numbers/underscore).
  /// Availability check is for UI feedback only; don't block navigation.
  bool get _isUsernameValid =>
      UsernameValidation.isValidFormat(_usernameController.text.trim());

  // Future<void> _logout(BuildContext context) async {
  //   await AuthService().signOut();
  //   if (!context.mounted) return;
  //   Navigator.of(context).pushAndRemoveUntil(
  //     MaterialPageRoute(builder: (_) => const AuthWrapper()),
  //     (route) => false,
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          AppGradientBackground(
            type: GradientType.onboarding,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _horizontalPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    _buildLogo(),
                    const SizedBox(height: 16),
                    _buildProgressBar(),
                    const SizedBox(height: 40),
                    _buildAvatar(),
                    const SizedBox(height: 30),
                    const Text(
                      "Let's get you started",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.defaultTextColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: _buildUsernameSection(),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
          Positioned(right: 24, bottom: 24, child: _buildNextButton()),
          // Temporary logout
          // Positioned(
          //   top: 16,
          //   right: 16,
          //   child: TextButton.icon(
          //     onPressed: () => _logout(context),
          //     icon: const Icon(Icons.logout, color: Colors.white70, size: 20),
          //     label: const Text(
          //       'Logout',
          //       style: TextStyle(color: Colors.white70, fontSize: 14),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: SizedBox(
        height: 45,
        child: Image.asset(
          'assets/BrandLogo/Vyooo logo (2).png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Text(
            'VyooO',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 38,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth = constraints.maxWidth;
        final fillWidth = fullWidth * _progressFill;
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 3,
            width: double.infinity,
            child: Stack(
              children: [
                Container(width: fullWidth, height: 3, color: White24.value),
                SizedBox(
                  width: fillWidth,
                  child: Container(
                    height: 3,
                    decoration: const BoxDecoration(
                      color: AppColors.pink,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(10),
                        right: Radius.zero,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar() {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .05),
              border: Border.all(color: White10.value, width: 1),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.person_outline,
              size: 72,
              color: AppColors.pink,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: Icon(
              Icons.auto_awesome,
              size: 24,
              color: AppColors.lightGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsernameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Username',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.secondaryTextColor,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        _buildUsernameInput(),
        if (_available == false && _usernameController.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'The Username ${_usernameController.text} is not available',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.red,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_suggestions.isNotEmpty) _buildSuggestions(),
      ],
    );
  }

  Widget _buildUsernameInput() {
    final hasError = _available == false;
    final hasSuccess = _available == true;
    final borderColor = hasError
        ? Colors.red
        : hasSuccess
        ? Colors.green
        : Colors.transparent;
    final borderWidth = (hasError || hasSuccess) ? 1.5 : 0.0;

    return AnimatedContainer(
      duration: _borderAnimationDuration,
      curve: Curves.easeInOut,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.darkPurple.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: borderWidth > 0
            ? Border.all(color: borderColor, width: borderWidth)
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _usernameController,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.defaultTextColor,
                fontWeight: FontWeight.w400,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                TextInputFormatter.withFunction(
                  (_, value) => TextEditingValue(
                    text: value.text.toLowerCase(),
                    selection: value.selection,
                  ),
                ),
              ],
            ),
          ),
          if (_isChecking)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            )
          else if (hasError)
            const Icon(Icons.close, color: Colors.grey, size: 22)
          else if (hasSuccess)
            const Icon(Icons.check, color: Colors.green, size: 22),
        ],
      ),
    );
  }

  Widget _buildNextButton() {
    return Material(
      elevation: 2,
      shape: const CircleBorder(),
      color: AppTheme.buttonBackground,
      child: InkWell(
        onTap: _isUsernameValid ? _onNext : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          child: Icon(
            Icons.arrow_forward,
            color: _isUsernameValid ? AppTheme.buttonTextColor : Colors.grey,
            size: 28,
          ),
        ),
      ),
    );
  }

  Future<void> _onNext() async {
    if (!_isUsernameValid) return;
    final uid = AuthService().currentUser?.uid;
    final username = _usernameController.text.trim();
    if (uid != null && uid.isNotEmpty) {
      try {
        await UserService().updateUserProfile(uid: uid, username: username);
      } catch (_) {
        // Still navigate so onboarding isn't blocked by network/backend errors
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const SelectDobScreen()),
        );
        return;
      }
    }
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SelectDobScreen()));
  }

  Widget _buildSuggestions() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        children: List.generate(_suggestions.length, (index) {
          final suggestion = _suggestions[index];

          return Column(
            children: [
              if (index != 0)
                Divider(height: 1, color: Colors.white.withOpacity(0.1)),
              InkWell(
                onTap: () => _applySuggestion(suggestion),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          suggestion,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.green, width: 2),
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 18,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
