import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart';

import '../../core/services/reels_service.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_gradient_background.dart';
import 'upload_success_screen.dart';

/// Upload Details screen: title, description, tags, isVR.
/// Gets a direct upload URL from Cloud Function → uploads to Cloudflare Stream
/// → saves reel doc to Firestore with Stream playback URL.
class UploadDetailsScreen extends StatefulWidget {
  const UploadDetailsScreen({super.key, required this.asset});

  final AssetEntity asset;

  @override
  State<UploadDetailsScreen> createState() => _UploadDetailsScreenState();
}

class _UploadDetailsScreenState extends State<UploadDetailsScreen> {
  static const Color _pink = Color(0xFFDE106B);

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _tagsController = TextEditingController();

  bool _isVR = false;
  bool _isUploading = false;
  double _uploadProgress = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      // 1 — get file from asset
      final file = await widget.asset.file;
      if (file == null || !mounted) {
        setState(() => _isUploading = false);
        return;
      }

      // 2 — get direct upload URL from Cloud Function, then upload to Cloudflare
      final videoUrl = await _uploadVideo(file);

      if (!mounted) return;

      // 3 — fetch user profile from Firestore
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final username = (userData['username'] as String?)?.isNotEmpty == true
          ? userData['username'] as String
          : user.displayName ?? user.email?.split('@').first ?? 'User';
      final profileImage = (userData['profileImage'] as String?) ?? '';
      final handle = '@${username.toLowerCase().replaceAll(' ', '_')}';

      // 4 — build caption from title + tags
      final tags = _tagsController.text.trim();
      final caption = tags.isNotEmpty ? '$title\n$tags' : title;

      // 5 — save reel doc to Firestore
      await FirebaseFirestore.instance.collection('reels').add({
        'videoUrl': videoUrl,
        'username': username,
        'handle': handle,
        'caption': caption,
        'description': _descController.text.trim(),
        'likes': 0,
        'comments': 0,
        'saves': 0,
        'views': 0,
        'viewsCount': 0,
        'shares': 0,
        'avatarUrl': profileImage,
        'profileImage': profileImage,
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'isVR': _isVR,
      });

      if (!mounted) return;
      // 6 — navigate to success
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const UploadSuccessScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<String> _uploadVideo(File file) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final db = FirebaseFirestore.instance;

    // 1 — create a request doc; Cloud Function picks it up and writes back uploadUrl + videoId
    final reqRef = await db.collection('cloudflare_upload_requests').add({
      'userId': uid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2 — wait for Cloud Function to write status: 'done' (poll with snapshots, timeout 30s)
    String videoId = '';
    String uploadUrl = '';
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    await for (final snap in reqRef.snapshots()) {
      final data = snap.data();
      if (data == null) continue;
      final status = data['status'] as String? ?? '';
      if (status == 'done') {
        videoId = data['videoId'] as String? ?? '';
        uploadUrl = data['uploadUrl'] as String? ?? '';
        break;
      }
      if (status == 'error') {
        throw Exception(data['error'] ?? 'Cloudflare URL request failed');
      }
      if (DateTime.now().isAfter(deadline)) {
        throw Exception('Timed out waiting for upload URL');
      }
    }

    await reqRef.delete(); // clean up request doc

    // 3 — upload video directly to Cloudflare Stream
    final fileBytes = await file.readAsBytes();
    if (mounted) setState(() => _uploadProgress = 0.1);

    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl))
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: '${DateTime.now().millisecondsSinceEpoch}.mp4',
      ));

    final streamed = await request.send();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('Cloudflare upload failed: ${streamed.statusCode}');
    }
    if (mounted) setState(() => _uploadProgress = 1);

    // 4 — return HLS playback URL
    return ReelsService.streamPlaybackUrl(videoId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: AppGradientBackground(
        type: GradientType.profile,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              Expanded(
                child: _isUploading ? _buildProgress() : _buildForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          ),
          const Expanded(
            child: Text(
              'Post video',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: _isUploading ? null : _post,
            child: const Text(
              'Post',
              style: TextStyle(color: _pink, fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_upload_rounded, color: _pink, size: 56),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Uploading your video…',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _uploadProgress > 0 ? _uploadProgress : null,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                color: _pink,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _uploadProgress > 0
                  ? '${(_uploadProgress * 100).toInt()}%'
                  : 'Preparing…',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          _buildField(
            controller: _titleController,
            label: 'Title',
            hint: 'Add a title…',
            maxLines: 1,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildField(
            controller: _descController,
            label: 'Description',
            hint: 'Describe your video…',
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildField(
            controller: _tagsController,
            label: 'Hashtags',
            hint: '#viral #trending #vyooo',
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildToggle(
            label: 'VR Content',
            subtitle: 'Show in VR tab (360° or spatial video)',
            value: _isVR,
            onChanged: (v) => setState(() => _isVR = v),
          ),
          const SizedBox(height: AppSpacing.xl),
          _buildPostButton(),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required int maxLines,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 15),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: const BorderSide(color: _pink),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildToggle({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: SwitchListTile(
        title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13),
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: _pink,
        activeTrackColor: _pink.withValues(alpha: 0.5),
        inactiveThumbColor: Colors.white54,
        inactiveTrackColor: Colors.white24,
      ),
    );
  }

  Widget _buildPostButton() {
    return Material(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: _post,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFDE106B), Color(0xFFF81945)],
            ),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Post Video',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}
