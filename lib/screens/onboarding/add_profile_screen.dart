import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../services/image_picker_service.dart';
import '../../state/onboarding_state.dart';
import 'select_interests_screen.dart';

class AddProfileScreen extends StatefulWidget {
  const AddProfileScreen({
    super.key,
    this.onboardingState,
    this.imagePickerService,
  });

  final OnboardingState? onboardingState;
  final ImagePickerService? imagePickerService;

  @override
  State<AddProfileScreen> createState() => _AddProfileScreenState();
}

class _AddProfileScreenState extends State<AddProfileScreen> {
  static const double _horizontalPadding = 28;
  static const double _progressFill = 0.6;

  OnboardingState get _state => widget.onboardingState ?? _defaultState;
  ImagePickerService get _imageService =>
      widget.imagePickerService ?? ImagePickerService();

  static final OnboardingState _defaultState = OnboardingState();

  String? _profileImagePath;
  bool _isPicking = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _profileImagePath = _state.profileImagePath;
    _state.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (mounted) setState(() => _profileImagePath = _state.profileImagePath);
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isPicking) return;
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: AppColors.brandPurple,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.pop(context, 'camera'),
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                label: const Text(
                  'Camera',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pop(context, 'gallery'),
                icon: const Icon(Icons.photo_library, color: Colors.white),
                label: const Text(
                  'Gallery',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: White70.value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => _isPicking = true);
    try {
      final path = source == 'camera'
          ? await _imageService.pickFromCamera()
          : await _imageService.pickFromGallery();
      if (mounted && path != null) {
        _state.profileImagePath = path;
        setState(() {});
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _onNext() async {
    if (_isUploading) return;
    final uid = AuthService().currentUser?.uid;
    if (uid != null && _profileImagePath != null) {
      setState(() => _isUploading = true);
      try {
        await StorageService().uploadProfileImage(
          imageFile: File(_profileImagePath!),
          uid: uid,
        );
      } catch (_) {
        // Upload failed (e.g. Firebase Storage not enabled or rules). Still update Firestore
        // with empty profileImage so the field exists, and try next screen.
        try {
          await UserService().updateUserProfile(uid: uid, profileImage: '');
        } catch (_) {}
        if (mounted) setState(() => _isUploading = false);
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const SelectInterestsScreen(),
          ),
        );
        return;
      }
      if (!mounted) return;
      setState(() => _isUploading = false);
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SelectInterestsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.profile,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                /// TOP SECTION
                const SizedBox(height: 20),
                _buildLogo(),
                const SizedBox(height: 16),
                _buildProgressBar(),

                /// MIDDLE SECTION (CENTERED)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildAvatar(),
                      const SizedBox(height: 40),

                      const Text(
                        'Add a Profile page',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.defaultTextColor,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Select a photo that matches your vibe',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.secondaryTextColor,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                /// BOTTOM BUTTON
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _buildNextButton(),
                  ),
                ),
              ],
            ),
          ),
        ),
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
                Container(
                  width: fullWidth,
                  height: 3,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
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
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onTap: _isPicking ? null : _pickImage,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _profileImagePath != null
                  ? _buildAvatarImage()
                  : _buildDefaultAvatar(),
            ),
          ),

          /// sparkle icon
          Positioned(
            top: 8,
            left: 10,
            child: Image.asset(
              'assets/vyooO_icons/Home/vr.png',
              width: 50,
              height: 50,
              color: AppColors.lightGold,
            ),
          ),

          /// camera button
          Positioned(
            right: -2,
            bottom: 10,
            child: GestureDetector(
              onTap: _isPicking ? null : _pickImage,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF14001E),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: _isPicking
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Image.asset(
                        'assets/vyooO_icons/Profile/arrow.png',
                        width: 22,
                        height: 22,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      key: const ValueKey('default'),
      width: 221,
      height: 221,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: White10.value, width: 1),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_outline,
        size: 80,
        color: AppColors.brandPink,
      ),
    );
  }

  Widget _buildAvatarImage() {
    final path = _profileImagePath!;
    return Container(
      key: ValueKey(path),
      width: 221,
      height: 221,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: White10.value, width: 1),
        image: DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildNextButton() {
    return Material(
      elevation: 2,
      shape: const CircleBorder(),
      color: _isUploading
          ? Colors.white.withValues(alpha: 0.5)
          : AppTheme.buttonBackground,
      child: InkWell(
        onTap: _isUploading ? null : _onNext,
        customBorder: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          child: _isUploading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                )
              : Image.asset(
                  'assets/vyooO_icons/Profile/arrow.png',
                  width: 28,
                  height: 28,
                  color: AppTheme.buttonTextColor,
                ),
        ),
      ),
    );
  }
}
