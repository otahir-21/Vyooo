import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/app_user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/user_service.dart';
import '../../core/services/verification_request_service.dart';
import '../../core/widgets/app_gradient_background.dart';

class VerificationRequestScreen extends StatefulWidget {
  const VerificationRequestScreen({super.key});

  @override
  State<VerificationRequestScreen> createState() => _VerificationRequestScreenState();
}

class _VerificationRequestScreenState extends State<VerificationRequestScreen> {
  final _fullNameController = TextEditingController();
  final _countryController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedIdType = 'Passport';
  bool _submitting = false;
  bool _pickingPdf = false;
  bool _loading = true;
  String _status = 'none';
  bool _isVerified = false;
  String? _pdfPath;
  String? _pdfName;

  static const List<String> _idTypes = [
    'Passport',
    'National ID',
    'Driving License',
  ];

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _countryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final uid = AuthService().currentUser?.uid ?? '';
    if (uid.isEmpty) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    final AppUserModel? user = await UserService().getUser(uid);
    final latest = await VerificationRequestService().getLatestRequestForUser(uid);
    if (!mounted) return;
    setState(() {
      _isVerified = user?.isVerified ?? false;
      _status = (latest?['status'] as String? ??
              user?.verificationStatus ??
              'none')
          .toLowerCase();
      _loading = false;
    });
  }

  Future<void> _submit() async {
    final uid = AuthService().currentUser?.uid ?? '';
    final email = AuthService().currentUser?.email ?? '';
    if (uid.isEmpty) return;
    final fullName = _fullNameController.text.trim();
    final country = _countryController.text.trim();
    if (fullName.isEmpty || country.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill full name and country.')),
      );
      return;
    }
    if ((_pdfPath ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please attach a PDF document.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final hasOpen = await VerificationRequestService().hasOpenRequest(uid);
      if (hasOpen) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You already have a pending request.')),
        );
        setState(() {
          _submitting = false;
          _status = 'pending';
        });
        return;
      }
      final requestRef = DateTime.now().millisecondsSinceEpoch.toString();
      final pdfUrl = await StorageService().uploadVerificationPdf(
        pdfFile: File(_pdfPath!),
        uid: uid,
        requestRef: requestRef,
      );
      await VerificationRequestService().submitRequest(
        uid: uid,
        email: email,
        fullName: fullName,
        country: country,
        idType: _selectedIdType,
        notes: _notesController.text,
        pdfUrl: pdfUrl,
        pdfFileName: _pdfName,
      );
      if (!mounted) return;
      setState(() {
        _status = 'pending';
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification request submitted.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
    }
  }

  Future<void> _pickPdf() async {
    if (_pickingPdf) return;
    setState(() => _pickingPdf = true);
    try {
      FilePickerResult? result;
      try {
        result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['pdf'],
        );
      } on MissingPluginException {
        // Some installed native plugin builds don't expose `custom`; fallback to
        // generic picker and validate extension locally.
        result = await FilePicker.pickFiles(type: FileType.any);
      }
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.path == null || file.path!.isEmpty) return;
      final isPdf = file.name.toLowerCase().endsWith('.pdf') ||
          file.path!.toLowerCase().endsWith('.pdf');
      if (!isPdf) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a PDF file only.')),
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _pdfPath = file.path!;
        _pdfName = file.name;
      });
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'File picker is not available in this build. Please restart the app.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _pickingPdf = false);
    }
  }

  String _statusLabel() {
    switch (_status) {
      case 'verified':
        return 'Verified';
      case 'pending':
      case 'submitted':
      case 'in_review':
        return 'Pending review';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Not requested';
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestLocked = _isVerified ||
        _status == 'pending' ||
        _status == 'submitted' ||
        _status == 'in_review';
    return Scaffold(
      body: AppGradientBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAppBar(context),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 24,
                      ),
                      children: [
                        _statusCard(),
                        const SizedBox(height: 20),
                        _field(
                          controller: _fullNameController,
                          label: 'Full legal name',
                          enabled: !requestLocked,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _countryController,
                          label: 'Country',
                          enabled: !requestLocked,
                        ),
                        const SizedBox(height: 12),
                        _idTypeDropdown(enabled: !requestLocked),
                        const SizedBox(height: 12),
                        _pdfAttachmentTile(enabled: !requestLocked),
                        const SizedBox(height: 12),
                        _field(
                          controller: _notesController,
                          label: 'Notes (optional)',
                          enabled: !requestLocked,
                          maxLines: 4,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: requestLocked || _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF81945),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _submitting ? 'Submitting...' : 'Submit Verification Request',
                          ),
                        ),
                        if (requestLocked) ...[
                          const SizedBox(height: 10),
                          Text(
                            _isVerified
                                ? 'Your badge is active.'
                                : 'Your request is under review by admin.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard() {
    final text = _statusLabel();
    final color = _isVerified
        ? const Color(0xFF22C55E)
        : (_status == 'rejected'
              ? const Color(0xFFF43F5E)
              : const Color(0xFFFACC15));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Verification status: $text',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required bool enabled,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFFF81945), width: 1.2),
        ),
      ),
    );
  }

  Widget _idTypeDropdown({required bool enabled}) {
    return DropdownButtonFormField<String>(
      value: _selectedIdType,
      onChanged: enabled ? (v) => setState(() => _selectedIdType = v!) : null,
      items: _idTypes
          .map((type) => DropdownMenuItem(value: type, child: Text(type)))
          .toList(),
      dropdownColor: const Color(0xFF1A0A24),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'ID type',
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
      ),
    );
  }

  Widget _pdfAttachmentTile({required bool enabled}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _pdfName == null ? 'No PDF attached' : _pdfName!,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: (!enabled || _pickingPdf) ? null : _pickPdf,
            child: Text(_pickingPdf ? 'Picking...' : 'Attach PDF'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                SizedBox(width: 12),
                Text(
                  'Request Verification',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'VyooO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

