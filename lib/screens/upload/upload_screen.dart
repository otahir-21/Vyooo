import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_spacing.dart';
import 'all_albums_screen.dart';
import 'photo_gallery_permission.dart';
import '../../features/story/story_upload_screen.dart';
import 'creator_live_route.dart';
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
  String _selectedAlbum = 'Recents';
  int? _selectedIndex;
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
        _selectedIndex = null;
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
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: AppGradients.premiumDarkGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(child: _buildBody()),
              _buildBottomBar(),
            ],
          ),
        ),
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Image.asset(
                'assets/vyooO_icons/Search/close.png',
                width: 24,
                height: 24,
                color: Colors.white,
              ),
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
            )
          else
            Text(
              _bottomSegment == 2 ? 'Live' : 'Story',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: isPost
                ? GestureDetector(
                    onTap: () {
                      if (_selectedIndex != null &&
                          _selectedIndex! < _assets.length) {
                        final selected = _assets[_selectedIndex!];
                        if (_isVideoAsset(selected)) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  UploadVideoPreviewScreen(asset: selected),
                            ),
                          );
                        } else if (selected.type == AssetType.image) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  UploadPhotoPreviewScreen(asset: selected),
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
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Select photo or video'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Next',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                : const SizedBox(width: 48),
          ),
        ],
      ),
    );
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
          color: Colors.white.withValues(alpha: 0.14),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
      itemCount: _assets.length,
      itemBuilder: (context, index) {
        final entity = _assets[index];
        final selected = _selectedIndex == index;
        return GestureDetector(
          onTap: () => setState(() => _selectedIndex = selected ? null : index),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _GalleryThumbnail(entity: entity),
              if (_isVideoAsset(entity)) _VideoDuration(entity: entity),
              if (selected) _SelectedBadge(),
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
            builder: (_) => const StoryUploadScreen(),
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

class _SelectedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Color(0xFF27AE60),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 16, color: Colors.white),
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

