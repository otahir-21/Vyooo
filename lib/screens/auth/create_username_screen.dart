import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/app_user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../services/firestore_username_service.dart';
import '../../services/username_service.dart';
import '../../services/username_validation.dart';

enum _OnboardingAccountType { private, public, business, government }

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
  StreamSubscription<UsernameCheckResult>? _availabilitySub;
  bool _isChecking = false;
  bool _isSubmitting = false;
  bool? _available;
  List<String> _suggestions = [];
  /// After Firestore save, [AuthWrapper] + user stream advance onboarding; do not push routes here.
  bool _awaitingGateHandoff = false;
  Timer? _gateHandoffTimeout;
  UsernameService get _usernameService =>
      widget.usernameService ?? FirestoreUsernameService();

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _gateHandoffTimeout?.cancel();
    _debounceTimer?.cancel();
    _availabilitySub?.cancel();
    _usernameController.removeListener(_onUsernameChanged);
    _usernameController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    final raw = _usernameController.text;
    final normalized = UsernameValidation.normalize(raw);
    final withoutSpaces = raw.replaceAll(RegExp(r'\s'), '');
    if (withoutSpaces != raw) {
      _usernameController
        ..removeListener(_onUsernameChanged)
        ..text = withoutSpaces
        ..selection = TextSelection.collapsed(offset: withoutSpaces.length)
        ..addListener(_onUsernameChanged);
      return;
    }
    _availabilityFromLength(normalized.length);
    if (UsernameValidation.shouldCheckAvailability(normalized)) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(_debounceDuration, () {
        final latest = UsernameValidation.normalize(_usernameController.text);
        if (!UsernameValidation.shouldCheckAvailability(latest)) return;
        _restartAvailabilityWatch(latest);
      });
    }
  }

  void _availabilityFromLength(int length) {
    if (length < UsernameValidation.minLengthForCheck) {
      _debounceTimer?.cancel();
      _availabilitySub?.cancel();
      _availabilitySub = null;
      setState(() {
        _available = null;
        _suggestions = [];
        _isChecking = false;
      });
    }
  }

  void _restartAvailabilityWatch(String normalized) {
    _availabilitySub?.cancel();
    _availabilitySub = null;
    if (!UsernameValidation.shouldCheckAvailability(normalized)) {
      return;
    }
    final uid = AuthService().currentUser?.uid ?? '';
    setState(() {
      _isChecking = true;
      _available = null;
      _suggestions = [];
    });
    _availabilitySub = _usernameService
        .watchAvailability(normalized, excludeUid: uid)
        .listen(
          (result) {
            if (!mounted) return;
            final current = UsernameValidation.normalize(
              _usernameController.text,
            );
            if (current != normalized) return;
            setState(() {
              _isChecking = false;
              _available = result.available;
              _suggestions = result.suggestions;
            });
          },
          onError: (_) {
            if (!mounted) return;
            final current = UsernameValidation.normalize(
              _usernameController.text,
            );
            if (current != normalized) return;
            setState(() {
              _isChecking = false;
              _available = null;
              _suggestions = [];
            });
          },
        );
  }

  void _applySuggestion(String suggestion) {
    _usernameController
      ..removeListener(_onUsernameChanged)
      ..text = suggestion
      ..selection = TextSelection.collapsed(offset: suggestion.length)
      ..addListener(_onUsernameChanged);
    _restartAvailabilityWatch(UsernameValidation.normalize(suggestion));
  }

  /// Valid format, finished checking, and available (realtime Firestore).
  bool get _isUsernameValid {
    final text = _usernameController.text.trim();
    if (!UsernameValidation.isValidFormat(text)) return false;
    if (_isChecking || _isSubmitting || _awaitingGateHandoff) return false;
    return _available == true;
  }

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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: _onBack,
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                        tooltip: 'Back',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                    ),
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
          Positioned(right: 24, bottom: 36, child: _buildNextButton()),
          if (_awaitingGateHandoff) _buildGateHandoffOverlay(),
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
        height: 100,
        child: Image.asset(
          'assets/BrandLogo/vyooo_white_transparent.png',
          fit: BoxFit.contain,
          errorBuilder: (_, error, stackTrace) => const Text(
            'VyooO',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 42,
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
                      color: AppColors.brandPink,
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
              color: AppColors.brandPink,
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
        if (_available == false &&
            UsernameValidation.shouldCheckAvailability(
              UsernameValidation.normalize(_usernameController.text),
            )) ...[
          const SizedBox(height: 8),
          Text(
            'This username is not available (someone else may have just taken it)',
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
        color: AppColors.brandPurple.withValues(alpha: 0.25),
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
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_.]')),
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
    if (_isSubmitting || _awaitingGateHandoff) return;
    final username = UsernameValidation.normalize(_usernameController.text.trim());
    if (!UsernameValidation.isValidFormat(username)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter at least 3 characters (letters, numbers, underscore, dot).'),
        ),
      );
      return;
    }
    if (_isChecking) return;

    // Final one-shot check on tap so users can proceed even if realtime stream
    // hasn't emitted yet (common right after typing).
    if (_available != true) {
      try {
        final check = await _usernameService.checkAvailability(username);
        if (!mounted) return;
        setState(() {
          _available = check.available;
          _suggestions = check.suggestions;
        });
        if (!check.available) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Username is not available.')),
          );
          return;
        }
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not verify username right now. Try again.'),
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final uid = AuthService().currentUser?.uid;
      final selectedType = await _showAccountTypeDialog();
      if (selectedType == null) {
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }

      if (uid == null || uid.isEmpty) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please sign in again.')),
        );
        return;
      }

      String? publicPersonaUpdate;
      if (selectedType == _OnboardingAccountType.public) {
        final persona = await _promptPublicPersona();
        if (!mounted) return;
        if (persona == null) {
          setState(() => _isSubmitting = false);
          return;
        }
        publicPersonaUpdate = persona;
      }

      // Write username + accountType alone first. If `publicPersona` is merged in the same
      // request and production Firestore rules are older (no `publicPersona` in
      // validUserDoc.keys().hasOnly), the **entire** update is rejected — username never
      // saves and the user loops here. Persona is persisted in a follow-up write.
      await UserService().updateUserProfile(
        uid: uid,
        username: username,
        accountType: selectedType.name,
      );

      // Server read: confirm `username` is visible before relying on userStream to advance
      // [AuthWrapper] (avoids a cache race that kept users on this screen).
      final userSvc = UserService();
      AppUserModel? verified;
      for (var i = 0; i < 3; i++) {
        verified = await userSvc.getUser(uid, server: true);
        final u = UsernameValidation.normalize((verified?.username ?? '').trim());
        if (verified != null && u.isNotEmpty) break;
        if (i < 2) {
          await Future<void>.delayed(Duration(milliseconds: 250 * (i + 1)));
        }
        if (!mounted) return;
      }

      if (!mounted) return;

      final serverUsername = UsernameValidation.normalize(
        (verified?.username ?? '').trim(),
      );
      if (serverUsername.isEmpty || serverUsername != username) {
        setState(() {
          _isSubmitting = false;
          _awaitingGateHandoff = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your profile did not update on the server. Check your connection and tap Continue again.',
            ),
          ),
        );
        return;
      }

      if (publicPersonaUpdate != null && publicPersonaUpdate.isNotEmpty) {
        try {
          await userSvc.updateUserProfile(
            uid: uid,
            publicPersona: publicPersonaUpdate,
          );
        } catch (e, st) {
          assert(() {
            debugPrint(
              'Onboarding: publicPersona write failed (deploy firestore.rules with publicPersona): $e\n$st',
            );
            return true;
          }());
        }
      }

      _gateHandoffTimeout?.cancel();
      _gateHandoffTimeout = Timer(const Duration(seconds: 12), () {
        if (!mounted) return;
        if (!_awaitingGateHandoff) return;
        setState(() => _awaitingGateHandoff = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open the next step. Check your connection and tap Continue again.',
            ),
          ),
        );
      });
      setState(() {
        _isSubmitting = false;
        _awaitingGateHandoff = true;
      });
      // Single source of truth: [AuthWrapper] rebuilds from Firestore userStream
      // and shows SelectDobScreen / OrganizationDetailsScreen via OnboardingGate.
      // Imperative Navigator.push raced that stream and could leave users stuck here.
    } catch (_) {
      if (!mounted) return;
      _gateHandoffTimeout?.cancel();
      setState(() {
        _isSubmitting = false;
        _awaitingGateHandoff = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save username/account type. Please try again.'),
        ),
      );
    }
  }

  Widget _buildGateHandoffOverlay() {
    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.45),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
                SizedBox(height: 20),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Saving your profile…',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<_OnboardingAccountType?> _showAccountTypeDialog() async {
    final platform = Theme.of(context).platform;
    final isCupertino =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    if (isCupertino) {
      return _showCupertinoAccountTypeDialog();
    }

    return _showMaterialAccountTypeDialog();
  }

  Future<_OnboardingAccountType?> _showCupertinoAccountTypeDialog() {
    return showCupertinoModalPopup<_OnboardingAccountType>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Select account type'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(_OnboardingAccountType.private),
            child: const Text('Private account'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(_OnboardingAccountType.public),
            child: const Text('Public account'),
          ),
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.of(ctx).pop(_OnboardingAccountType.business),
            child: const Text('Business account'),
          ),
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.of(ctx).pop(_OnboardingAccountType.government),
            child: const Text('Government account'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<_OnboardingAccountType?> _showMaterialAccountTypeDialog() {
    return showDialog<_OnboardingAccountType>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select account type'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(_OnboardingAccountType.private),
            child: const Text('Private account'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(_OnboardingAccountType.public),
            child: const Text('Public account'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(_OnboardingAccountType.business),
            child: const Text('Business account'),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(ctx).pop(_OnboardingAccountType.government),
            child: const Text('Government account'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// After choosing a public account, collect how they describe their profile.
  Future<String?> _promptPublicPersona() {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _PublicPersonaDialog(),
    );
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
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
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

  Future<void> _onBack() async {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    await AuthService().signOut();
  }
}

/// Owns [TextEditingController] for the persona field so it is disposed only after
/// the route removes the dialog (avoids "used after being disposed" on pop/hot restart).
class _PublicPersonaDialog extends StatefulWidget {
  const _PublicPersonaDialog();

  @override
  State<_PublicPersonaDialog> createState() => _PublicPersonaDialogState();
}

class _PublicPersonaDialogState extends State<_PublicPersonaDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Describe your public profile'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            maxLength: UserService.publicPersonaMaxLength,
            decoration: const InputDecoration(
              hintText: 'e.g. Entrepreneur, Content creator, Celebrity',
              border: OutlineInputBorder(),
            ),
            validator: (raw) {
              final normalized = UserService.normalizePublicPersona(raw ?? '');
              if (normalized.length < 2) {
                return 'Enter at least 2 characters.';
              }
              return null;
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            final out = UserService.normalizePublicPersona(_controller.text);
            Navigator.of(context).pop(out);
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
