import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/app_user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_field_style.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/auth/auth_widgets.dart';
import '../../core/widgets/onboarding_progress_bar.dart';
import '../../core/widgets/vyooo_brand_logo.dart';
import '../../services/firestore_username_service.dart';
import '../../services/temporary_username_generator.dart';
import '../../services/username_service.dart';
import '../../services/username_validation.dart';

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
  late final FocusNode _usernameFocusNode;
  Timer? _debounceTimer;
  StreamSubscription<UsernameCheckResult>? _availabilitySub;
  bool _isChecking = false;
  bool _isSubmitting = false;
  bool? _available;
  bool _isReserved = false;
  bool _reservedContinueConfirmed = false;
  String? _lastReservedDialogFor;
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
    _usernameFocusNode = FocusNode()..addListener(_onUsernameFocusChanged);
    _usernameController.addListener(_onUsernameChanged);
  }

  void _onUsernameFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _gateHandoffTimeout?.cancel();
    _debounceTimer?.cancel();
    _availabilitySub?.cancel();
    _usernameController.removeListener(_onUsernameChanged);
    _usernameFocusNode.removeListener(_onUsernameFocusChanged);
    _usernameController.dispose();
    _usernameFocusNode.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    if (mounted) setState(() {});
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
        _isReserved = false;
        _reservedContinueConfirmed = false;
        _lastReservedDialogFor = null;
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
      _isReserved = false;
      _reservedContinueConfirmed = false;
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
              _isReserved = result.isReserved;
              _available = result.available;
              _suggestions = result.isReserved ? const [] : result.suggestions;
              if (!result.isReserved) {
                _reservedContinueConfirmed = false;
              }
            });
            if (result.isReserved) {
              _maybeShowReservedDialog(normalized);
            }
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
              _isReserved = false;
              _reservedContinueConfirmed = false;
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

  Future<void> _maybeShowReservedDialog(String normalized) async {
    if (_lastReservedDialogFor == normalized) return;
    _lastReservedDialogFor = normalized;
    if (!mounted) return;
    final proceed = await AuthReservedUsernameDialog.show(
      context,
      requestedUsername: normalized,
    );
    if (!mounted) return;
    final current = UsernameValidation.normalize(_usernameController.text);
    if (current != normalized) return;
    setState(() {
      _reservedContinueConfirmed = proceed == true;
    });
  }

  /// Valid format, finished checking, and available (or reserved + acknowledged).
  bool get _isUsernameValid {
    final text = _usernameController.text.trim();
    if (!UsernameValidation.isValidFormat(text)) return false;
    if (_isChecking || _isSubmitting || _awaitingGateHandoff) return false;
    if (_isReserved) return _reservedContinueConfirmed;
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
    return AuthLightScaffold(
      padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
      stackChildren: [
        AuthFloatingNavRow(
          onBack: _onBack,
          onForward: _onNext,
          forwardEnabled: _isUsernameValid,
        ),
        if (_awaitingGateHandoff) _buildGateHandoffOverlay(),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          const VyoooBrandLogo.auth(),
          const SizedBox(height: 16),
          const OnboardingProgressBar(progress: _progressFill),
          const SizedBox(height: 40),
          _buildAvatar(),
          const SizedBox(height: 30),
          Text(
            "Let's get you started",
            style: AppTypography.onboardingSectionTitle.copyWith(
              color: AppTheme.lightOnSurface,
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
    );
  }

  Widget _buildAvatar() {
    return Center(
      child: Image.asset(
        'assets/vyooO_icons/Onboarding/username_profile_avatar.png',
        width: 150,
        height: 150,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildUsernameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUsernameInput(),
        if (_isReserved &&
            UsernameValidation.shouldCheckAvailability(
              UsernameValidation.normalize(_usernameController.text),
            )) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${UsernameValidation.normalize(_usernameController.text)} is reserved. Reach out to claim it — we will assign a temporary username for now.',
            style: AppTypography.usernameAvailabilityError,
          ),
          const SizedBox(height: AppSpacing.md),
        ] else if (_available == false &&
            UsernameValidation.shouldCheckAvailability(
              UsernameValidation.normalize(_usernameController.text),
            )) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'The Username ${UsernameValidation.normalize(_usernameController.text)} is not available',
            style: AppTypography.usernameAvailabilityError,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (_suggestions.isNotEmpty) _buildSuggestions(),
      ],
    );
  }

  bool get _usernameShowsAvailabilityError =>
      !_isReserved &&
      _available == false &&
      UsernameValidation.shouldCheckAvailability(
        UsernameValidation.normalize(_usernameController.text),
      );

  ({Color color, double width}) _usernameFieldBorder() {
    if (_usernameShowsAvailabilityError) {
      return (color: AppColors.brandPink, width: 1.5);
    }
    if (_available == true) {
      return (color: Colors.green, width: 1.5);
    }
    if (_usernameFocusNode.hasFocus) {
      return (color: AppTheme.lightOnSurface, width: 1.5);
    }
    return (color: AppTheme.lightUnfocusedUnderline, width: 1);
  }

  Widget _buildUsernameInput() {
    final hasError = _usernameShowsAvailabilityError;
    final hasSuccess = _available == true;
    final isFocused = _usernameFocusNode.hasFocus;
    final hasText = _usernameController.text.isNotEmpty;
    final showInsetLabel = isFocused || hasText;
    final border = _usernameFieldBorder();

    return GestureDetector(
      onTap: () => _usernameFocusNode.requestFocus(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: _borderAnimationDuration,
        curve: Curves.easeInOut,
        height: 60,
        decoration: BoxDecoration(
          color: AppTheme.lightScaffoldBackground,
          borderRadius: AppRadius.pillRadius,
          border: Border.all(color: border.color, width: border.width),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSize(
                    duration: _borderAnimationDuration,
                    curve: Curves.easeInOut,
                    alignment: Alignment.topLeft,
                    child: showInsetLabel
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              'Username',
                              style: AppTypography.usernameFieldLabel.copyWith(
                                color: AppTheme.lightSecondaryText,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  TextField(
                    controller: _usernameController,
                    focusNode: _usernameFocusNode,
                    keyboardAppearance:
                        AppTextFieldStyle.keyboardAppearance(context),
                    cursorColor: AppTextFieldStyle.cursorColor(context),
                    style: AppTypography.usernameFieldValue.copyWith(
                      color: AppTheme.lightOnSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: showInsetLabel ? null : 'Username',
                      hintStyle: AppTypography.usernameFieldLabel.copyWith(
                        color: AppTheme.lightSecondaryText,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                      isCollapsed: showInsetLabel,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z0-9_.]'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (_isChecking)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.authBrandBurgundy,
                ),
              ),
            )
          else if (hasError)
            GestureDetector(
              onTap: () {
                _usernameController.clear();
                _availabilityFromLength(0);
              },
              child: Icon(
                Icons.close,
                color: AppTheme.secondaryTextColor.withValues(alpha: 0.8),
                size: AppSizes.fieldIcon,
              ),
            )
          else if (hasSuccess)
            const Icon(
              Icons.check,
              color: Colors.green,
              size: AppSizes.fieldIcon,
            ),
          ],
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
          content: Text('Enter at least 4 characters (letters, numbers, underscore, dot).'),
        ),
      );
      return;
    }
    if (_isChecking) return;

    var usernameToSave = username;
    if (_isReserved) {
      if (!_reservedContinueConfirmed) {
        await _maybeShowReservedDialog(username);
        if (!mounted || !_reservedContinueConfirmed) return;
      }
      final uid = AuthService().currentUser?.uid ?? '';
      if (uid.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please sign in again.')),
        );
        return;
      }
      usernameToSave = await TemporaryUsernameGenerator.generate(
        uid: uid,
        usernameService: _usernameService,
      );
    }

    // Final one-shot check on tap so users can proceed even if realtime stream
    // hasn't emitted yet (common right after typing).
    if (!_isReserved && _available != true) {
      try {
        final check = await _usernameService.checkAvailability(username);
        if (!mounted) return;
        setState(() {
          _available = check.available;
          _suggestions = check.suggestions;
        });
        if (!check.available) {
          if (check.isReserved) {
            setState(() => _isReserved = true);
            await _maybeShowReservedDialog(username);
            if (!mounted || !_reservedContinueConfirmed) return;
            final uid = AuthService().currentUser?.uid ?? '';
            if (uid.isEmpty) return;
            usernameToSave = await TemporaryUsernameGenerator.generate(
              uid: uid,
              usernameService: _usernameService,
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Username is not available.')),
            );
            return;
          }
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
      if (selectedType == AuthOnboardingAccountType.public) {
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
        username: usernameToSave,
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
      if (serverUsername.isEmpty || serverUsername != usernameToSave) {
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
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.authBrandBurgundy,
                  ),
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

  Future<AuthOnboardingAccountType?> _showAccountTypeDialog() {
    return AuthAccountTypePickerDialog.show(context);
  }

  /// After choosing a public account, collect how they describe their profile.
  Future<String?> _promptPublicPersona() {
    return AuthPublicPersonaDialog.show(context);
  }

  Widget _buildSuggestions() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: AppTheme.lightOtpBoxFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.lightUnfocusedUnderline,
        ),
      ),
      child: Column(
        children: List.generate(_suggestions.length, (index) {
          final suggestion = _suggestions[index];

          return Column(
            children: [
              if (index != 0)
                Divider(
                  height: 1,
                  color: AppTheme.lightUnfocusedUnderline,
                ),
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
                          style: AppTypography.usernameSuggestion.copyWith(
                            color: AppTheme.lightOnSurface,
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

