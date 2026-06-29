import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'all_albums_screen.dart';
import 'photo_gallery_permission.dart';
import '../../features/story/story_upload_screen.dart';
import 'creator_live_route.dart';
import 'upload_details_screen.dart';
import 'upload_photo_preview_screen.dart';
import 'upload_video_preview_screen.dart';
import 'widgets/upload_create_bottom_bar.dart';

/// Upload screen for subscribers: media grid from gallery, album dropdown, Story / Post / Live actions.
/// Opened from bottom nav plus; standard users are redirected to membership instead.
///
/// Defaults to **Post** so the gallery (or permission flow) starts immediately — no extra tap
/// through instructional copy. Story / Live use the bottom actions only.
class UploadScreen extends StatefulWidget {
  const UploadScreen({
    super.key,
    this.initialBottomSegment = 1,
  });

  /// `0` Story, `1` Post (gallery), `2` Live — used when opening from Story/Live hub bar.
  final int initialBottomSegment;

  /// Opens the Post (gallery) hub without pulling [StoryUploadScreen] into this library’s import graph.
  static void openPostHub(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const UploadScreen(initialBottomSegment: 1),
      ),
    );
  }

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> with WidgetsBindingObserver {
  /// Instagram-style carousel cap.
  static const int _maxCarouselItems = 10;

  String _selectedAlbum = 'Recents';

  /// Selection order matters: first picked = first carousel item = post cover.
  final List<AssetEntity> _selectedAssets = [];

  /// 0 Story (opens separate screen from bar), 1 Post (gallery), 2 Live.
  late int _bottomSegment;

  List<AssetPathEntity> _paths = [];
  List<AssetEntity> _assets = [];
  /// Start true: first frame is spinner until [_loadGallery] resolves (avoids a flash of
  /// "No photos or videos" before the first fetch).
  bool _loading = true;
  String? _permissionError;

  /// When user picks an album from All Albums screen.
  AssetPathEntity? _pathOverride;

  /// Ignores stale [setState] when [_loadGallery] is invoked concurrently.
  int _galleryLoadGeneration = 0;

  AssetPathEntity? get _currentPath {
    if (_pathOverride != null) return _pathOverride;
    if (_paths.isEmpty) return null;
    switch (_selectedAlbum) {
      case 'Favourites':
        final list = _paths
            .where((p) => p.name.toLowerCase().contains('favor'))
            .toList();
        return list.isNotEmpty ? list.first : _paths.first;
      case 'All Albums':
        return _paths.first; // fallback "All" / root
      case 'Recents':
      default:
        final list = _paths.where((p) {
          final n = p.name.toLowerCase();
          return n.contains('recent') || n == 'recents';
        }).toList();
        return list.isNotEmpty
            ? list.first
            : (_paths.length > 1 ? _paths[1] : _paths.first);
    }
  }

  bool _isVideoAsset(AssetEntity entity) {
    return entity.type == AssetType.video || entity.videoDuration.inSeconds > 0;
  }

  @override
  void initState() {
    super.initState();
    _bottomSegment = widget.initialBottomSegment.clamp(0, 2);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_bottomSegment == 1) _loadGallery();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        _bottomSegment == 1 &&
        _permissionError != null) {
      _loadGallery();
    }
  }

  Future<void> _loadGallery() async {
    if (_bottomSegment != 1) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final gen = ++_galleryLoadGeneration;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _permissionError = null;
    });
    try {
      final perm = await requestGalleryReadAccess();
      if (!mounted || gen != _galleryLoadGeneration) return;
      if (!perm.hasAccess) {
        setState(() {
          _loading = false;
          _permissionError =
              'Media library access is needed to choose photos or videos.';
        });
        return;
      }
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: true,
      );
      if (!mounted || gen != _galleryLoadGeneration) return;
      setState(() {
        _paths = paths;
        _loading = false;
      });
      await _loadAssetsForCurrentPath();
    } catch (e) {
      if (mounted && gen == _galleryLoadGeneration) {
        setState(() {
          _loading = false;
          _permissionError = e.toString();
        });
      }
    }
  }

  /// Capture a photo or video with the device camera, save it to the gallery
  /// and continue with the regular post preview flow.
  Future<void> _openCamera() async {
    final isVideo = await _showCameraModePicker();
    if (isVideo == null || !mounted) return;

    final picker = ImagePicker();
    XFile? captured;
    try {
      captured = isVideo
          ? await picker.pickVideo(
              source: ImageSource.camera,
              maxDuration: const Duration(minutes: 10),
            )
          : await picker.pickImage(source: ImageSource.camera);
    } catch (e) {
      if (mounted) {
        _showSnack('Could not open camera. Check camera permission in Settings.');
      }
      return;
    }
    if (captured == null || !mounted) return;

    // Save the capture into the gallery so the existing AssetEntity-based
    // preview/upload pipeline (crop, trim, details) can be reused.
    AssetEntity? entity;
    try {
      final title = 'vyooo_${DateTime.now().millisecondsSinceEpoch}';
      entity = isVideo
          ? await PhotoManager.editor.saveVideo(File(captured.path), title: title)
          : await PhotoManager.editor.saveImageWithPath(captured.path, title: title);
    } catch (e) {
      debugPrint('UploadScreen: camera capture save failed: $e');
    }
    if (!mounted) return;
    if (entity == null) {
      _showSnack('Could not save the capture. Allow photo library access and try again.');
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => isVideo
            ? UploadVideoPreviewScreen(asset: entity!)
            : UploadPhotoPreviewScreen(asset: entity!),
      ),
    );
    if (!mounted) return;
    // Refresh the grid so the new capture shows up.
    await _loadGallery();
  }

  Future<bool?> _showCameraModePicker() {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF1E0A1E).withValues(alpha: 0.98),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: Colors.white),
              title: const Text(
                'Take Photo',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              onTap: () => Navigator.of(ctx).pop(false),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined, color: Colors.white),
              title: const Text(
                'Record Video',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              onTap: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _loadAssetsForCurrentPath() async {
    final path = _currentPath ?? (_paths.isNotEmpty ? _paths.first : null);
    if (path == null) return;
    setState(() => _loading = true);
    try {
      final list = await path.getAssetListPaged(page: 0, size: 200);
      final media = list
          .where((e) => e.type == AssetType.video || e.type == AssetType.image)
          .toList();
      if (!mounted) return;
      setState(() {
        _assets = media;
        _loading = false;
        _selectedAssets.clear();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _assets = [];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.chatBackground,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: _buildHeader(context),
          ),
          Expanded(child: _buildBody()),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isPost = _bottomSegment == 1;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 44, height: 44),
                    icon: Image.asset(
                      'assets/vyooO_icons/Search/close.png',
                      width: 24,
                      height: 24,
                      color: AppColors.chatAppBarActionIcon,
                    ),
                  ),
                  if (isPost)
                    _AlbumDropdown(
                      value: _selectedAlbum,
                      paths: _paths,
                      onChanged: (v) async {
                        if (v == null) return;
                        if (v == 'All Albums') {
                          if (_paths.isEmpty) return;
                          final path = await Navigator.of(context)
                              .push<AssetPathEntity>(
                            MaterialPageRoute<AssetPathEntity>(
                              builder: (_) => AllAlbumsScreen(paths: _paths),
                            ),
                          );
                          if (!mounted) return;
                          if (path != null) {
                            setState(() {
                              _pathOverride = path;
                              _selectedAlbum = path.name;
                            });
                            await _loadAssetsForCurrentPath();
                          }
                          return;
                        }
                        setState(() {
                          _pathOverride = null;
                          _selectedAlbum = v;
                        });
                        await _loadAssetsForCurrentPath();
                      },
                    )
                  else
                    Text(
                      _bottomSegment == 2 ? 'Live' : 'Story',
                      style: AppTypography.chatTileName.copyWith(
                        color: AppColors.chatTextPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: isPost
                  ? TextButton(
                      onPressed: _onNextTap,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.brandDeepMagenta,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.sm,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Next',
                        style: AppTypography.chatTileName.copyWith(
                          color: AppColors.brandDeepMagenta,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : const SizedBox(width: 44, height: 44),
            ),
          ],
        ),
      ),
    );
  }

  void _onNextTap() {
    if (_selectedAssets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select photo or video'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_selectedAssets.length > 1) {
      // Carousel post: skip the single-asset crop/trim editors and go straight
      // to details, where every item is uploaded as part of one post.
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => UploadDetailsScreen(
            asset: _selectedAssets.first,
            additionalAssets: _selectedAssets.sublist(1),
          ),
        ),
      );
      return;
    }
    final selected = _selectedAssets.first;
    if (_isVideoAsset(selected)) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => UploadVideoPreviewScreen(asset: selected),
        ),
      );
    } else if (selected.type == AssetType.image) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => UploadPhotoPreviewScreen(asset: selected),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unsupported media selected.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _toggleAssetSelection(AssetEntity entity) {
    setState(() {
      if (_selectedAssets.contains(entity)) {
        _selectedAssets.remove(entity);
        return;
      }
      if (_selectedAssets.length >= _maxCarouselItems) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You can select up to $_maxCarouselItems items per post.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      _selectedAssets.add(entity);
    });
  }

  Widget _buildBody() {
    if (_bottomSegment != 1) {
      // No "tap below" instructional layer — Story / Live are started from the bottom bar.
      final icon = _bottomSegment == 0
          ? Icons.auto_stories_outlined
          : Icons.live_tv_outlined;
      return Center(
        child: Icon(
          icon,
          size: 56,
          color: AppColors.chatTextSecondary.withValues(alpha: 0.35),
        ),
      );
    }
    if (_permissionError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _permissionError!,
                textAlign: TextAlign.center,
                style: AppTypography.chatTileName.copyWith(
                  color: AppColors.chatTextPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tap Try again to show the system prompt. If nothing changes, '
                'use Open Settings and allow Photos or media access for Vyooo, '
                'then return here.',
                textAlign: TextAlign.center,
                style: AppTypography.chatTilePreview.copyWith(
                  height: 1.35,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.authBrandBurgundy,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.sm + AppSpacing.xs,
                  ),
                ),
                onPressed: openGalleryRelatedAppSettings,
                child: Text(
                  'Open Settings',
                  style: AppTypography.chatTileName.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brandDeepMagenta,
                  minimumSize: const Size(200, 48),
                ),
                onPressed: _loading ? null : _loadGallery,
                child: Text(
                  'Try again',
                  style: AppTypography.chatTileName.copyWith(
                    color: AppColors.brandDeepMagenta,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_loading && _assets.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandDeepMagenta),
      );
    }
    if (_assets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No photos or videos',
              style: AppTypography.chatTileName.copyWith(
                color: AppColors.chatTextSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.authBrandBurgundy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.sm + AppSpacing.xs,
                ),
              ),
              onPressed: _openCamera,
              icon: const Icon(Icons.photo_camera_outlined, size: 20),
              label: Text(
                'Use Camera',
                style: AppTypography.chatTileName.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }
    return _buildGrid();
  }

  Widget _buildGrid() {
    const spacing = 1.0;
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: 1,
      ),
      // First cell opens the device camera; gallery assets follow.
      itemCount: _assets.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _CameraTile(onTap: _openCamera);
        }
        final assetIndex = index - 1;
        final entity = _assets[assetIndex];
        final selectionOrder = _selectedAssets.indexOf(entity);
        final selected = selectionOrder >= 0;
        return GestureDetector(
          onTap: () => _toggleAssetSelection(entity),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _GalleryThumbnail(entity: entity),
              if (selected)
                Container(color: Colors.black.withValues(alpha: 0.25)),
              if (_isVideoAsset(entity)) _VideoDuration(entity: entity),
              if (selected)
                _SelectedBadge(
                  order: _selectedAssets.length > 1 ? selectionOrder + 1 : null,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return UploadCreateBottomBar(
      selectedSegment: _bottomSegment,
      onStoryTap: () {
        setState(() => _bottomSegment = 0);
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const StoryUploadScreen(successDismissToRoot: true),
          ),
        );
      },
      onPostTap: () {
        final wasPost = _bottomSegment == 1;
        setState(() => _bottomSegment = 1);
        if (!wasPost || _permissionError != null) {
          _loadGallery();
        }
      },
      onLiveTap: () {
        setState(() => _bottomSegment = 2);
        openCreatorLiveScreen(context);
      },
    );
  }
}

