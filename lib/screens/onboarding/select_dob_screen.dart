import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dob_validation.dart';
import '../../core/widgets/app_gradient_background.dart';
import 'add_profile_screen.dart';

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

class SelectDobScreen extends StatefulWidget {
  const SelectDobScreen({super.key, this.onDobSelected});

  /// Called with selected valid date when user taps Next.
  final void Function(DateTime date)? onDobSelected;

  @override
  State<SelectDobScreen> createState() => _SelectDobScreenState();
}

class _SelectDobScreenState extends State<SelectDobScreen> {
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
  bool get _isValid => DobValidation.isValidBirthDate(_selectedDate);

  @override
  void initState() {
    super.initState();
    _years = DobValidation.allowedYears;
    final defaultYear = DateTime.now().year - 25;
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
    widget.onDobSelected?.call(_selectedDate);
    final uid = AuthService().currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        final dobString =
            '${_year.toString().padLeft(4, '0')}-${_month.toString().padLeft(2, '0')}-${_day.toString().padLeft(2, '0')}';
        await UserService().updateUserProfile(uid: uid, dob: dobString);
      } catch (_) {
        if (!mounted) return;
      }
    }
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AddProfileScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          AppGradientBackground(
            type: GradientType.dob,
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
                      'Select your Date of birth',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.defaultTextColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    _buildPicker(),
                    const SizedBox(height: 16),
                    _buildPrivacyText(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
          Positioned(right: 24, bottom: 24, child: _buildFab()),
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
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
              border: Border.all(color: White10.value, width: 1),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.person_outline,
              size: 64,
              color: AppColors.brandPink,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: Image.asset(
              'assets/vyooO_icons/Home/vr.png',
              width: 22,
              height: 22,
              color: AppColors.lightGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPicker() {
    return Container(
      height: _pickerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      // decoration: BoxDecoration(
      //   borderRadius: BorderRadius.circular(20),
      //   color: Colors.transparent,
      //   border: Border.all(color: Colors.white.withOpacity(0.08)),
      // ),
      child: Stack(
        children: [
          /// PICKERS
          Row(
            children: [
              Expanded(
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
                        style: TextStyle(
                          fontSize: selected ? 20 : 16,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected
                              ? Colors.white
                              : Colors.white.withOpacity(0.35),
                        ),
                        child: Text(_monthNames[index]),
                      ),
                    );
                  },
                ),
              ),

              Expanded(
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
                        style: TextStyle(
                          fontSize: selected ? 20 : 16,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected
                              ? Colors.white
                              : Colors.white.withOpacity(0.35),
                        ),
                        child: Text('${_days[index]}'),
                      ),
                    );
                  },
                ),
              ),

              Expanded(
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
                        style: TextStyle(
                          fontSize: selected ? 20 : 16,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected
                              ? Colors.white
                              : Colors.white.withOpacity(0.35),
                        ),
                        child: Text('${_years[index]}'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          /// CENTER SELECTION HIGHLIGHT
          Center(
            child: IgnorePointer(
              child: Container(
                height: _pickerItemExtent,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
          ),

          /// TOP FADE
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 60,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.45),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          /// BOTTOM FADE
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 60,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.45),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyText() {
    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: const TextStyle(
            fontSize: 12,
            color: White50.value,
            fontWeight: FontWeight.w400,
          ),
          children: [
            const TextSpan(
              text: 'Please refer to our ',
              style: TextStyle(
                fontSize: 12,
                color: White50.value,
                fontWeight: FontWeight.w400,
              ),
            ),
            WidgetSpan(
              child: GestureDetector(
                onTap: () {
                  // TODO: open Privacy Policy
                },
                child: const Text(
                  'Privacy Policy',
                  style: TextStyle(
                    fontSize: 12,
                    color: White50.value,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const TextSpan(
              text: ' for further information on how we process this data.',
              style: TextStyle(
                fontSize: 12,
                color: White50.value,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFab() {
    return Material(
      elevation: 2,
      shape: const CircleBorder(),
      color: AppTheme.buttonBackground,
      child: InkWell(
        onTap: _isValid ? _onNext : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          child: Icon(
            Icons.arrow_forward,
            color: _isValid ? AppTheme.buttonTextColor : Colors.grey,
            size: 28,
          ),
        ),
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
