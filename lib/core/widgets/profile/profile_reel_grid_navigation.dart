import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/reel_media_item.dart';
import '../../models/video_360_metadata.dart';
import '../../../screens/content/post_feed_screen.dart';
import '../../../screens/content/vr_detail_screen.dart';
import '../../../screens/profile/profile_figma_tokens.dart';

/// Thumbnail + navigation helpers for profile Posts / VR / Saved grids.
abstract final class ProfileReelGridNavigation {
  ProfileReelGridNavigation._();

  /// Maps a `reels` document for profile grids (image + video posts).
  static Map<String, dynamic> reelMapFromFirestore(
    String docId,
    Map<String, dynamic> data, {
    String fallbackUserId = '',
  }) {
    return {
      'id': docId,
      'userId': data['userId'] as String? ?? fallbackUserId,
      'username': data['username'] as String? ?? '',
      'handle': data['handle'] as String? ?? '',
      'avatarUrl': data['avatarUrl'] as String? ?? '',
      'videoUrl': data['videoUrl'] as String? ?? '',
      'imageUrl': data['imageUrl'] as String? ?? '',
      'thumbnailUrl': data['thumbnailUrl'] as String? ?? '',
      'mediaType': data['mediaType'] as String? ?? '',
      'mediaItems': ReelMediaItem.sanitizedRawList(data['mediaItems']),
      'mediaCount': (data['mediaCount'] as num?)?.toInt() ?? 1,
      'caption': data['caption'] as String? ?? '',
      'title': data['title'] as String? ?? '',
      'description': data['description'] as String? ?? '',
      'tags': data['tags'] is List
          ? (data['tags'] as List).map((e) => e.toString()).toList()
          : const <String>[],
      'likes': (data['likes'] as num?)?.toInt() ?? 0,
      'comments': (data['comments'] as num?)?.toInt() ?? 0,
      'shares': (data['shares'] as num?)?.toInt() ?? 0,
      'views': (data['views'] as num?)?.toInt() ?? 0,
      'saves': (data['saves'] as num?)?.toInt() ?? 0,
      'reportCount': (data['reportCount'] as num?)?.toInt() ?? 0,
      'moderation': data['moderation'],
      'createdAt': data['createdAt'],
      'isVR': data['isVR'] == true,
      'is360Video': data['is360Video'] == true,
      'projectionType': data['projectionType'] as String? ?? 'flat',
      'stereoMode': data['stereoMode'] as String? ?? 'mono',
      'profileGridSpan': data['profileGridSpan'] as String? ?? '',
      'profileGridTitle': data['profileGridTitle'] as String? ?? '',
      'profileGridThumbnailUrl': data['profileGridThumbnailUrl'] as String? ?? '',
      'hideLikeCount': data['hideLikeCount'] == true,
      'hideViewCount': data['hideViewCount'] == true,
      'hideShareCount': data['hideShareCount'] == true,
      'hideCommentCount': data['hideCommentCount'] == true,
      'hideSaveCount': data['hideSaveCount'] == true,
      'reposts': (data['reposts'] as num?)?.toInt() ??
          (data['shares'] as num?)?.toInt() ??
          0,
      'isRepost': data['isRepost'] == true,
      'repostOf': data['repostOf'] as String? ?? '',
      'repostOfUserId': data['repostOfUserId'] as String? ?? '',
      'repostOfUsername': data['repostOfUsername'] as String? ?? '',
    };
  }

  static String thumbnailFromReel(Map<String, dynamic> reel) {
    final gridThumb =
        (reel['profileGridThumbnailUrl'] as String?)?.trim() ?? '';
    if (gridThumb.isNotEmpty) return gridThumb;
    return defaultThumbnailFromReel(reel);
  }

  /// Post thumbnail without [profileGridThumbnailUrl] override.
  static String defaultThumbnailFromReel(Map<String, dynamic> reel) {
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
    final videoUrl = (item['videoUrl'] as String? ?? '').trim();
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
            videoUrl: videoUrl.isNotEmpty ? videoUrl : null,
            description: (item['description'] as String? ??
                    item['caption'] as String? ??
                    '')
                .trim(),
            likeCount: (item['likes'] as num?)?.toInt() ?? 0,
            commentCount: (item['comments'] as num?)?.toInt() ?? 0,
            viewCount: (item['views'] as num?)?.toInt() ?? 0,
            shareCount: (item['shares'] as num?)?.toInt() ?? 0,
            saveCount: (item['saves'] as num?)?.toInt() ?? 0,
            video360: Video360Metadata.forVrPlayback(item),
          ),
        ),
      ),
    );
  }
}