class _CameraTile extends StatelessWidget {
  const _CameraTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: AppColors.chatSearchFill,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_camera_outlined,
              color: AppColors.chatTextSecondary,
              size: 32,
            ),
            const SizedBox(height: AppSpacing.sm - AppSpacing.xs),
            Text(
              'Camera',
              style: AppTypography.chatTilePreview.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryThumbnail extends StatelessWidget {
  const _GalleryThumbnail({required this.entity});

  final AssetEntity entity;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: entity.thumbnailDataWithSize(const ThumbnailSize.square(400)),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        }
        return Container(
          color: AppColors.chatSearchFill,
          child: Center(
            child: Image.asset(
              'assets/vyooO_icons/Upload_Story_Live/gallery.png',
              width: 40,
              height: 40,
              color: AppColors.chatTextSecondary.withValues(alpha: 0.5),
            ),
          ),
        );
      },
    );
  }
}

class _VideoDuration extends StatelessWidget {
  const _VideoDuration({required this.entity});

  final AssetEntity entity;

  @override
  Widget build(BuildContext context) {
    final d = entity.videoDuration;
    final sec = d.inSeconds;
    if (sec <= 0) return const SizedBox.shrink();
    final m = sec ~/ 60;
    final s = sec % 60;
    final h = m ~/ 60;
    final mm = m % 60;
    final str = h > 0
        ? '$h:${mm.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '$mm:${s.toString().padLeft(2, '0')}';
    return Positioned(
      right: 6,
      bottom: 6,
      child: Text(
        str,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
        ),
      ),
    );
  }
}

