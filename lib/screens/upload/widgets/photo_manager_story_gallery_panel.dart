import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_spacing.dart';
import '../all_albums_screen.dart';
import '../photo_gallery_permission.dart';

/// In-app gallery matching [UploadScreen] Post flow: album menu + 3-column grid.
///
/// Story rules: multi-select **photos** (up to [remainingPhotoSlots]) or **one video**
/// when [existingPhotoCount] is 0. Append mode ([existingPhotoCount] > 0) is images only.
class PhotoManagerStoryGalleryPanel extends StatefulWidget {
  const PhotoManagerStoryGalleryPanel({
    super.key,
    required this.existingPhotoCount,
    required this.onImagesPicked,
    required this.onVideoPicked,
    required this.onBack,
  });

  /// Photos already in the editor; append picks may add at most `10 - this`.
  final int existingPhotoCount;
  final Future<void> Function(List<File> files) onImagesPicked;
  final Future<void> Function(File file) onVideoPicked;
  final VoidCallback onBack;

  @override
  State<PhotoManagerStoryGalleryPanel> createState() =>
      _PhotoManagerStoryGalleryPanelState();
}

class _PhotoManagerStoryGalleryPanelState extends State<PhotoManagerStoryGalleryPanel>
    with WidgetsBindingObserver {
  String _selectedAlbum = 'Recents';
  List<AssetPathEntity> _paths = [];
  List<AssetEntity> _assets = [];
  bool _loading = true;
  String? _permissionError;
  AssetPathEntity? _pathOverride;

  /// Selection order for multi-photo (indices into [_assets]).
  final List<int> _selectedImageIndexes = [];
  int? _selectedVideoIndex;
  bool _submitting = false;

  /// Ignores stale [setState] when [_loadGallery] is invoked concurrently.
  int _galleryLoadGeneration = 0;

  int get _remainingPhotoSlots => (10 - widget.existingPhotoCount).clamp(0, 10);

  bool get _appendMode => widget.existingPhotoCount > 0;

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
        return _paths.first;
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
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadGallery();
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
        _permissionError != null) {
      _loadGallery();
    }
  }

  Future<void> _loadGallery() async {
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
        _selectedImageIndexes.clear();
        _selectedVideoIndex = null;
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

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  void _onCellTap(int index) {
    if (index < 0 || index >= _assets.length) return;
    final entity = _assets[index];
    if (_isVideoAsset(entity)) {
      if (_appendMode) {
        _showSnack('Add more photos only here, or clear photos to pick a video.');
        return;
      }
      if (_selectedImageIndexes.isNotEmpty) {
        _showSnack('Deselect photos to choose a video.');
        return;
      }
      setState(() {
        _selectedVideoIndex = _selectedVideoIndex == index ? null : index;
      });
      return;
    }

    if (_selectedVideoIndex != null) {
      setState(() => _selectedVideoIndex = null);
    }
    setState(() {
      final i = _selectedImageIndexes.indexOf(index);
      if (i >= 0) {
        _selectedImageIndexes.removeAt(i);
      } else {
        if (_selectedImageIndexes.length >= _remainingPhotoSlots) {
          _showSnack(
            _appendMode
                ? 'You can add up to $_remainingPhotoSlots more photo(s).'
                : 'You can select up to 10 photos.',
          );
          return;
        }
        _selectedImageIndexes.add(index);
      }
    });
  }

  Future<void> _onNext() async {
    if (_submitting) return;
    if (_selectedVideoIndex != null) {
      final entity = _assets[_selectedVideoIndex!];
      setState(() => _submitting = true);
      try {
        final file = await entity.file;
        if (!mounted) return;
        if (file == null) {
          _showSnack('Could not load that video.');
          setState(() => _submitting = false);
          return;
        }
        await widget.onVideoPicked(file);
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
      return;
    }

    if (_selectedImageIndexes.isEmpty) {
      _showSnack('Select photo(s) or one video');
      return;
    }

    setState(() => _submitting = true);
    try {
      final files = <File>[];
      for (final i in _selectedImageIndexes) {
        final entity = _assets[i];
        if (_isVideoAsset(entity)) continue;
        final file = await entity.file;
        if (file != null) files.add(file);
      }
      if (!mounted) return;
      if (files.isEmpty) {
        _showSnack('Could not load the selected photos.');
        setState(() => _submitting = false);
        return;
      }
      await widget.onImagesPicked(files);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: AppGradients.premiumDarkGradient),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: widget.onBack,
              icon: Image.asset(
                'assets/vyooO_icons/Home/chevron_left.png',
                width: 22,
                height: 22,
                color: Colors.white,
              ),
            ),
          ),
          _GalleryAlbumPopup(
            value: _selectedAlbum,
            paths: _paths,
            onChanged: (v) async {
              if (v == null) return;
              if (v == 'All Albums') {
                if (_paths.isEmpty) return;
                final path = await Navigator.of(context).push<AssetPathEntity>(
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
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _submitting
                ? const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: _onNext,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Next',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_appendMode && _remainingPhotoSlots <= 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'You already have 10 photos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
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
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tap Try again to show the system prompt. If nothing changes, '
                'use Open Settings and allow Photos or media access for Vyooo, '
                'then return here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(200, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: openGalleryRelatedAppSettings,
                child: const Text(
                  'Open Settings',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 48),
                ),
                onPressed: _loading ? null : _loadGallery,
                child: const Text(
                  'Try again',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
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
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_assets.isEmpty) {
      return Center(
        child: Text(
          'No photos or videos',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 16,
          ),
        ),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 1,
        crossAxisSpacing: 1,
        childAspectRatio: 1,
      ),
      itemCount: _assets.length,
      itemBuilder: (context, index) {
        final entity = _assets[index];
        final isVideo = _isVideoAsset(entity);
        final vi = _selectedVideoIndex == index;
        final photoOrder = _selectedImageIndexes.indexOf(index);
        final selectedPhoto = photoOrder >= 0;
        return GestureDetector(
          onTap: () => _onCellTap(index),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _GalleryThumbnail(entity: entity),
              if (isVideo) _VideoDuration(entity: entity),
              if (vi)
                Container(
                  color: Colors.black45,
                  child: const Center(
                    child: Icon(Icons.check_circle, color: Colors.white, size: 40),
                  ),
                )
              else if (selectedPhoto)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDE106B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${photoOrder + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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
          color: Colors.white.withValues(alpha: 0.1),
          child: Center(
            child: Image.asset(
              'assets/vyooO_icons/Upload_Story_Live/gallery.png',
              width: 40,
              height: 40,
              color: Colors.white38,
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

class _GalleryAlbumPopup extends StatelessWidget {
  const _GalleryAlbumPopup({
    required this.value,
    required this.paths,
    required this.onChanged,
  });

  final String value;
  final List<AssetPathEntity> paths;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 44),
      color: const Color(0xFF1E0A1E).withValues(alpha: 0.98),
      elevation: 4,
      shadowColor: Colors.black54,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      itemBuilder: (context) => [
        _buildPopupItem('Recents', Icons.photo_library_outlined),
        _buildPopupItem('Favourites', Icons.favorite_border_rounded),
        _buildPopupItem('All Albums', Icons.grid_view_outlined),
      ],
      onSelected: onChanged,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 24,
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
          Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(
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
