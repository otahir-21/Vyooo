import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_background_assets.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/dob_validation.dart';
import '../../core/utils/establishment_date_validation.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../core/widgets/auth/auth_widgets.dart';
import '../../core/widgets/vyooo_brand_logo.dart';

const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Government onboarding: when the department/agency was established (not personal DOB).
class SelectEstablishmentDateScreen extends StatefulWidget {
  const SelectEstablishmentDateScreen({super.key});

  @override
  State<SelectEstablishmentDateScreen> createState() =>
      _SelectEstablishmentDateScreenState();
}

class _SelectEstablishmentDateScreenState
    extends State<SelectEstablishmentDateScreen> {
  static const double _horizontalPadding = 28;
  static const double _progressFill = 0.4;
  static const double _pickerHeight = 190;
  static const double _pickerItemExtent = 44;

  late int _monthIndex;
  late int _dayIndex;
  late int _yearIndex;
  late List<int> _years;
  late List<int> _days;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _dayController;
  late FixedExtentScrollController _yearController;

  int get _month => _monthIndex + 1;
  int get _year => _years[_yearIndex];
  int get _day => _days[_dayIndex];

  DateTime get _selectedDate => DateTime(_year, _month, _day);
  bool get _isValid =>
      EstablishmentDateValidation.isValidEstablishmentDate(_selectedDate);

  @override
  void initState() {
    super.initState();
    _years = EstablishmentDateValidation.allowedYears;
    final defaultYear = DateTime.now().year - 20;
    _yearIndex = _years.indexOf(defaultYear).clamp(0, _years.length - 1);
    if (_yearIndex < 0) _yearIndex = _years.length ~/ 2;
    _monthIndex = 0;
    _dayIndex = 0;
    _updateDaysList();
    _monthController = FixedExtentScrollController(initialItem: _monthIndex);
    _dayController = FixedExtentScrollController(initialItem: _dayIndex);
    _yearController = FixedExtentScrollController(initialItem: _yearIndex);
  }

  void _updateDaysList() {
    final maxDay = DobValidation.daysInMonth(_year, _month);
    _days = List.generate(maxDay, (i) => i + 1);
    _dayIndex = _dayIndex.clamp(0, _days.length - 1);
    if (_days.isNotEmpty && _day > _days.last) {
      _dayIndex = _days.length - 1;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dayController.hasClients && _dayIndex < _days.length) {
        _dayController.jumpToItem(_dayIndex);
      }
    });
  }

  @override
  void dispose() {
    _monthController.dispose();
    _dayController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _onMonthChanged(int index) {
    setState(() {
      _monthIndex = index;
      _updateDaysList();
    });
  }

  void _onDayChanged(int index) {
    setState(() => _dayIndex = index);
  }

  void _onYearChanged(int index) {
    setState(() {
      _yearIndex = index;
      _updateDaysList();
    });
  }

  Future<void> _onNext() async {
    if (!_isValid) return;
    final uid = AuthService().currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        final iso =
            '${_year.toString().padLeft(4, '0')}-${_month.toString().padLeft(2, '0')}-${_day.toString().padLeft(2, '0')}';
        await UserService().patchOrganizationDetails(
          uid: uid,
          patch: {'establishmentDate': iso},
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save establishment date. Check your connection and try again.',
            ),
          ),
        );
        return;
      }
    }
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onBack() async {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    await AuthService().signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          AppGradientBackground(
            type: GradientType.authFlow,
            backgroundAsset: AppBackgroundAssets.otpScreen,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _horizontalPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    const VyoooBrandLogo(size: AppSizes.authLogoHeight),
                    const SizedBox(height: 16),
                    _buildProgressBar(),
                    const SizedBox(height: 40),
                    _buildAvatar(),
                    const SizedBox(height: 30),
                    const Text(
                      'When was your department\nestablished?',
                      style: AppTypography.onboardingSectionTitle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use the official founding or establishment date',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.secondaryTextColor.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    _buildPicker(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
          AuthFloatingNavRow(
            onBack: _onBack,
            onForward: _onNext,
            forwardEnabled: _isValid,
          ),
        ],
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
                      color: Color(0xFFDE106B),
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
      child: Image.asset(
        'assets/vyooO_icons/Onboarding/username_profile_avatar.png',
        width: 150,
        height: 150,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildPicker() {
    return Container(
      height: _pickerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Stack(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: CupertinoPicker.builder(
                  scrollController: _monthController,
                  itemExtent: _pickerItemExtent,
                  selectionOverlay: const SizedBox(),
                  onSelectedItemChanged: _onMonthChanged,
                  childCount: 12,
                  itemBuilder: (context, index) {
                    final selected = _monthIndex == index;
                    return Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: selected
                            ? AppTypography.dobPickerSelected
                            : AppTypography.dobPickerUnselected,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _monthNames[index],
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                flex: 1,
                child: CupertinoPicker.builder(
                  scrollController: _dayController,
                  itemExtent: _pickerItemExtent,
                  selectionOverlay: const SizedBox(),
                  onSelectedItemChanged: _onDayChanged,
                  childCount: _days.length,
                  itemBuilder: (context, index) {
                    final selected = _dayIndex == index;
                    return Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: selected
                            ? AppTypography.dobPickerSelected
                            : AppTypography.dobPickerUnselected,
                        child: Text('${_days[index]}'),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                flex: 2,
                child: CupertinoPicker.builder(
                  scrollController: _yearController,
                  itemExtent: _pickerItemExtent,
                  selectionOverlay: const SizedBox(),
                  onSelectedItemChanged: _onYearChanged,
                  childCount: _years.length,
                  itemBuilder: (context, index) {
                    final selected = _yearIndex == index;
                    return Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: selected
                            ? AppTypography.dobPickerSelected
                            : AppTypography.dobPickerUnselected,
                        child: Text('${_years[index]}'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          Center(
            child: IgnorePointer(
              child: Container(
                height: _pickerItemExtent,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
