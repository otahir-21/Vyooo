import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../screens/profile/profile_figma_tokens.dart';

/// Highlight album chip on profile — square cover with title below.
class ProfileHighlightAlbumTile extends StatelessWidget {
  const ProfileHighlightAlbumTile({
    super.key,
    required this.title,
    required this.onTap,
    this.coverMediaUrl,
  });

  final String title;
  final VoidCallback onTap;
  final String? coverMediaUrl;

  @override
  Widget build(BuildContext context) {
    final cover = (coverMediaUrl ?? '').trim();

    return SizedBox(
      width: ProfileFigmaTokens.highlightTileWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(
                ProfileFigmaTokens.highlightTileRadius,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  ProfileFigmaTokens.highlightTileRadius,
                ),
                child: SizedBox(
                  width: ProfileFigmaTokens.highlightTileWidth,
                  height: ProfileFigmaTokens.highlightTileHeight,
                  child: cover.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => _placeholder(title),
                          errorWidget: (_, _, _) => _placeholder(title),
                        )
                      : _placeholder(title),
                ),
              ),
            ),
          ),
          SizedBox(height: ProfileFigmaTokens.highlightLabelGap),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'DM Sans',
              color: ProfileFigmaTokens.highlightLabelColor,
              fontSize: ProfileFigmaTokens.highlightLabelFontSize,
              fontWeight: ProfileFigmaTokens.highlightLabelFontWeight,
              height: ProfileFigmaTokens.highlightLabelLineHeight /
                  ProfileFigmaTokens.highlightLabelFontSize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(String label) {
    return ColoredBox(
      color: ProfileFigmaTokens.highlightTileBackground,
      child: Center(
        child: Text(
          label.isNotEmpty ? label[0].toUpperCase() : '?',
          style: const TextStyle(
            fontFamily: 'DM Sans',
            color: ProfileFigmaTokens.primaryText,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
