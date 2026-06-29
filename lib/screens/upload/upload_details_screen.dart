import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/post_location_model.dart';
import '../../core/models/video_360_metadata.dart';
import '../../core/services/user_service.dart';
import '../../core/utils/video_360_detector.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/services/hashtag_generation_service.dart';
import '../../core/services/reels_service.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/upload_tag_suggestions.dart';
import 'location_picker_sheet.dart';
import 'upload_success_screen.dart';

/// Upload Details screen: title, description, tags, 360 video options.
/// Gets a direct upload URL from Cloud Function → uploads to Cloudflare Stream
/// → saves reel doc to Firestore with Stream playback URL.
///
/// When [additionalAssets] is non-empty the post is an Instagram-style
/// carousel: every asset is uploaded and stored in `mediaItems[]`, while the
/// flat media fields keep mirroring the first item for backward compatibility.
class UploadDetailsScreen extends StatefulWidget {
  const UploadDetailsScreen({
    super.key,
    required this.asset,
    this.additionalAssets = const <AssetEntity>[],
    this.photoFileOverride,
    this.videoFileOverride,
  });

  final AssetEntity asset;

  /// Carousel items after [asset] (selection order preserved).
  final List<AssetEntity> additionalAssets;

  /// When set for an **image** post, this file is uploaded instead of [asset.file]
  /// (e.g. after crop on [UploadPhotoPreviewScreen]).
  final File? photoFileOverride;

  /// When set for a **video** post, this file is uploaded instead of [asset.file]
  /// (e.g. after FFmpeg trim on [EditVideoScreen]).
  final File? videoFileOverride;

  @override
  State<UploadDetailsScreen> createState() => _UploadDetailsScreenState();
}

class _UploadDetailsScreenState extends State<UploadDetailsScreen> {
  static const int _maxTags = 30;
  static const List<String> _categories = <String>[
    'Entertainment',
    'Education',
    'Travel',
    'Sports',
    'Music',
    'Comedy',
    'Fashion',
    'Food',
    'Technology',
    'Other',
  ];

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _tagsController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _is360Video = false;
  Video360Projection _projectionType = Video360Projection.equirectangular;
  Video360StereoMode _stereoMode = Video360StereoMode.mono;
  bool _isDetecting360 = false;
  Video360DetectionResult? _detectionResult;
  bool _isUploading = false;
  double _uploadProgress = 0;
  int _uploadingItemIndex = 0;
  String? _selectedCategory;
  final List<String> _selectedTags = <String>[];
  List<String> _suggestedTags = <String>[];
  File? _customThumbnailFile;
  bool _aiGenerating = false;
  PostLocation? _selectedLocation;
  late final PageController _previewPageController;
  int _previewPageIndex = 0;

  bool get _isVideoAsset => widget.asset.type == AssetType.video;

  List<AssetEntity> get _allAssets => [widget.asset, ...widget.additionalAssets];

  static bool _isVideoEntity(AssetEntity asset) =>
      asset.type == AssetType.video;

  static String _streamThumbnailFromVideoUrl(String videoUrl) {
    try {
      final uri = Uri.parse(videoUrl);
      final videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      if (videoId.isEmpty) return '';
      return 'https://videodelivery.net/$videoId/thumbnails/thumbnail.jpg';
    } catch (_) {
      return '';
    }
  }

  bool get _canConfigure360 => _isVideoAsset && _allAssets.length == 1;

  @override
  void initState() {
    super.initState();
    _previewPageController = PageController();
    _titleController.addListener(_refreshSuggestedTags);
    _descController.addListener(_refreshSuggestedTags);
    _suggestedTags = UploadTagSuggestions.build(
      title: _titleController.text,
      description: _descController.text,
      category: _selectedCategory,
    );
    if (_canConfigure360) {
      _run360Detection();
    }
  }

