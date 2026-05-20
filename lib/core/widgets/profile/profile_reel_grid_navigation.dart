import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../screens/content/post_feed_screen.dart';
import '../../../screens/content/vr_detail_screen.dart';
import '../../../screens/profile/profile_figma_tokens.dart';

/// Thumbnail + navigation helpers for profile Posts / VR / Saved grids.
abstract final class ProfileReelGridNavigation {
  ProfileReelGridNavigation._();

  static String thumbnailFromReel(Map<String, dynamic> reel) {
    final mediaType = ((reel['mediaType'] as String?) ?? '').toLowerCase();
    final imageUrl = (reel['imageUrl'] as String?)?.trim() ?? '';
    final explicitThumb = (reel['thumbnailUrl'] as String?)?.trim() ?? '';
    final videoUrl = (reel['videoUrl'] as String?)?.trim() ?? '';
    if (mediaType == 'image') {
      if (imageUrl.isNotEmpty) return imageUrl;
      if (explicitThumb.isNotEmpty) return explicitThumb;
      return '';
    }
    if (explicitThumb.isNotEmpty) return explicitThumb;
    if (imageUrl.isNotEmpty) return imageUrl;
    if (videoUrl.isEmpty) return '';
    try {
      final uri = Uri.parse(videoUrl);
      final videoId =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      if (videoId.isEmpty) return '';
      return 'https://videodelivery.net/$videoId/thumbnails/thumbnail.jpg';
    } catch (_) {
      return '';
    }
  }

  static int sortReelsNewestFirst(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final aTs = a['createdAt'] as Timestamp?;
    final bTs = b['createdAt'] as Timestamp?;
    if (aTs == null && bTs == null) return 0;
    if (aTs == null) return 1;
    if (bTs == null) return -1;
    return bTs.compareTo(aTs);
  }

  static void openPostFeed({
    required BuildContext context,
    required List<Map<String, dynamic>> posts,
    required int index,
    required String fallbackDisplayName,
    required String fallbackUsername,
    required String fallbackAvatarUrl,
    required bool fallbackIsVerified,
    bool? liveIsVerified,
  }) {
    final reel = posts[index];
    final username = (reel['username'] as String? ?? '').trim();
    final avatarUrl = (reel['avatarUrl'] as String? ?? '').trim();
    final creatorName =
        username.isNotEmpty ? username : fallbackDisplayName;
    final handle = username.isNotEmpty
        ? ProfileFigmaTokens.displayUsername(username)
        : ProfileFigmaTokens.displayUsername(fallbackUsername);
    final isVerified = reel['isVerified'] == true ||
        liveIsVerified == true ||
        fallbackIsVerified;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PostFeedScreen(
          payload: PostFeedPayload(
            posts: posts,
            initialIndex: index,
            creatorName: creatorName,
            creatorHandle: handle,
            avatarUrl:
                avatarUrl.isNotEmpty ? avatarUrl : fallbackAvatarUrl,
            isVerified: isVerified,
          ),
        ),
      ),
    );
  }

  static void openVRDetail({
    required BuildContext context,
    required Map<String, dynamic> item,
  }) {
    final creatorName = (item['username']?.toString() ?? '').trim();
    final creatorHandle = (item['handle']?.toString() ?? '').trim();
    final avatar = (item['avatarUrl']?.toString() ?? '').trim();
    final thumb = thumbnailFromReel(item);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VRDetailScreen(
          payload: VRDetailPayload(
            creatorName:
                creatorName.isNotEmpty ? creatorName : 'Creator',
            creatorHandle: creatorHandle.isNotEmpty
                ? ProfileFigmaTokens.displayUsername(creatorHandle)
                : 'creator',
            avatarUrl: avatar,
            thumbnailUrl: thumb,
            likeCount: (item['likes'] as num?)?.toInt() ?? 0,
          ),
        ),
      ),
    );
  }
}
