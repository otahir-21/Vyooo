import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/reels_service.dart';
import 'profile_grid_posts.dart';
import 'profile_reel_grid_navigation.dart';

/// Loads profile post lists once per cache key; avoids refetch on parent [setState].
abstract final class ProfilePostsLoader {
  ProfilePostsLoader._();

  static Future<List<Map<String, dynamic>>> loadPostsForUser(String uid) async {
    if (uid.isEmpty) return const [];
    final q = await FirebaseFirestore.instance
        .collection('reels')
        .where('userId', isEqualTo: uid)
        .get();
    final docs = q.docs
        .map(
          (d) => ProfileReelGridNavigation.reelMapFromFirestore(
            d.id,
            d.data(),
            fallbackUserId: uid,
          ),
        )
        .toList();
    docs.sort(profilePostsSortNewestFirst);
    final hydrated = await ReelsService().hydrateRepostEngagementStats(docs);
    return ProfileGridPosts.filterImageAndVideo(hydrated);
  }
}

int profilePostsSortNewestFirst(
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
