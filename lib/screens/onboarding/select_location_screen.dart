import 'package:flutter/material.dart';

import '../../core/location/places_location_service.dart';
import '../../core/widgets/location/location_map_preview.dart';
import '../../core/models/post_location_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../core/widgets/auth/auth_widgets.dart';
import '../../core/widgets/onboarding_progress_bar.dart';
import '../../core/widgets/vyooo_brand_logo.dart';
import '../upload/location_picker_sheet.dart';

/// Profile location: map preview, editable address, search sheet, GPS.
class SelectLocationScreen extends StatefulWidget {
  const SelectLocationScreen({super.key});

  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  static const double _horizontalPadding = 28;
  static const double _progressFill = 0.75;
  static const double _mapHeight = 168;
  static const int _minAddressLength = 2;

  final _addressController = TextEditingController();

  double? _latitude;
  double? _longitude;
  String? _placeId;
  String _locationSource = 'manual';
  bool _gpsLoading = false;
  bool _saving = false;
  bool _applyingAutofill = false;
  String? _error;

  bool get _hasMapCoordinates => _latitude != null && _longitude != null;

  bool get _canContinue =>
      _addressController.text.trim().length >= _minAddressLength;

  @override
  void initState() {
    super.initState();
    _addressController.addListener(_onAddressEdited);
  }

  void _onAddressEdited() {
    if (_applyingAutofill || !mounted) return;
    setState(() => _locationSource = 'manual');
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  void _applyResolved(ResolvedProfileLocation resolved) {
    _applyingAutofill = true;
    _latitude = resolved.location.latitude;
    _longitude = resolved.location.longitude;
    _placeId = resolved.location.placeId;
    _locationSource = resolved.location.source;
    _addressController.text = resolved.addressLines;
    _applyingAutofill = false;
    _error = null;
  }

  void _applyPostLocation(PostLocation location) {
    _applyingAutofill = true;
    _latitude = location.latitude;
    _longitude = location.longitude;
    _placeId = location.placeId;
    _locationSource = location.source;
    _addressController.text =
        PlacesLocationService.formatAddressLinesFromPostLocation(location);
    _applyingAutofill = false;
    _error = null;
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _gpsLoading = true;
      _error = null;
    });
    try {
      final resolved = await PlacesLocationService.currentLocation();
      if (!mounted) return;
      setState(() {
        _applyResolved(resolved);
        _gpsLoading = false;
      });
    } on PlacesLocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _gpsLoading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gpsLoading = false;
        _error = 'Could not get location. Edit the address or search.';
      });
    }
  }

  Future<void> _openSearchSheet() async {
    final picked = await showLocationPickerSheet(context);
    if (!mounted || picked == null) return;
    setState(() => _applyPostLocation(picked));
  }

  PostLocation? _locationToSave() {
    final raw = _addressController.text.trim();
    if (raw.length < _minAddressLength) return null;

    final lines =
        raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final primary = lines.isNotEmpty ? lines.first : raw;
    final secondary =
        lines.length > 1 ? lines.sublist(1).join(', ') : '';
    final singleLine =
        secondary.isEmpty ? primary : '$primary, $secondary';

    return PostLocation(
      placeId: _placeId,
      name: primary,
      address: singleLine,
      latitude: _latitude,
      longitude: _longitude,
      source: _locationSource,
    );
  }

  Future<void> _saveAndContinue({required bool skipped}) async {
    if (_saving) return;
    final uid = AuthService().currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    setState(() => _saving = true);
    try {
      await UserService().updateUserProfile(
        uid: uid,
        profileLocation: skipped ? null : _locationToSave(),
        locationSetupComplete: true,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save location. Check your connection and try again.',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<void> _onSkip() => _saveAndContinue(skipped: true);

  Future<void> _onNext() async {
    if (!_canContinue) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter an address or use current location.'),
        ),
      );
      return;
    }
    await _saveAndContinue(skipped: false);
  }

  Future<void> _onBack() async {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final navClearance = AuthFloatingNavRow.scrollBottomClearance(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          AppGradientBackground(
            type: GradientType.authFlow,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  const Center(
                    child: VyoooBrandLogo(size: AppSizes.authLogoHeight),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const OnboardingProgressBar(progress: _progressFill),
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.only(bottom: navClearance + bottomInset),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Where are you based?',
                            style: AppTypography.onboardingSectionTitle,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Shown on your profile. You can change this later in Settings.',
                            style: AppTypography.onboardingPrivacyBody.copyWith(
                              color: AppTheme.secondaryTextColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _buildMapPreview(),
                          const SizedBox(height: AppSpacing.lg),
                          _buildFieldLabel('Address'),
                          const SizedBox(height: AppSpacing.xs),
                          _buildAddressRow(),
                          if (_error != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _error!,
                              style: TextStyle(
                                color: Colors.orange.shade300,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          _buildSearchButton(),
                          const SizedBox(height: AppSpacing.md),
                          TextButton(
                            onPressed: _saving ? null : _onSkip,
                            child: Text(
                              'Not now',
                              style: AppTypography.onboardingPrivacyBody,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AuthFloatingNavRow(
            onBack: _onBack,
            onForward: _onNext,
            forwardEnabled: _canContinue && !_saving && !_gpsLoading,
            forwardLoading: _saving,
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: AppTypography.usernameFieldLabel.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.defaultTextColor,
      ),
    );
  }

  Widget _buildMapPreview() {
    return ClipRRect(
      borderRadius: AppRadius.inputRadius,
      child: SizedBox(
        height: _mapHeight,
        width: double.infinity,
        child: _hasMapCoordinates
            ? LocationMapPreview(
                latitude: _latitude!,
                longitude: _longitude!,
                height: _mapHeight,
              )
            : _mapPlaceholder(
                message: 'Use location or search to see the map',
              ),
      ),
    );
  }

  Widget _mapPlaceholder({
    String message = '',
    bool showLoading = false,
  }) {
    return Container(
      color: Colors.white.withValues(alpha: 0.06),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: showLoading
          ? const CircularProgressIndicator(color: Colors.white24)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 40,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    message,
                    style: AppTypography.onboardingPrivacyBody,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildAddressRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: AppRadius.inputRadius,
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: TextField(
              controller: _addressController,
              style: AppTypography.input,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Street, city, and region',
                hintStyle: AppTypography.inputHint,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _buildGpsButton(),
      ],
    );
  }

  Widget _buildGpsButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: (_gpsLoading || _saving) ? null : _useCurrentLocation,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: _gpsLoading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54,
                  ),
                )
              : const Icon(
                  Icons.my_location_rounded,
                  color: AppTheme.defaultTextColor,
                  size: 24,
                ),
        ),
      ),
    );
  }

  Widget _buildSearchButton() {
    return OutlinedButton.icon(
      onPressed: _saving ? null : _openSearchSheet,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.defaultTextColor,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.inputRadius),
      ),
      icon: const Icon(Icons.search, size: 20),
      label: Text(
        'Search for a place',
        style: AppTypography.input.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }
}
