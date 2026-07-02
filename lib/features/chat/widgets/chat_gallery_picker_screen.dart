import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../screens/upload/photo_gallery_permission.dart';

enum ChatGalleryPickType { image, video }

/// In-app gallery picker for chat attachments.
///
/// Avoids the Android system photo picker, which fails to return results when
/// [MainActivity] uses restrictive launch modes.
class ChatGalleryPickerScreen extends StatefulWidget {
  const ChatGalleryPickerScreen({
    super.key,
    required this.pickType,
  });

  final ChatGalleryPickType pickType;

  static Future<File?> open(
    BuildContext context, {
    required ChatGalleryPickType pickType,
  }) {
    return Navigator.of(context).push<File?>(
      MaterialPageRoute<File?>(
        fullscreenDialog: true,
        builder: (_) => ChatGalleryPickerScreen(pickType: pickType),
      ),
    );
  }

  @override
  State<ChatGalleryPickerScreen> createState() =>
      _ChatGalleryPickerScreenState();
}

class _ChatGalleryPickerScreenState extends State<ChatGalleryPickerScreen>
    with WidgetsBindingObserver {
  List<AssetEntity> _assets = [];
  bool _loading = true;
  String? _permissionError;
  bool _submitting = false;
  int _galleryLoadGeneration = 0;

  bool get _imagesOnly => widget.pickType == ChatGalleryPickType.image;

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
              'Allow photo library access in Settings to choose media.';
        });
        return;
      }

      final paths = await PhotoManager.getAssetPathList(
        type: _imagesOnly ? RequestType.image : RequestType.video,
        hasAll: true,
      );
      if (!mounted || gen != _galleryLoadGeneration) return;
      if (paths.isEmpty) {
        setState(() {
          _assets = [];
          _loading = false;
        });
        return;
      }

      final recents = paths.firstWhere(
        (p) {
          final n = p.name.toLowerCase();
          return n.contains('recent') || n == 'recents';
        },
        orElse: () => paths.first,
      );
      final list = await recents.getAssetListPaged(page: 0, size: 300);
      if (!mounted || gen != _galleryLoadGeneration) return;
      setState(() {
        _assets = list;
        _loading = false;
      });
    } catch (e) {
      if (mounted && gen == _galleryLoadGeneration) {
        setState(() {
          _loading = false;
          _permissionError = 'Could not load gallery.';
        });
      }
    }
  }

  Future<void> _onAssetTap(AssetEntity asset) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final file = await asset.file;
      if (!mounted) return;
      if (file == null) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the selected item.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      Navigator.of(context).pop(file);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the selected item.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _imagesOnly ? 'Choose Photo' : 'Choose Video';
    return Scaffold(
      backgroundColor: AppColors.chatBackground,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                  Text(
                    title,
                    style: AppTypography.chatTileName.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_submitting)
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: EdgeInsets.only(right: AppSpacing.md),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.brandDeepMagenta,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandDeepMagenta),
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
                  color: AppColors.chatTextSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: openGalleryRelatedAppSettings,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.authBrandBurgundy,
                ),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      );
    }
    if (_assets.isEmpty) {
      return Center(
        child: Text(
          _imagesOnly ? 'No photos found' : 'No videos found',
          style: AppTypography.chatTileName.copyWith(
            color: AppColors.chatTextSecondary,
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
        final asset = _assets[index];
        return GestureDetector(
          onTap: _submitting ? null : () => _onAssetTap(asset),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Thumbnail(asset: asset),
              if (!_imagesOnly) _VideoDurationBadge(asset: asset),
            ],
          ),
        );
      },
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.asset});

  final AssetEntity asset;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(const ThumbnailSize.square(400)),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        }
        return const ColoredBox(color: AppColors.chatSearchFill);
      },
    );
  }
}

class _VideoDurationBadge extends StatelessWidget {
  const _VideoDurationBadge({required this.asset});

  final AssetEntity asset;

  @override
  Widget build(BuildContext context) {
    final sec = asset.videoDuration.inSeconds;
    if (sec <= 0) return const SizedBox.shrink();
    final m = sec ~/ 60;
    final s = sec % 60;
    final label = '$m:${s.toString().padLeft(2, '0')}';
    return Positioned(
      right: 6,
      bottom: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: AppTypography.chatTilePreview.copyWith(
            color: Colors.white,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
