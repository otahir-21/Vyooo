import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// All Albums screen: 2-column grid of gallery albums (thumbnail, name, count).
/// Tapping an album pops with that [AssetPathEntity].
class AllAlbumsScreen extends StatefulWidget {
  const AllAlbumsScreen({
    super.key,
    required this.paths,
  });

  final List<AssetPathEntity> paths;

  @override
  State<AllAlbumsScreen> createState() => _AllAlbumsScreenState();
}

class _AllAlbumsScreenState extends State<AllAlbumsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.chatBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpacing.lg,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: widget.paths.length,
                  itemBuilder: (context, index) {
                    final path = widget.paths[index];
                    return _AlbumTile(
                      path: path,
                      onTap: () => Navigator.of(context).pop(path),
                    );
                  },
                ),
              ),
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
              onPressed: () => Navigator.of(context).pop(),
              icon: Image.asset(
                'assets/vyooO_icons/Search/close.png',
                width: 24,
                height: 24,
                color: AppColors.chatAppBarActionIcon,
              ),
            ),
          ),
          Text(
            'All Albums',
            style: AppTypography.authDialogTitle.copyWith(
              color: AppColors.chatTextPrimary,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Next',
                style: AppTypography.chatTileName.copyWith(
                  color: AppColors.brandDeepMagenta,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({required this.path, required this.onTap});

  final AssetPathEntity path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppRadius.inputRadius,
            child: AspectRatio(
              aspectRatio: 1,
              child: FutureBuilder<Uint8List?>(
                future: _thumbnailFuture(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return Image.memory(
                      snapshot.data!,
                      fit: BoxFit.cover,
                    );
                  }
                  return Container(
                    color: AppColors.chatSearchFill,
                    child: Center(
                      child: Icon(
                        Icons.photo_library_outlined,
                        color: AppColors.chatTextSecondary.withValues(alpha: 0.5),
                        size: 40,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          Text(
            path.name,
            style: AppTypography.chatTileName.copyWith(
              color: AppColors.chatTextPrimary,
              fontSize: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          FutureBuilder<int>(
            future: path.assetCountAsync,
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Text(
                _formatCount(count),
                style: AppTypography.chatTilePreview,
              );
            },
          ),
        ],
      ),
    );
  }

  Future<Uint8List?> _thumbnailFuture() async {
    final list = await path.getAssetListPaged(page: 0, size: 1);
    if (list.isEmpty) return null;
    return list.first.thumbnailDataWithSize(const ThumbnailSize.square(400));
  }

  String _formatCount(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
