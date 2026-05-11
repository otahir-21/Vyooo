import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_gradient_background.dart';

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({
    super.key,
    this.email,
    this.phone,
    this.dateOfBirth,
  });

  final String? email;
  final String? phone;
  final String? dateOfBirth;

  @override
  State<PersonalInformationScreen> createState() => _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  static const List<String> _accountTypeOptions = <String>[
    'private',
    'public',
    'business',
    'government',
  ];
  static const List<String> _interestOptions = <String>[
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

  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _orgNameController = TextEditingController();
  final _workEmailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _industryController = TextEditingController();
  final _locationController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _publicPersonaController = TextEditingController();

  String _selectedAccountType = 'private';
  bool _loading = true;
  bool _saving = false;
  String _email = '';
  List<String> _selectedInterests = <String>[];

  bool get _showOrgFields =>
      _selectedAccountType == 'business' || _selectedAccountType == 'government';

  DateTime? _parseDob(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (iso != null) {
      final year = int.tryParse(iso.group(1)!);
      final month = int.tryParse(iso.group(2)!);
      final day = int.tryParse(iso.group(3)!);
      if (year != null && month != null && day != null) {
        return DateTime(year, month, day);
      }
    }
    final slash = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(value);
    if (slash != null) {
      final day = int.tryParse(slash.group(1)!);
      final month = int.tryParse(slash.group(2)!);
      final year = int.tryParse(slash.group(3)!);
      if (year != null && month != null && day != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  String _formatDob(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _parseDob(_dobController.text) ?? DateTime(now.year - 18, 1, 1);
    DateTime selected = initial;
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: 320,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(selected),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: initial,
                    maximumDate: DateTime(now.year - 13, 12, 31),
                    minimumDate: DateTime(1900, 1, 1),
                    onDateTimeChanged: (value) => selected = value,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _dobController.text = _formatDob(picked);
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _orgNameController.dispose();
    _workEmailController.dispose();
    _websiteController.dispose();
    _descriptionController.dispose();
    _industryController.dispose();
    _locationController.dispose();
    _contactPhoneController.dispose();
    _publicPersonaController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final authUser = AuthService().currentUser;
    final uid = authUser?.uid;
    final fallbackEmail = widget.email ?? authUser?.email ?? '';
    final fallbackPhone = widget.phone ?? authUser?.phoneNumber ?? '';
    final fallbackDob = widget.dateOfBirth ?? '';
    if (uid == null || uid.isEmpty) {
      _email = fallbackEmail;
      _emailController.text = _email;
      _phoneController.text = fallbackPhone;
      _dobController.text = fallbackDob;
      if (mounted) setState(() => _loading = false);
      return;
    }

    final user = await UserService().getUser(uid);
    final userEmail = (user?.email ?? '').trim();
    final userPhone = (user?.phoneNumber ?? '').trim();
    final userDob = (user?.dob ?? '').trim();
    _email = userEmail.isNotEmpty ? userEmail : fallbackEmail;
    _emailController.text = _email;
    _phoneController.text = userPhone.isNotEmpty ? userPhone : fallbackPhone;
    _dobController.text = userDob.isNotEmpty ? userDob : fallbackDob;
    final rawType = (user?.accountType ?? 'private').trim().toLowerCase();
    _selectedAccountType = rawType == 'personal' ? 'private' : rawType;
    if (!_accountTypeOptions.contains(_selectedAccountType)) {
      _selectedAccountType = 'private';
    }
    final org = user?.organizationDetails ?? const <String, dynamic>{};
    _orgNameController.text = (org['orgName'] ?? '').toString();
    _workEmailController.text = (org['workEmail'] ?? '').toString();
    _websiteController.text = (org['website'] ?? '').toString();
    _descriptionController.text = (org['description'] ?? '').toString();
    _industryController.text = (org['industry'] ?? '').toString();
    _locationController.text = (org['location'] ?? '').toString();
    _contactPhoneController.text = (org['contactPhone'] ?? '').toString();
    _publicPersonaController.text = (user?.publicPersona ?? '').trim();
    _selectedInterests = List<String>.from(user?.interests ?? const <String>[]);

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_saving) return;
    final uid = AuthService().currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    final accountKey = _selectedAccountType.trim().toLowerCase();
    if (accountKey == 'public') {
      final persona = UserService.normalizePublicPersona(_publicPersonaController.text);
      if (persona.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'For a public account, add at least 2 characters describing your profile (e.g. creator, entrepreneur).',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final authUser = AuthService().currentUser;
      final nextEmail = _emailController.text.trim().toLowerCase();
      final currentEmail = (_email).trim().toLowerCase();
      if (nextEmail.isNotEmpty && nextEmail != currentEmail && authUser != null) {
        await authUser.verifyBeforeUpdateEmail(nextEmail);
      }

      final orgDetails = <String, dynamic>{
        'orgName': _orgNameController.text.trim(),
        'workEmail': _workEmailController.text.trim(),
        'website': _websiteController.text.trim(),
        'description': _descriptionController.text.trim(),
        'industry': _industryController.text.trim(),
        'location': _locationController.text.trim(),
        'contactPhone': _contactPhoneController.text.trim(),
        'orgType': _selectedAccountType,
      };
      final hasOrgData = orgDetails.values.any((v) => v.toString().isNotEmpty);
      await UserService().updateUserProfile(
        uid: uid,
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        dob: _dobController.text.trim(),
        accountType: _selectedAccountType,
        publicPersona: accountKey == 'public'
            ? UserService.normalizePublicPersona(_publicPersonaController.text)
            : '',
        interests: _selectedInterests,
        orgProfileCompleted: _showOrgFields ? hasOrgData : false,
        organizationDetails: _showOrgFields ? orgDetails : <String, dynamic>{},
      );
      if (!mounted) return;
      setState(() => _email = _emailController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Personal information updated')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().contains('requires-recent-login')
          ? 'For security, please log in again before changing email.'
          : 'Could not save: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
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
              _buildAppBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: _loading ? _buildLoading() : _buildContent(context),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text(
              'Personal Information',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.only(top: 64),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(
          'Provide your personal information, even if the account is for something such as a business or pet. It won\'t be part of your public profile.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'To keep your account secure, don\'t enter an email address or phone number that belongs to someone else.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _EditableFieldRow(
          label: 'Email',
          controller: _emailController,
          hint: 'name@example.com',
        ),
        _EditableFieldRow(label: 'Phone', controller: _phoneController),
        _DatePickerFieldRow(
          label: 'Date of Birth',
          controller: _dobController,
          onTap: _pickDob,
        ),
        _AccountTypeRow(
          value: _selectedAccountType,
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedAccountType = value);
          },
        ),
        if (_selectedAccountType == 'public') ...[
          const SizedBox(height: AppSpacing.sm),
          _EditableFieldRow(
            label: 'Public profile type',
            controller: _publicPersonaController,
            hint: 'e.g. Entrepreneur, Celebrity, Content creator',
            maxLength: UserService.publicPersonaMaxLength,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Interests',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _interestOptions.map((interest) {
            final isSelected = _selectedInterests.contains(interest);
            return FilterChip(
              label: Text(interest),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    if (!_selectedInterests.contains(interest)) {
                      _selectedInterests.add(interest);
                    }
                  } else {
                    _selectedInterests.remove(interest);
                  }
                });
              },
              selectedColor: Colors.pink.withValues(alpha: 0.35),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              checkmarkColor: Colors.white,
              labelStyle: const TextStyle(color: Colors.white),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
            );
          }).toList(),
        ),
        if (_showOrgFields) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Organization details',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _EditableFieldRow(label: 'Org name', controller: _orgNameController),
          _EditableFieldRow(label: 'Work email', controller: _workEmailController),
          _EditableFieldRow(label: 'Website', controller: _websiteController),
          _EditableFieldRow(label: 'Industry', controller: _industryController),
          _EditableFieldRow(label: 'Location', controller: _locationController),
          _EditableFieldRow(label: 'Contact phone', controller: _contactPhoneController),
          _EditableFieldRow(
            label: 'Description',
            controller: _descriptionController,
            maxLines: 3,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _EditableFieldRow extends StatelessWidget {
  const _EditableFieldRow({
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.maxLength,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
          ),
        ),
      ),
    );
  }
}

class _DatePickerFieldRow extends StatelessWidget {
  const _DatePickerFieldRow({
    required this.label,
    required this.controller,
    required this.onTap,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        child: IgnorePointer(
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: label,
              hintText: 'YYYY-MM-DD',
              suffixIcon: const Icon(Icons.calendar_today, color: Colors.white70, size: 18),
              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountTypeRow extends StatelessWidget {
  const _AccountTypeRow({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Account type',
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF2A0030),
          style: const TextStyle(color: Colors.white),
          isExpanded: true,
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem(value: 'private', child: Text('Private')),
            DropdownMenuItem(value: 'public', child: Text('Public')),
            DropdownMenuItem(value: 'business', child: Text('Business')),
            DropdownMenuItem(value: 'government', child: Text('Government')),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
