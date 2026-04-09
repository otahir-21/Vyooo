import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user_model.dart';

class UserDiscoveryItem {
  const UserDiscoveryItem({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.isFollowing,
    required this.followerCount,
  });

  final String uid;
  final String username;
  final String displayName;
  final String avatarUrl;
  final bool isFollowing;
  final int followerCount;
}

/// Firestore user document operations. No UI, no BuildContext.
/// Call createUserDocument AFTER successful registration.
class UserService {
  UserService._();
  static final UserService _instance = UserService._();
  factory UserService() => _instance;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static const String _usersCollection = 'users';

  static Map<String, dynamic> _initialUserData(
    String uid,
    String email, {
    required bool emailOtpVerified,
  }) =>
      {
        'uid': uid,
        'email': email,
        'username': '',
        'dob': '',
        'profileImage': '',
        'interests': [],
        'onboardingCompleted': false,
        'emailOtpVerified': emailOtpVerified,
        'createdAt': FieldValue.serverTimestamp(),
        'following': <String>[],
        'blockedUsers': <String>[],
        'followersCount': 0,
      };

  /// Creates the initial user document. Call after AuthService.registerWithEmail success.
  Future<void> createUserDocument({
    required String uid,
    required String email,
  }) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).set(
            _initialUserData(uid, email, emailOtpVerified: false),
          );
    } catch (e) {
      rethrow;
    }
  }

  /// Ensures the user document exists. Creates it only if missing (e.g. if createUserDocument failed at signup).
  Future<void> ensureUserDocument({
    required String uid,
    required String email,
  }) async {
    try {
      final docRef = _firestore.collection(_usersCollection).doc(uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        await docRef.set(
          _initialUserData(uid, email, emailOtpVerified: true),
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Updates user profile fields. Uses set with merge so the doc is created if it doesn't exist yet.
  Future<void> updateUserProfile({
    required String uid,
    String? username,
    String? dob,
    String? profileImage,
    List<String>? interests,
    bool? onboardingCompleted,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (username != null) {
        data['username'] = username.trim().toLowerCase();
      }
      if (dob != null) data['dob'] = dob;
      if (profileImage != null) data['profileImage'] = profileImage;
      if (interests != null) data['interests'] = interests;
      if (onboardingCompleted != null) data['onboardingCompleted'] = onboardingCompleted;
      if (data.isEmpty) return;
      await _firestore.collection(_usersCollection).doc(uid).set(
            data,
            SetOptions(merge: true),
          );
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches the user document. Returns null if not found or on error.
  Future<AppUserModel?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return AppUserModel.fromJson(doc.data()!);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Stream of user document for reactive updates.
  Stream<AppUserModel?> userStream(String uid) {
    return _firestore
        .collection(_usersCollection)
        .doc(uid)
        .snapshots()
        .map((snap) {
      if (snap.exists && snap.data() != null) {
        return AppUserModel.fromJson(snap.data()!);
      }
      return null;
    });
  }

  /// List of user IDs the current user is following. Source: users/{uid}.following (array).
  Future<List<String>> getFollowing(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      final data = doc.data();
      if (data == null) return [];
      final following = data['following'];
      if (following is List) {
        return following.map((e) => e.toString()).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// How many users include [targetUid] in their `following` array.
  Future<int> getFollowerCount(String targetUid) async {
    if (targetUid.isEmpty) return 0;
    try {
      final agg = await _firestore
          .collection(_usersCollection)
          .where('following', arrayContains: targetUid)
          .count()
          .get();
      return agg.count ?? 0;
    } catch (_) {
      try {
        final q = await _firestore
            .collection(_usersCollection)
            .where('following', arrayContains: targetUid)
            .get();
        return q.docs.length;
      } catch (_) {
        return 0;
      }
    }
  }

  /// User documents for accounts that follow [targetUid].
  Future<List<AppUserModel>> getFollowerProfilesForUser(
    String targetUid, {
    int limit = 200,
  }) async {
    if (targetUid.isEmpty) return [];
    try {
      final q = await _firestore
          .collection(_usersCollection)
          .where('following', arrayContains: targetUid)
          .limit(limit)
          .get();
      final out = <AppUserModel>[];
      for (final doc in q.docs) {
        try {
          out.add(AppUserModel.fromJson(doc.data()));
        } catch (_) {}
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  /// User documents for each uid in users/{uid}.following (order preserved).
  Future<List<AppUserModel>> getFollowingProfilesForUser(String uid) async {
    final ids = await getFollowing(uid);
    return getUsersByIds(ids);
  }

  /// Published reels count for profile stats.
  Future<int> getReelCountForUser(String uid) async {
    if (uid.isEmpty) return 0;
    try {
      final agg = await _firestore
          .collection('reels')
          .where('userId', isEqualTo: uid)
          .count()
          .get();
      return agg.count ?? 0;
    } catch (_) {
      try {
        final q = await _firestore
            .collection('reels')
            .where('userId', isEqualTo: uid)
            .get();
        return q.docs.length;
      } catch (_) {
        return 0;
      }
    }
  }

  static List<String> _stringListField(Map<String, dynamic>? data, String key) {
    if (data == null) return [];
    final v = data[key];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  /// Blocked user IDs for [uid] (users/{uid}.blockedUsers).
  Future<List<String>> getBlockedUserIds(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      return _stringListField(doc.data(), 'blockedUsers');
    } catch (_) {
      return [];
    }
  }

  Future<bool> isFollowingUser({
    required String currentUid,
    required String targetUid,
  }) async {
    final list = await getFollowing(currentUid);
    return list.contains(targetUid);
  }

  Future<bool> isUserBlocked({
    required String currentUid,
    required String targetUid,
  }) async {
    final blocked = await getBlockedUserIds(currentUid);
    return blocked.contains(targetUid);
  }

  /// Adds [targetUid] to users/{currentUid}.following. Only mutates the signed-in user's document
  /// (works with tight Firestore rules: no writes to other users' docs).
  Future<void> followUser({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid.isEmpty || targetUid.isEmpty || currentUid == targetUid) {
      throw ArgumentError('Invalid follow');
    }
    final meRef = _firestore.collection(_usersCollection).doc(currentUid);
    await meRef.set(
      {
        'following': FieldValue.arrayUnion([targetUid]),
        'blockedUsers': FieldValue.arrayRemove([targetUid]),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> unfollowUser({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid.isEmpty || targetUid.isEmpty || currentUid == targetUid) {
      throw ArgumentError('Invalid unfollow');
    }
    final meRef = _firestore.collection(_usersCollection).doc(currentUid);
    await meRef.set(
      {'following': FieldValue.arrayRemove([targetUid])},
      SetOptions(merge: true),
    );
  }

  /// Blocks [targetUid]: adds to blockedUsers and removes from following (local doc only).
  Future<void> blockUser({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid.isEmpty || targetUid.isEmpty || currentUid == targetUid) {
      throw ArgumentError('Invalid block');
    }
    final meRef = _firestore.collection(_usersCollection).doc(currentUid);
    await meRef.set(
      {
        'blockedUsers': FieldValue.arrayUnion([targetUid]),
        'following': FieldValue.arrayRemove([targetUid]),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> unblockUser({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid.isEmpty || targetUid.isEmpty) {
      throw ArgumentError('Invalid unblock');
    }
    final meRef = _firestore.collection(_usersCollection).doc(currentUid);
    await meRef.set(
      {'blockedUsers': FieldValue.arrayRemove([targetUid])},
      SetOptions(merge: true),
    );
  }

  /// Reactive follower count stream based on users who include [uid] in following.
  Stream<int> followerCountStream(String uid) {
    if (uid.isEmpty) return const Stream<int>.empty();
    return _firestore
        .collection(_usersCollection)
        .where('following', arrayContains: uid)
        .snapshots()
        .map((q) => q.docs.length);
  }

  /// Reactive reels count stream for a profile.
  Stream<int> reelCountStream(String uid) {
    if (uid.isEmpty) return const Stream<int>.empty();
    return _firestore
        .collection('reels')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((q) => q.docs.length);
  }

  /// Fetches many user documents in batched whereIn queries (max 10 each), preserving [userIds] order.
  Future<List<AppUserModel>> getUsersByIds(List<String> userIds) async {
    final ids = userIds.where((e) => e.trim().isNotEmpty).toList();
    if (ids.isEmpty) return [];
    final byId = <String, AppUserModel>{};
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, (i + 10 > ids.length) ? ids.length : i + 10);
      try {
        final q = await _firestore
            .collection(_usersCollection)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final d in q.docs) {
          final model = AppUserModel.fromJson(d.data());
          byId[model.uid.isNotEmpty ? model.uid : d.id] = model;
        }
      } catch (_) {}
    }
    final ordered = <AppUserModel>[];
    for (final id in ids) {
      final v = byId[id];
      if (v != null) ordered.add(v);
    }
    return ordered;
  }

  /// Search/discover users (excluding [currentUid] and any IDs in [excludeIds]).
  Future<List<AppUserModel>> discoverUsers({
    required String currentUid,
    String query = '',
    Set<String> excludeIds = const {},
    int limit = 200,
  }) async {
    if (currentUid.isEmpty) return [];
    try {
      final snap = await _firestore.collection(_usersCollection).limit(limit).get();
      final q = query.trim().toLowerCase();
      final out = <AppUserModel>[];
      for (final d in snap.docs) {
        final data = d.data();
        final model = AppUserModel.fromJson(data);
        final uid = model.uid.isNotEmpty ? model.uid : d.id;
        if (uid == currentUid || excludeIds.contains(uid)) continue;
        final name = (model.username ?? '').trim().toLowerCase();
        final emailName = model.email.split('@').first.toLowerCase();
        final searchable = '$name $emailName';
        if (q.isNotEmpty && !searchable.contains(q)) continue;
        out.add(model.copyWith(uid: uid));
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  /// Centralized discover/search list used by profile + global search.
  /// Filters out self + blocked users and marks follow state from current user's following.
  Future<List<UserDiscoveryItem>> discoverUserItems({
    required String currentUid,
    String query = '',
    int limit = 120,
  }) async {
    if (currentUid.isEmpty) return [];
    final following = await getFollowing(currentUid);
    final blocked = await getBlockedUserIds(currentUid);
    final users = await discoverUsers(
      currentUid: currentUid,
      query: query,
      excludeIds: blocked.toSet(),
      limit: limit,
    );
    final out = <UserDiscoveryItem>[];
    for (final u in users) {
      final uid = u.uid;
      if (uid.isEmpty) continue;
      final username = (u.username ?? '').trim().isNotEmpty
          ? u.username!.trim()
          : (u.email.contains('@') ? u.email.split('@').first : uid);
      final displayName = username;
      out.add(
        UserDiscoveryItem(
          uid: uid,
          username: username,
          displayName: displayName,
          avatarUrl: (u.profileImage ?? '').trim(),
          isFollowing: following.contains(uid),
          followerCount: u.followersCount,
        ),
      );
    }
    out.sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));
    return out;
  }
}