class _SelectedBadge extends StatelessWidget {
  const _SelectedBadge({this.order});

  /// 1-based carousel position; null shows a plain checkmark (single select).
  final int? order;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.chatVerified,
          shape: BoxShape.circle,
        ),
        child: order != null
            ? Text(
                '$order',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              )
            : const Icon(Icons.check, size: 16, color: Colors.white),
      ),
    );
  }
}

class _AlbumDropdown extends StatelessWidget {
  const _AlbumDropdown({
    required this.value,
    required this.paths,
    required this.onChanged,
  });

  final String value;
  final List<AssetPathEntity> paths;
  final void Function(String?) onChanged;

  static const Color _menuFill = Color(0xD93A3A3C);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.white24,
        highlightColor: Colors.white12,
      ),
      child: PopupMenuButton<String>(
        offset: const Offset(0, 44),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        color: _menuFill,
        elevation: 8,
        shadowColor: Colors.black26,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.inputRadius),
        tooltip: '',
        itemBuilder: (context) => [
          _buildPopupItem('Recents', Icons.photo_library_outlined),
          _buildPopupItem('Favourites', Icons.favorite_border_rounded),
          _buildPopupItem('All Albums', Icons.grid_view_outlined),
        ],
        onSelected: onChanged,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: AppTypography.chatTileName.copyWith(
                color: AppColors.chatTextPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.chatAppBarActionIcon,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(String label, IconData icon) {
    return PopupMenuItem<String>(
      value: label,
      height: 48,
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.95)),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
          Text(
            label,
            style: AppTypography.chatTileName.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