  Future<void> _run360Detection() async {
    setState(() => _isDetecting360 = true);
    try {
      final file = widget.videoFileOverride ?? await widget.asset.file;
      if (file == null || !mounted) return;
      final result = await Video360Detector.detect(file);
      if (!mounted) return;
      setState(() {
        _isDetecting360 = false;
        _detectionResult = result;
        final suggested = result.suggested;
        if (suggested != null &&
            suggested.is360Video &&
            result.confidence != Video360DetectionConfidence.none) {
          _is360Video = true;
          _projectionType = suggested.projectionType;
          _stereoMode = suggested.stereoMode;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isDetecting360 = false);
    }
  }

  void _refreshSuggestedTags() {
    if (_aiGenerating) return;
    final next = UploadTagSuggestions.build(
      title: _titleController.text,
      description: _descController.text,
      category: _selectedCategory,
    );
    if (!_listEq(_suggestedTags, next)) {
      setState(() => _suggestedTags = next);
    }
  }

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _titleController.removeListener(_refreshSuggestedTags);
    _descController.removeListener(_refreshSuggestedTags);
    _titleController.dispose();
    _descController.dispose();
    _tagsController.dispose();
    _previewPageController.dispose();
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
      // 1+2 — resolve and upload every selected asset, in carousel order.
      // Photo/video edit overrides only ever exist for the single-asset flow,
      // so they apply to the first item only.
      final assets = _allAssets;
      final mediaItems = <Map<String, dynamic>>[];
      for (var i = 0; i < assets.length; i++) {
        if (!mounted) return;
        setState(() {
          _uploadingItemIndex = i;
          _uploadProgress = 0;
        });
        final asset = assets[i];
        final isVideo = _isVideoEntity(asset);
        final File? file = i == 0
            ? (isVideo
                  ? (widget.videoFileOverride ?? await asset.file)
                  : (widget.photoFileOverride ?? await asset.file))
            : await asset.file;
        if (file == null) {
          throw Exception('Could not read selected media (item ${i + 1}).');
        }
        final url = isVideo ? await _uploadVideo(file) : await _uploadPhoto(file);
        mediaItems.add({
          'type': isVideo ? 'video' : 'image',
          'url': url,
          'thumbnailUrl': isVideo ? _streamThumbnailFromVideoUrl(url) : url,
        });
      }
      final first = mediaItems.first;
      final firstIsVideo = first['type'] == 'video';
      final mediaUrl = first['url'] as String;

      if (!mounted) return;

      // 3 — fetch user profile from Firestore
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final username = (userData['username'] as String?)?.isNotEmpty == true
          ? userData['username'] as String
          : user.displayName ?? user.email?.split('@').first ?? 'User';
      final profileImage = (userData['profileImage'] as String?) ?? '';
      final handle = '@${username.replaceAll(' ', '_')}';
      final accountType = (userData['accountType'] as String?) ?? 'private';
      final authorAccountPrivate =
          UserService.accountTypeRequiresFollowApproval(accountType);

      // 4 — build caption from title + tags
      final tags = _tagsController.text.trim();
      if (tags.isNotEmpty) {
        _addTag(tags, clearInput: true);
      }
      final tagsLine = _selectedTags.isEmpty ? '' : _selectedTags.map((t) => '#$t').join(' ');
      final caption = tagsLine.isNotEmpty ? '$title\n$tagsLine' : title;

      var thumbnailUrl = firstIsVideo ? '' : mediaUrl;
      if (firstIsVideo && _customThumbnailFile != null) {
        thumbnailUrl = await _uploadCustomThumbnail(_customThumbnailFile!);
        mediaItems[0] = {...first, 'thumbnailUrl': thumbnailUrl};
      }

      final video360Meta = Video360Metadata.sanitize(
        is360Video: _canConfigure360 && _is360Video,
        projectionType: _projectionType.firestoreValue,
        stereoMode: _stereoMode.firestoreValue,
      );

      // 5 — save reel doc to Firestore. Flat media fields mirror the first
      // carousel item so older clients and existing queries keep working.
      final reelRef = await FirebaseFirestore.instance.collection('reels').add({
        'mediaType': firstIsVideo ? 'video' : 'image',
        'videoUrl': firstIsVideo ? mediaUrl : '',
        'imageUrl': firstIsVideo ? '' : mediaUrl,
        'thumbnailUrl': thumbnailUrl,
        'mediaItems': mediaItems,
        'mediaCount': mediaItems.length,
        'username': username,
        'handle': handle,
        'caption': caption,
        'description': _descController.text.trim(),
        'title': title,
        'category': _selectedCategory ?? '',
        'tags': _selectedTags,
        'likes': 0,
        'comments': 0,
        'saves': 0,
        'views': 0,
        'viewsCount': 0,
        'shares': 0,
        'reposts': 0,
        'avatarUrl': profileImage,
        'profileImage': profileImage,
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'authorAccountPrivate': authorAccountPrivate,
        ...video360Meta.toFirestore(),
        'isVR': video360Meta.is360Video,
        if (_selectedLocation != null)
          'location': _selectedLocation!.toMap(),
        'moderation': {
          'provider': 'hive',
          'status': 'pending',
          'score': 0.0,
          'reasons': <String>[],
        },
      });
      if (kDebugMode) {
        debugPrint(
          'Reel saved: id=${reelRef.id}, project=${FirebaseFirestore.instance.app.options.projectId}',
        );
      }

      if (!mounted) return;
      // 6 — navigate to success
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => UploadSuccessScreen.forMediaPost(
            mediaItems: mediaItems,
          ),
        ),
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

    // 3 — upload video directly to Cloudflare Stream (stream from disk; no size cap in app)
    if (mounted) setState(() => _uploadProgress = 0.1);

    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl))
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
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

  Future<String> _uploadPhoto(File file) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ext = _extFromPath(file.path);
    final ref = FirebaseStorage.instance.ref().child(
      'users/$uid/uploads/photos/${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    if (mounted) setState(() => _uploadProgress = 1);
    return ref.getDownloadURL();
  }

  Future<String> _uploadCustomThumbnail(File file) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ext = _extFromPath(file.path);
    final ref = FirebaseStorage.instance.ref().child(
      'users/$uid/uploads/thumbnails/${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  String _extFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.heic')) return 'heic';
    if (lower.endsWith('.heif')) return 'heif';
    return 'jpg';
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.lightEdgeToEdgeOverlay,
        child: Scaffold(
          backgroundColor: AppColors.chatBackground,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
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
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + AppSpacing.xs,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.chatTextPrimary,
              size: 20,
            ),
          ),
          Text(
            'Add details',
            style: AppTypography.chatTileName.copyWith(
              color: AppColors.chatTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _isUploading ? null : _post,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.authBrandBurgundy,
                borderRadius: AppRadius.pillRadius,
              ),
              child: Text(
                'Upload',
                style: AppTypography.chatTileName.copyWith(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
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
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_upload_rounded,
              color: AppColors.brandDeepMagenta,
              size: 56,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              _allAssets.length > 1
                  ? 'Uploading ${_uploadingItemIndex + 1} of ${_allAssets.length}…'
                  : (_isVideoAsset
                        ? 'Uploading your video…'
                        : 'Uploading your photo…'),
              style: AppTypography.chatTileName.copyWith(
                color: AppColors.chatTextPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.xs),
              child: LinearProgressIndicator(
                value: _uploadProgress > 0 ? _uploadProgress : null,
                backgroundColor: AppColors.chatSearchFill,
                color: AppColors.brandDeepMagenta,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _uploadProgress > 0 ? '${(_uploadProgress * 100).toInt()}%' : 'Preparing…',
              style: AppTypography.chatTilePreview,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md + AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md + AppSpacing.xs),
          _buildThumbnail(),
          const SizedBox(height: AppSpacing.xxl),
          _buildField(
            controller: _titleController,
            label: 'Title',
            hint: 'Add your Title',
            maxLines: 1,
            maxLength: 120,
          ),
          const SizedBox(height: AppSpacing.xl),
          _buildField(
            controller: _descController,
            label: 'Description',
            hint: 'Add a short description',
            maxLines: 2,
            maxLength: 200,
          ),
          const SizedBox(height: AppSpacing.xl),
          _buildCategoryPicker(),
          const SizedBox(height: AppSpacing.xl),
          _buildLocationPicker(),
          const SizedBox(height: AppSpacing.xl),
          if (_canConfigure360) ...[
            _build360VideoSection(),
            const SizedBox(height: AppSpacing.xl),
          ],
          _buildSuggestedTagsSection(),
          const SizedBox(height: AppSpacing.xl),
          _buildTagsPicker(),
          const SizedBox(height: AppSpacing.xl + AppSpacing.sm),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    if (_allAssets.length > 1) {
      return _buildCarouselPreview();
    }
    return Center(
      child: GestureDetector(
        onTap: _isUploading || !_isVideoAsset ? null : _pickCustomThumbnail,
        child: Container(
          width: 160,
          height: 220,
          decoration: BoxDecoration(
            borderRadius: AppRadius.buttonRadius,
            color: AppColors.chatSearchFill,
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildAssetPreview(_allAssets.first, index: 0),
        ),
      ),
    );
  }

  Widget _buildCarouselPreview() {
    final total = _allAssets.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _previewPageController,
            itemCount: total,
            onPageChanged: (index) => setState(() => _previewPageIndex = index),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ClipRRect(
                  borderRadius: AppRadius.buttonRadius,
                  child: ColoredBox(
                    color: AppColors.chatSearchFill,
                    child: _buildAssetPreview(_allAssets[index], index: index),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < total; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _previewPageIndex ? 8 : 6,
                height: i == _previewPageIndex ? 8 : 6,
                decoration: BoxDecoration(
                  color: i == _previewPageIndex
                      ? AppColors.brandDeepMagenta
                      : AppColors.chatTextSecondary.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
            Text(
              '${_previewPageIndex + 1}/$total',
              style: AppTypography.chatTilePreview.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Swipe to preview all selected media',
          style: AppTypography.chatTilePreview.copyWith(fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildAssetPreview(AssetEntity asset, {required int index}) {
    final isVideo = _isVideoEntity(asset);
    if (index == 0 && _customThumbnailFile != null) {
      return Image.file(_customThumbnailFile!, fit: BoxFit.cover);
    }
    if (index == 0 && !isVideo && widget.photoFileOverride != null) {
      return Image.file(widget.photoFileOverride!, fit: BoxFit.cover);
    }
    if (index == 0 && isVideo && widget.videoFileOverride != null) {
      return FutureBuilder<Uint8List?>(
        future: asset.thumbnailDataWithSize(const ThumbnailSize(500, 800)),
        builder: (context, thumbSnap) {
          final bytes = thumbSnap.data;
          if (bytes != null && bytes.isNotEmpty) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(bytes, fit: BoxFit.cover),
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white70,
                    size: 44,
                  ),
                ),
              ],
            );
          }
          return Container(
            color: Colors.black.withValues(alpha: 0.35),
            child: const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white70,
                size: 44,
              ),
            ),
          );
        },
      );
    }
    if (isVideo) {
      return FutureBuilder<Uint8List?>(
        future: asset.thumbnailDataWithSize(const ThumbnailSize(500, 800)),
        builder: (context, thumbSnap) {
          final bytes = thumbSnap.data;
          if (bytes != null && bytes.isNotEmpty) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(bytes, fit: BoxFit.cover),
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white70,
                    size: 44,
                  ),
                ),
              ],
            );
          }
          return Container(
            color: Colors.black.withValues(alpha: 0.35),
            child: const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white70,
                size: 44,
              ),
            ),
          );
        },
      );
    }
    return FutureBuilder<File?>(
      future: asset.file,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.file(snapshot.data!, fit: BoxFit.cover);
        }
        return const Center(
          child: CircularProgressIndicator(color: AppColors.brandDeepMagenta),
        );
      },
    );
  }

  Future<void> _pickCustomThumbnail() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1280,
    );
    if (!mounted || file == null) return;
    setState(() => _customThumbnailFile = File(file.path));
  }

  Future<void> _showCategoryPickerSheet() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.chatBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.input)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: _categories
              .map(
                (category) => ListTile(
                  title: Text(
                    category,
                    style: AppTypography.chatTileName.copyWith(
                      color: AppColors.chatTextPrimary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  trailing: _selectedCategory == category
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.brandDeepMagenta,
                        )
                      : null,
                  onTap: () => Navigator.of(ctx).pop(category),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedCategory = picked);
    _refreshSuggestedTags();
  }

  void _addTag(String rawTag, {bool clearInput = false}) {
    final normalized = rawTag
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_ ]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    if (normalized.isEmpty) return;
    if (_selectedTags.contains(normalized)) return;
    if (_selectedTags.length >= _maxTags) return;
    setState(() => _selectedTags.add(normalized));
    if (clearInput) _tagsController.clear();
  }

  void _removeTag(String tag) {
    setState(() => _selectedTags.remove(tag));
  }

  void _toggleSuggestedTag(String tag) {
    if (_selectedTags.contains(tag)) {
      _removeTag(tag);
      return;
    }
    _addTag(tag, clearInput: false);
  }

  Future<void> _generateAiHashtags() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a title first, then run AI hashtags.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _aiGenerating = true);
    try {
      final tags = await HashtagGenerationService.generate(
        title: title,
        description: _descController.text,
        category: _selectedCategory,
      );
      if (!mounted) return;
      setState(() => _suggestedTags = tags);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tags.length} AI hashtag ideas ready. Tap to add.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e, st) {
      debugPrint('[UploadDetails] AI hashtags failed: $e');
      debugPrint('$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI hashtags: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _aiGenerating = false);
    }
  }

  Widget _buildTagChips() {
    if (_selectedTags.isEmpty) {
      return Text(
        'No tags added yet.',
        style: AppTypography.chatTilePreview.copyWith(fontSize: 11),
      );
    }
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: _selectedTags
          .map(
            (tag) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + AppSpacing.xs,
                vertical: AppSpacing.sm - AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.chatSearchFill,
                borderRadius: AppRadius.pillRadius,
                border: Border.all(color: AppColors.chatDivider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tag,
                    style: AppTypography.chatTileName.copyWith(
                      color: AppColors.chatTextPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm - AppSpacing.xs),
                  GestureDetector(
                    onTap: () => _removeTag(tag),
                    child: const Icon(
                      Icons.close,
                      color: AppColors.chatTextSecondary,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCategoryPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: AppTypography.chatTileName.copyWith(
            color: AppColors.chatTextPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        GestureDetector(
          onTap: _showCategoryPickerSheet,
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedCategory ?? 'Select your category',
                      style: AppTypography.chatTileName.copyWith(
                        color: _selectedCategory == null
                            ? AppColors.chatTextSecondary
                            : AppColors.chatTextPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.chatAppBarActionIcon,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1, color: AppColors.chatDivider),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'All content must be categorized for better search experience.',
          style: AppTypography.chatTilePreview.copyWith(fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildLocationPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location',
          style: AppTypography.chatTileName.copyWith(
            color: AppColors.chatTextPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        GestureDetector(
          onTap: _isUploading
              ? null
              : () async {
                  final result = await showLocationPickerSheet(context);
                  if (!mounted || result == null) return;
                  setState(() => _selectedLocation = result);
                },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.chatSearchFill,
              borderRadius: AppRadius.inputRadius,
              border: Border.all(color: AppColors.chatDivider),
            ),
            child: _selectedLocation == null
                ? Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.chatTextSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                      Text(
                        'Add location',
                        style: AppTypography.chatTileName.copyWith(
                          color: AppColors.chatTextSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.keyboard_arrow_right_rounded,
                        color: AppColors.chatAppBarActionIcon,
                        size: 22,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: AppColors.brandDeepMagenta,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedLocation!.name,
                              style: AppTypography.chatTileName.copyWith(
                                color: AppColors.chatTextPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_selectedLocation!.address != null &&
                                _selectedLocation!.address!.isNotEmpty)
                              Text(
                                _selectedLocation!.address!,
                                style: AppTypography.chatTilePreview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      GestureDetector(
                        onTap: () => setState(() => _selectedLocation = null),
                        child: const Icon(
                          Icons.close,
                          color: AppColors.chatTextSecondary,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _build360VideoSection() {
    final detection = _detectionResult;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '360 video',
                style: AppTypography.chatTileName.copyWith(
                  color: AppColors.chatTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_isDetecting360)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.brandDeepMagenta,
                ),
              )
            else
              Switch.adaptive(
                value: _is360Video,
                activeTrackColor: AppColors.brandDeepMagenta.withValues(alpha: 0.55),
                thumbColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppColors.brandDeepMagenta
                      : AppColors.chatTextSecondary,
                ),
                onChanged: _isUploading
                    ? null
                    : (value) => setState(() => _is360Video = value),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm - AppSpacing.xs),
        Text(
          'Look around by dragging or moving your phone. All videos stay in the gallery — this only changes how the post plays.',
          style: AppTypography.chatTilePreview.copyWith(
            fontSize: 12,
            height: 1.35,
          ),
        ),
        if (detection?.message != null && detection!.message!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + AppSpacing.xs,
              vertical: AppSpacing.sm + AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.chatSearchFill,
              borderRadius: AppRadius.inputRadius,
              border: Border.all(color: AppColors.chatDivider),
            ),
            child: Text(
              detection.message!,
              style: AppTypography.chatTilePreview.copyWith(fontSize: 12),
            ),
          ),
        ],
        if (_is360Video) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Projection',
            style: AppTypography.chatTilePreview.copyWith(fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildChoiceChipRow(
            options: const [
              ('Equirectangular', Video360Projection.equirectangular),
            ],
            selected: _projectionType,
            onSelected: (value) =>
                setState(() => _projectionType = value as Video360Projection),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Stereo layout',
            style: AppTypography.chatTilePreview.copyWith(fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildChoiceChipRow(
            options: const [
              ('Mono', Video360StereoMode.mono),
              ('Top-Bottom 3D', Video360StereoMode.topBottom),
              ('Side-by-Side 3D', Video360StereoMode.sideBySide),
            ],
            selected: _stereoMode,
            onSelected: (value) =>
                setState(() => _stereoMode = value as Video360StereoMode),
          ),
        ],
      ],
    );
  }

  Widget _buildChoiceChipRow({
    required List<(String, Object)> options,
    required Object selected,
    required ValueChanged<Object> onSelected,
  }) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final (label, value) in options)
          ChoiceChip(
            label: Text(label),
            selected: selected == value,
            onSelected: _isUploading
                ? null
                : (_) => onSelected(value),
            selectedColor: AppColors.brandDeepMagenta.withValues(alpha: 0.15),
            backgroundColor: AppColors.chatSearchFill,
            labelStyle: AppTypography.chatTileName.copyWith(
              color: selected == value
                  ? AppColors.authBrandBurgundy
                  : AppColors.chatTextSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            side: BorderSide(
              color: selected == value
                  ? AppColors.brandDeepMagenta
                  : AppColors.chatDivider,
            ),
          ),
      ],
    );
  }

  Widget _buildSuggestedTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Suggested tags',
                        style: AppTypography.chatTileName.copyWith(
                          color: AppColors.chatTextPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${_suggestedTags.length} ideas',
                        style: AppTypography.chatTilePreview,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Local suggestions update as you type. AI 30+ asks the server for at least ${HashtagGenerationService.minHashtagCount} tags (Gemini or OpenAI, configured in Cloud Functions).',
                    style: AppTypography.chatTilePreview.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: (_aiGenerating || _isUploading) ? null : _generateAiHashtags,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brandDeepMagenta,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: _aiGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brandDeepMagenta,
                      ),
                    )
                  : Text(
                      'AI 30+',
                      style: AppTypography.chatTileName.copyWith(
                        color: AppColors.brandDeepMagenta,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Tap a chip to add or remove.',
          style: AppTypography.chatTilePreview.copyWith(fontSize: 11),
        ),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: _suggestedTags
              .map(
                (tag) {
                  final selected = _selectedTags.contains(tag);
                  return GestureDetector(
                    onTap: () => _toggleSuggestedTag(tag),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm + AppSpacing.xs,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.brandDeepMagenta.withValues(alpha: 0.12)
                            : AppColors.chatSearchFill,
                        borderRadius: AppRadius.pillRadius,
                        border: Border.all(
                          color: selected
                              ? AppColors.brandDeepMagenta
                              : AppColors.chatDivider,
                          width: selected ? 1.2 : 1,
                        ),
                      ),
                      child: Text(
                        tag,
                        style: AppTypography.chatTileName.copyWith(
                          color: selected
                              ? AppColors.authBrandBurgundy
                              : AppColors.chatTextPrimary,
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                },
              )
              .toList(),
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
            Text(
              'Tags',
              style: AppTypography.chatTileName.copyWith(
                color: AppColors.chatTextPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${_selectedTags.length}/$_maxTags',
              style: AppTypography.chatTilePreview,
            ),
          ],
        ),
        if (_selectedTags.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          _buildTagChips(),
        ],
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        TextField(
          controller: _tagsController,
          onSubmitted: (v) => _addTag(v, clearInput: true),
          keyboardAppearance: Brightness.light,
          cursorColor: AppColors.authBrandBurgundy,
          style: AppTypography.chatTileName.copyWith(
            color: AppColors.chatTextPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            hintText: 'Enter your own tags',
            hintStyle: AppTypography.chatTilePreview.copyWith(fontSize: 13),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.chatDivider),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.authBrandBurgundy),
            ),
            suffixIcon: TextButton(
              onPressed: () => _addTag(_tagsController.text, clearInput: true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brandDeepMagenta,
              ),
              child: Text(
                'Add',
                style: AppTypography.chatTileName.copyWith(
                  color: AppColors.brandDeepMagenta,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        Text(
          'Tags are visible by others and are used to make you discoverable on vyoo.',
          style: AppTypography.chatTilePreview.copyWith(fontSize: 11),
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
              style: AppTypography.chatTileName.copyWith(
                color: AppColors.chatTextPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${controller.text.length}/$maxLength',
              style: AppTypography.chatTilePreview.copyWith(fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          onChanged: (_) => setState(() {}),
          keyboardAppearance: Brightness.light,
          cursorColor: AppColors.authBrandBurgundy,
          style: AppTypography.chatTileName.copyWith(
            color: AppColors.chatTextPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: hint,
            hintStyle: AppTypography.chatTilePreview.copyWith(fontSize: 13),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.chatDivider),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.authBrandBurgundy),
            ),
          ),
        ),
      ],
    );
  }
}
