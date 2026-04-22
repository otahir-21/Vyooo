import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../services/firestore_username_service.dart';
import '../../services/image_picker_service.dart';
import '../../services/username_validation.dart';
import '../music/music_picker_sheet.dart';
import 'personal_information_screen.dart';

/// Subscriber Edit Profile: avatar, Edit picture, Name/Username/Bio/Music, Personal information settings.
/// Username shows green check (available) or red X + error text (taken). Bio has character counter.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    this.initialName = 'Matt Rife',
    this.initialUsername = 'mattrife_x',
    this.initialBio = 'In the right place, at the right time',
    this.initialMusic = 'Zulfein • Mehul Mahesh, DJ A...',
    this.avatarUrl,
  });

  final String initialName;
  final String initialUsername;
  final String initialBio;
  final String initialMusic;
  final String? avatarUrl;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

enum _UsernameStatus { none, available, taken }

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _musicController;

  _UsernameStatus _usernameStatus = _UsernameStatus.none;

  /// Picked local file path after Edit picture → crop.
  String? _pickedImagePath;

  Timer? _usernameDebounce;
  bool _isSaving = false;

  static const int _bioMaxLength = 150;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _usernameController = TextEditingController(text: widget.initialUsername);
    _bioController = TextEditingController(text: widget.initialBio);
    _musicController = TextEditingController(text: widget.initialMusic);
    _nameController.addListener(_onFormChanged);
    _usernameController.addListener(_onUsernameChanged);
    _bioController.addListener(_onFormChanged);
    _musicController.addListener(_onFormChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final n = UsernameValidation.normalize(_usernameController.text.trim());
      if (!UsernameValidation.isValidFormat(n)) return;
      if (n == UsernameValidation.normalize(widget.initialUsername) && mounted) {
        setState(() => _usernameStatus = _UsernameStatus.available);
      }
    });
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _nameController.removeListener(_onFormChanged);
    _usernameController.removeListener(_onUsernameChanged);
    _bioController.removeListener(_onFormChanged);
    _musicController.removeListener(_onFormChanged);
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _musicController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    _usernameDebounce?.cancel();
    final text = _usernameController.text.trim();
    if (text.isEmpty) {
      setState(() => _usernameStatus = _UsernameStatus.none);
      return;
    }
    final normalized = UsernameValidation.normalize(text);
    if (!UsernameValidation.isValidFormat(normalized)) {
      setState(() => _usernameStatus = _UsernameStatus.none);
      return;
    }

    final initialNorm = UsernameValidation.normalize(widget.initialUsername);
    if (normalized == initialNorm) {
      setState(() => _usernameStatus = _UsernameStatus.available);
      return;
    }

    _usernameDebounce = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      final n = UsernameValidation.normalize(_usernameController.text.trim());
      if (!UsernameValidation.isValidFormat(n)) return;
      try {
        final result = await FirestoreUsernameService().checkAvailability(n);
        if (!mounted) return;
        if (UsernameValidation.normalize(_usernameController.text.trim()) != n) {
          return;
        }
        setState(() {
          _usernameStatus = result.available
              ? _UsernameStatus.available
              : _UsernameStatus.taken;
        });
      } catch (_) {
        if (mounted) setState(() => _usernameStatus = _UsernameStatus.none);
      }
    });
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  bool get _canSave {
    if (_isSaving) return false;
    final name = _nameController.text.trim();
    if (name.isEmpty) return false;
    final un = UsernameValidation.normalize(_usernameController.text.trim());
    if (!UsernameValidation.isValidFormat(un)) return false;
    if (_usernameStatus == _UsernameStatus.taken) return false;
    final initialUn = UsernameValidation.normalize(widget.initialUsername);
    final initialName = widget.initialName.trim();
    final initialBio = widget.initialBio.trim();
    final nameChanged = name != initialName;
    final usernameChanged = un != initialUn;
    final bioChanged = _bioController.text.trim() != initialBio;
    return _pickedImagePath != null || usernameChanged || nameChanged || bioChanged;
  }

  Future<void> _saveProfile() async {
    if (!_canSave) return;
    final uid = AuthService().currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not signed in.')),
        );
      }
      return;
    }

    final username = UsernameValidation.normalize(_usernameController.text.trim());
    final name = _nameController.text.trim();
    final bio = _bioController.text.trim();
    final initialUn = UsernameValidation.normalize(widget.initialUsername);
    final initialName = widget.initialName.trim();
    final initialBio = widget.initialBio.trim();

    setState(() => _isSaving = true);
    var partialWarning = false;
    try {
      if (_pickedImagePath != null) {
        try {
          await StorageService().uploadProfileImage(
            imageFile: File(_pickedImagePath!),
            uid: uid,
          );
        } catch (e) {
          // Non-fatal: let profile text changes still save.
          partialWarning = true;
          debugPrint('Profile image upload failed: $e');
        }
      }

      if (username != initialUn) {
        final avail = await FirestoreUsernameService().checkAvailability(username);
        if (!avail.available) {
          if (mounted) {
            setState(() {
              _isSaving = false;
              _usernameStatus = _UsernameStatus.taken;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('That username is already taken.')),
            );
          }
          return;
        }
        await UserService().updateUserProfile(uid: uid, username: username);
      }

      if (name != initialName) {
        await UserService().updateUserProfile(uid: uid, displayName: name);
        await AuthService().currentUser?.updateDisplayName(name);
      }

      if (bio != initialBio) {
        try {
          await UserService().updateUserProfile(uid: uid, bio: bio);
        } catch (e) {
          // Non-fatal: in case deployed Firestore rules don't yet allow `bio`.
          partialWarning = true;
          debugPrint('Bio update failed: $e');
        }
      }

      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          partialWarning
              ? 'Profile updated, but some changes could not be saved.'
              : 'Profile updated',
        ),
      ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.profile,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      _buildProfilePictureSection(),
                      const SizedBox(height: AppSpacing.xl),
                      _buildNameField(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildUsernameField(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildBioField(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildMusicField(),
                      const SizedBox(height: AppSpacing.xl),
                      _buildPersonalInfoLink(),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text(
              'Edit Profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _canSave ? _saveProfile : null,
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: _canSave ? const Color(0xFFDE106B) : Colors.white38,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _onEditPicture() async {
    final source = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Profile Photo'),
        message: const Text('Choose where to pick your photo from'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('camera'),
            child: const Text('Take Photo'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('gallery'),
            child: const Text('Choose from Library'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (!mounted || source == null) return;

    final picker = ImagePickerService();
    final path = source == 'camera'
        ? await picker.pickFromCamera()
        : await picker.pickFromGallery();
    if (!mounted || path == null) return;

    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop profile photo',
            toolbarColor: AppColors.brandPurple,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.black,
            activeControlsWidgetColor: AppColors.brandPink,
            lockAspectRatio: true,
            initAspectRatio: CropAspectRatioPreset.square,
            aspectRatioPresets: const [CropAspectRatioPreset.square],
            cropStyle: CropStyle.circle,
            hideBottomControls: true,
          ),
          IOSUiSettings(
            title: 'Crop profile photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            cropStyle: CropStyle.circle,
          ),
        ],
      );
      if (!mounted) return;
      if (cropped != null) {
        setState(() => _pickedImagePath = cropped.path);
      }
    } catch (error) {
      debugPrint('Profile crop failed in edit profile: $error');
      if (mounted) setState(() => _pickedImagePath = path);
    }
  }

  Widget _buildProfilePictureSection() {
    final avatarUrl = widget.avatarUrl;
    final hasLocal = _pickedImagePath != null;
    final file = hasLocal ? File(_pickedImagePath!) : null;
    return Column(
      children: [
        CircleAvatar(
          radius: 56,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          backgroundImage: hasLocal && file != null
              ? FileImage(file)
              : (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? NetworkImage(avatarUrl)
                  : null,
          child: (avatarUrl == null || avatarUrl.isEmpty) && !hasLocal
              ? Icon(Icons.person_rounded, size: 56, color: Colors.white.withValues(alpha: 0.6))
              : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        GestureDetector(
          onTap: _onEditPicture,
          child: const Text(
            'Edit picture',
            style: TextStyle(
              color: Color(0xFFDE106B),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return _EditProfileRow(
      label: 'Name',
      child: TextField(
        controller: _nameController,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 16),
        decoration: _inputDecoration(hint: ''),
      ),
    );
  }

  Widget _buildUsernameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditProfileRow(
          label: 'Username',
          child: TextField(
            controller: _usernameController,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 16,
            ),
            decoration: _inputDecoration(hint: 'username').copyWith(
              suffixIcon: _usernameStatus == _UsernameStatus.available
                  ? Icon(Icons.check_circle_rounded, color: Colors.green.shade400, size: 22)
                  : _usernameStatus == _UsernameStatus.taken
                      ? Icon(Icons.cancel_rounded, color: AppColors.deleteRed, size: 22)
                      : null,
            ),
          ),
        ),
        if (_usernameStatus == _UsernameStatus.taken) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 0),
            child: Text(
              'This username is already taken',
              style: TextStyle(color: AppColors.deleteRed, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBioField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditProfileRow(
          label: 'Bio',
          child: TextField(
            controller: _bioController,
            maxLines: 3,
            maxLength: _bioMaxLength,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 16),
            decoration: _inputDecoration(hint: 'Add your bio').copyWith(
              counterText: '',
              contentPadding: const EdgeInsets.only(bottom: 20),
            ),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _bioController,
          builder: (context, value, _) => Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${value.text.length}/$_bioMaxLength',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMusicField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              showMusicPickerSheet(
                context,
                currentDisplay: _musicController.text,
                onDone: (track) {
                  setState(() => _musicController.text = track.profileDisplay);
                },
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Music',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        _musicController.text,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Divider(height: 1, color: Colors.white.withValues(alpha: 0.25)),
      ],
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint.isEmpty ? null : hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 16),
      border: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
      ),
      contentPadding: const EdgeInsets.only(bottom: 8),
      isDense: true,
    );
  }

  Widget _buildPersonalInfoLink() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const PersonalInformationScreen(),
          ),
        );
      },
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 20, color: Colors.white),
          const SizedBox(width: AppSpacing.sm),
          const Text(
            'Personal information settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Label on left, input on right; single underline across.
class _EditProfileRow extends StatelessWidget {
  const _EditProfileRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: child),
      ],
    );
  }
}
