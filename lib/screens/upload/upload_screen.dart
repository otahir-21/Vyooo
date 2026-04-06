import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_spacing.dart';
import 'all_albums_screen.dart';
import 'creator_live_route.dart';
import 'story_capture_screen.dart';
import 'upload_video_preview_screen.dart';

/// Upload screen for subscribers: media grid from gallery, album dropdown, Story / Gallery / Live actions.
/// Opened from bottom nav plus; standard users are redirected to membership instead.
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  String _selectedAlbum = 'Recents';
  int? _selectedIndex;
  int _bottomSegment = 1; // 0 Story, 1 Gallery, 2 Live

  List<AssetPathEntity> _paths = [];
  List<AssetEntity> _assets = [];
  bool _loading = true;
  String? _permissionError;

  /// When user picks an album from All Albums screen.
  AssetPathEntity? _pathOverride;

  AssetPathEntity? get _currentPath {
    if (_pathOverride != null) return _pathOverride;
    if (_paths.isEmpty) return null;
    switch (_selectedAlbum) {
      case 'Favourites':
        final list = _paths.where((p) => p.name.toLowerCase().contains('favor')).toList();
        return list.isNotEmpty ? list.first : _paths.first;
      case 'All Albums':
        return _paths.first; // fallback "All" / root
      case 'Recents':
      default:
        final list = _paths.where((p) {
          final n = p.name.toLowerCase();
          return n.contains('recent') || n == 'recents';
        }).toList();
        return list.isNotEmpty ? list.first : (_paths.length > 1 ? _paths[1] : _paths.first);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadGallery();
  }

  Future<void> _loadGallery() async {
    setState(() {
      _loading = true;
      _permissionError = null;
    });
    try {
      final perm = await PhotoManager.requestPermissionExtend();
      if (!perm.isAuth) {
        setState(() {
          _loading = false;
          _permissionError = 'Photo library access is needed to choose videos.';
        });
        return;
      }
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        hasAll: true,
      );
      if (!mounted) return;
      setState(() {
        _paths = paths;
        _loading = false;
      });
      await _loadAssetsForCurrentPath();
    } catch (e) {
      if (mounted) {
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
      if (!mounted) return;
      setState(() {
        _assets = list;
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
        decoration: const BoxDecoration(gradient: AppGradients.feedGradient),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white, size: 26),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Text(
            'Gallery',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Center(
              child: _AlbumDropdown(
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
            ),
          ),
          TextButton(
            onPressed: () {
              if (_selectedIndex != null && _selectedIndex! < _assets.length) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => UploadVideoPreviewScreen(asset: _assets[_selectedIndex!]),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Select a video'), behavior: SnackBarBehavior.floating),
                );
              }
            },
            child: const Text('Next', style: TextStyle(color: Color(0xFFDE106B), fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
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
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 15),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: _loadGallery,
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
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
          'No videos',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16),
        ),
      );
    }
    return _buildGrid();
  }

  Widget _buildGrid() {
    const spacing = 2.0;
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
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
              if (entity.type == AssetType.video) _VideoDuration(entity: entity),
              if (selected) _SelectedBadge(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: Colors.black.withValues(alpha: 0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _BottomSegmentButton(
            label: 'Story',
            icon: Icons.auto_stories_rounded,
            selected: _bottomSegment == 0,
            onTap: () {
              setState(() => _bottomSegment = 0);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StoryCaptureScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
          _BottomSegmentButton(
            label: 'Gallery',
            icon: Icons.photo_library_rounded,
            selected: _bottomSegment == 1,
            onTap: () => setState(() => _bottomSegment = 1),
          ),
          const SizedBox(width: 8),
          _BottomSegmentButton(
            label: 'Live',
            icon: Icons.videocam_rounded,
            selected: _bottomSegment == 2,
            onTap: () {
              setState(() => _bottomSegment = 2);
              openCreatorLiveScreen(context);
            },
          ),
        ],
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
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
          );
        }
        return Container(
          color: Colors.white.withValues(alpha: 0.1),
          child: const Center(
            child: Icon(Icons.photo_library_rounded, color: Colors.white38, size: 40),
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
    final str = h > 0 ? '$h:${mm.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}' : '$mm:${s.toString().padLeft(2, '0')}';
    return Positioned(
      right: 4,
      bottom: 4,
      child: Text(
        str,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
        ),
      ),
    );
  }
}

class _SelectedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Positioned(
      top: 6,
      right: 6,
      child: DecoratedBox(
        decoration: BoxDecoration(color: Color(0xFFDE106B), shape: BoxShape.circle),
        child: Padding(
          padding: EdgeInsets.all(2),
          child: Icon(Icons.check, color: Colors.white, size: 16),
        ),
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
      offset: const Offset(0, 40),
      color: const Color(0xFF1E0A1E).withValues(alpha: 0.95),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'Recents',
          child: Row(
            children: [
              Icon(Icons.photo_library_rounded, size: 20, color: Colors.white.withValues(alpha: 0.8)),
              const SizedBox(width: 12),
              Text('Recents', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'Favourites',
          child: Row(
            children: [
              Icon(Icons.favorite_rounded, size: 20, color: Colors.white.withValues(alpha: 0.8)),
              const SizedBox(width: 12),
              Text('Favourites', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'All Albums',
          child: Row(
            children: [
              Icon(Icons.grid_view_rounded, size: 20, color: Colors.white.withValues(alpha: 0.8)),
              const SizedBox(width: 12),
              Text('All Albums', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14)),
            ],
          ),
        ),
      ],
      onSelected: onChanged,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withValues(alpha: 0.9), size: 28),
        ],
      ),
    );
  }
}

class _BottomSegmentButton extends StatelessWidget {
  const _BottomSegmentButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;


  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white.withValues(alpha: 0.65);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDE106B) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
