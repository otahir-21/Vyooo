import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../core/widgets/interest_chip.dart';
import '../../core/widgets/onboarding_progress_bar.dart';
import '../../state/onboarding_state.dart';
import 'onboarding_complete_screen.dart';

/// Default interest options. Replace with API-driven list when ready.
const List<String> _defaultInterests = [
  'Music',
  'Gaming',
  'Sports',
  'Travel',
  'Food',
  'Tech',
  'Art',
  'Fashion',
  'Fitness',
  'Movies',
  'Books',
  'Photography',
  'Dance',
  'Cooking',
  'Nature',
  'Comedy',
  'Podcasts',
  'DIY',
  'Pets',
];

class SelectInterestsScreen extends StatefulWidget {
  const SelectInterestsScreen({
    super.key,
    this.onboardingState,
    this.interests = _defaultInterests,
  });

  final OnboardingState? onboardingState;
  final List<String> interests;

  @override
  State<SelectInterestsScreen> createState() => _SelectInterestsScreenState();
}

class _SelectInterestsScreenState extends State<SelectInterestsScreen> {
  static const double _horizontalPadding = 28;
  static const int _minSelections = 3;

  OnboardingState get _state => widget.onboardingState ?? _defaultState;
  static final OnboardingState _defaultState = OnboardingState();

  late List<String> _interests;
  late TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _interests = List.from(widget.interests);
    _searchController = TextEditingController();
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
    _state.addListener(_onStateChanged);
  }

  void _onStateChanged() => setState(() {});

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filteredInterests {
    if (_searchQuery.isEmpty) return _interests;
    return _interests
        .where((s) => s.toLowerCase().contains(_searchQuery))
        .toList();
  }

  int get _selectedCount => _state.selectedInterests.length;
  bool get _canContinue => _selectedCount >= _minSelections;

  void _toggleInterest(String id) {
    _state.toggleInterest(id);
  }

  Future<void> _onNext() async {
    if (!_canContinue) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 3 interests.')),
      );
      return;
    }
    final uid = AuthService().currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        await UserService().updateUserProfile(
          uid: uid,
          interests: _state.selectedInterests,
        );
      } catch (_) {
        // Still navigate so onboarding isn't blocked by Firestore errors
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const OnboardingCompleteScreen(),
          ),
        );
        return;
      }
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const OnboardingCompleteScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          AppGradientBackground(
            type: GradientType.profile,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _horizontalPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 5.0, right: 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        const OnboardingProgressBar(progress: 0.85),
                        const SizedBox(height: 40),
                        _buildTitleSection(),
                        const SizedBox(height: 20),
                        _buildSearchBar(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(child: _buildChipsRows()),
                  ),
                  const SizedBox(height: 16),
                  _buildHelperText(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          Positioned(right: 24, bottom: 24, child: _buildNextButton()),
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

  Widget _buildTitleSection() {
    final height = MediaQuery.sizeOf(context).height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What's your vibe?",
          style: TextStyle(
            fontSize: height * 0.05,
            fontWeight: FontWeight.w700,
            color: AppTheme.defaultTextColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Powered by AI to match you with content that truly vibes with you',
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.secondaryTextColor,
            fontWeight: FontWeight.w400,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/vyooO_icons/Home/nav_bar_icons/search.png',
            width: 22,
            height: 22,
            color: AppTheme.searchBarColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                color: AppTheme.defaultTextColor,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'Search interests...',
                hintStyle: const TextStyle(color: White50.value, fontSize: 16),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          Image.asset(
            'assets/vyooO_icons/Search/microphone.png',
            width: 22,
            height: 22,
            color: AppTheme.searchBarColor,
          ),
        ],
      ),
    );
  }

  static const int _chipsPerRow = 7;

  Widget _buildChipsRows() {
    final list = _filteredInterests;
    final chunks = <List<String>>[];
    for (var i = 0; i < list.length; i += _chipsPerRow) {
      chunks.add(
        list.sublist(
          i,
          i + _chipsPerRow > list.length ? list.length : i + _chipsPerRow,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var r = 0; r < chunks.length; r++) ...[
          if (r > 0) const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < chunks[r].length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    InterestChip(
                      label: chunks[r][i],
                      isSelected: _state.selectedInterests.contains(
                        chunks[r][i],
                      ),
                      onTap: () => _toggleInterest(chunks[r][i]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHelperText() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _canContinue ? 0.6 : 1.0,
      child: Center(
        child: Text(
          'Select at least 3 interests to continue',
          style: const TextStyle(
            fontSize: 12,
            color: White60.value,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    return Material(
      elevation: 2,
      shape: const CircleBorder(),
      color: _canContinue
          ? AppTheme.buttonBackground
          : Colors.white.withValues(alpha: 0.4),
      child: InkWell(
        onTap: _onNext,
        customBorder: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          child: Icon(
            Icons.arrow_forward,
            color: _canContinue ? AppTheme.buttonTextColor : White50.value,
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
