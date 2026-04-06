import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart';

import '../../core/services/reels_service.dart';
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFDE106B), Color(0xFF1E0A1E)],
            stops: [0.0, 0.6],
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: _isUploading ? null : () => Navigator.of(context).pop(),
            child: const Row(
              children: [
                Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Add details',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _isUploading ? null : _post,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: _pink,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Upload',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_upload_rounded, color: _pink, size: 56),
            const SizedBox(height: 24),
            const Text(
              'Uploading your video…',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _uploadProgress > 0 ? _uploadProgress : null,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                color: _pink,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _uploadProgress > 0 ? '${(_uploadProgress * 100).toInt()}%' : 'Preparing…',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          _buildThumbnail(),
          const SizedBox(height: 32),
          _buildField(
            controller: _titleController,
            label: 'Title',
            hint: 'Add your Title',
            maxLines: 1,
            maxLength: 120,
          ),
          const SizedBox(height: 24),
          _buildField(
            controller: _descController,
            label: 'Description',
            hint: 'Add a short description',
            maxLines: 2,
            maxLength: 200,
          ),
          const SizedBox(height: 24),
          _buildCategoryPicker(),
          const SizedBox(height: 24),
          _buildTagsPicker(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    return Center(
      child: Container(
        width: 140,
        height: 190,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withValues(alpha: 0.1),
        ),
        clipBehavior: Clip.antiAlias,
        child: FutureBuilder<File?>(
          future: widget.asset.file,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return Image.file(snapshot.data!, fit: BoxFit.cover);
            }
            return const Center(child: CircularProgressIndicator(color: Colors.white24));
          },
        ),
      ),
    );
  }

  Widget _buildCategoryPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Text(
                'Select your category',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
              ),
              const Spacer(),
              Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withValues(alpha: 0.6), size: 20),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'All content must be categorized for better search experience.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildTagsPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tags',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Text(
              '0/6',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagsController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Enter your own tags',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
                    border: InputBorder.none,
                  ),
                ),
              ),
              Text(
                'Add',
                style: TextStyle(color: _pink.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Tags are visible by others and are used to make you discoverable on vyoo.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required int maxLines,
    required int maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Text(
              '0/$maxLength',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _pink),
            ),
          ),
        ),
      ],
    );
  }
}
