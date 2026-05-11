import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../services/username_validation.dart';
import '../models/app_user_model.dart';
import '../models/parent_consent_constants.dart';
import 'notification_service.dart';

class UserDiscoveryItem {
  const UserDiscoveryItem({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.isFollowing,
    required this.followerCount,
    required this.isVerified,
    required this.accountType,
    required this.vipVerified,
  });

  final String uid;
  final String username;
  final String displayName;
  final String avatarUrl;
  final bool isFollowing;
  final int followerCount;
  final bool isVerified;
  final String accountType;
  final bool vipVerified;
}

/// Firestore user document operations. No UI, no BuildContext.
/// Call createUserDocument AFTER successful registration.
class UserService {
  UserService._();
  static final UserService _instance = UserService._();
  factory UserService() => _instance;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static const String _usersCollection = 'users';

  static const int publicPersonaMaxLength = 80;

  /// Trims and normalizes user-entered public persona text for Firestore.
  static String normalizePublicPersona(String value) {
    var t = value.trim();
    if (t.isEmpty) return '';
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    t = t.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
    if (t.length > publicPersonaMaxLength) {
      t = t.substring(0, publicPersonaMaxLength);
    }
    return t;
  }

  static String normalizePhone(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final keepPlus = trimmed.startsWith('+');
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return '';
    return keepPlus ? '+$digitsOnly' : digitsOnly;
  }

  static Map<String, dynamic> _initialUserData(
    String uid,
    String email, {
    required bool emailOtpVerified,
  }) => {
    'uid': uid,
    'email': email,
    'phoneNumber': '',
    'normalizedPhone': '',
    'displayName': '',
    'username': '',
    'bio': '',
    'dob': '',
    'profileImage': '',
    'interests': [],
    'onboardingCompleted': false,
    'emailOtpVerified': emailOtpVerified,
    'isVerified': false,
    'verificationStatus': 'none',
    'accountType': 'private',
    'publicPersona': '',
    'vipVerified': false,
    'orgProfileCompleted': false,
    'organizationDetails': <String, dynamic>{},
    'createdAt': FieldValue.serverTimestamp(),
    'following': <String>[],
    'blockedUsers': <String>[],
    'followersCount': 0,
    'parentConsentStatus': ParentConsentStatusValue.notRequired,
    'parentConsentId': '',
    'parentUid': '',
    'parentInviteEmail': '',
    'parentInvitePhone': '',
  };

  /// Creates the initial user document. Call after AuthService.registerWithEmail success.
  Future<void> createUserDocument({
    required String uid,
    required String email,
  }) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .set(_initialUserData(uid, email, emailOtpVerified: false));
    } catch (e) {
      rethrow;
    }
  }

  /// Ensures the user document exists. Creates it only if missing (e.g. if createUserDocument failed at signup).
  Future<void> ensureUserDocument({
    required String uid,
    required String email,
    bool emailOtpVerified = true,
  }) async {
    try {
      final docRef = _firestore.collection(_usersCollection).doc(uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        await docRef.set(
          _initialUserData(uid, email, emailOtpVerified: emailOtpVerified),
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Updates user profile fields. Uses set with merge so the doc is created if it doesn't exist yet.
  Future<void> updateUserProfile({
    required String uid,
    String? email,
    String? displayName,
    String? username,
    String? bio,
    String? dob,
    String? profileImage,
    List<String>? interests,
    bool? onboardingCompleted,
    String? accountType,
    String? publicPersona,
    bool? vipVerified,
    String? phoneNumber,
    bool? orgProfileCompleted,
    Map<String, dynamic>? organizationDetails,
    String? parentConsentStatus,
    String? parentConsentId,
    String? parentUid,
    String? parentInviteEmail,
    String? parentInvitePhone,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (email != null) {
        final normalizedEmail = email.trim().toLowerCase();
        if (normalizedEmail.isNotEmpty) {
          data['email'] = normalizedEmail;
        }
      }
      if (displayName != null) {
        data['displayName'] = displayName.trim();
      }
      if (username != null) {
        data['username'] = UsernameValidation.normalize(username);
      }
      if (bio != null) data['bio'] = bio.trim();
      if (dob != null) data['dob'] = dob;
      if (profileImage != null) data['profileImage'] = profileImage;
      if (interests != null) data['interests'] = interests;
      if (onboardingCompleted != null) {
        data['onboardingCompleted'] = onboardingCompleted;
      }
      if (accountType != null && accountType.trim().isNotEmpty) {
        data['accountType'] = accountType.trim().toLowerCase();
      }
      if (publicPersona != null) {
        data['publicPersona'] = normalizePublicPersona(publicPersona);
      }
      if (vipVerified != null) data['vipVerified'] = vipVerified;
      if (phoneNumber != null) {
        final raw = phoneNumber.trim();
        data['phoneNumber'] = raw;
        data['normalizedPhone'] = normalizePhone(raw);
      }
      if (orgProfileCompleted != null) {
        data['orgProfileCompleted'] = orgProfileCompleted;
      }
      if (organizationDetails != null) {
        data['organizationDetails'] = organizationDetails;
      }
      if (parentConsentStatus != null && parentConsentStatus.trim().isNotEmpty) {
        data['parentConsentStatus'] = parentConsentStatus.trim();
      }
      if (parentConsentId != null) {
        data['parentConsentId'] = parentConsentId.trim();
      }
      if (parentUid != null) {
        data['parentUid'] = parentUid.trim();
      }
      if (parentInviteEmail != null) {
        data['parentInviteEmail'] = parentInviteEmail.trim().toLowerCase();
      }
      if (parentInvitePhone != null) {
        data['parentInvitePhone'] = normalizePhone(parentInvitePhone);
      }
      if (data.isEmpty) return;
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  /// Sets parental consent outcome on the minor's user doc (merge). Uses server time for [parentConsentAt].
  Future<void> mergeMinorParentConsentOutcome({
    required String uid,
    required String parentConsentStatus,
    required String parentUid,
  }) async {
    final data = <String, dynamic>{
      'parentConsentStatus': parentConsentStatus,
      'parentUid': parentUid,
      'parentConsentAt': FieldValue.serverTimestamp(),
    };
    await _firestore.collection(_usersCollection).doc(uid).set(
          data,
          SetOptions(merge: true),
        );
  }

  /// Fetches the user document. Returns null if not found or on error.
  ///
  /// Use [server] after a write when you need to avoid a briefly stale cache read.
  Future<AppUserModel?> getUser(String uid, {bool server = false}) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get(
            GetOptions(
              source: server ? Source.server : Source.serverAndCache,
            ),
          );
      if (doc.exists && doc.data() != null) {
        return AppUserModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('getUser failed uid=$uid: $e\n$st');
      }
      return null;
    }
  }

  /// Finds a user by exact username (case-sensitive; leading `@` and spaces ignored).
  Future<AppUserModel?> getUserByUsername(String username) async {
    var key = username.trim();
    if (key.startsWith('@')) key = key.substring(1);
    key = UsernameValidation.normalize(key);
    if (key.isEmpty) return null;
    try {
      final q = await _firestore
          .collection(_usersCollection)
          .where('username', isEqualTo: key)
          .limit(2)
          .get();
      if (q.docs.isEmpty) return null;
      if (q.docs.length > 1) return null;
      return AppUserModel.fromJson(q.docs.first.data());
    } catch (_) {
      return null;
    }
  }

  /// Resolve login identifier to email.
  /// Accepts email, username (case-sensitive), or display name.
  Future<String?> resolveEmailForLoginIdentifier(String identifier) async {
    final raw = identifier.trim();
    if (raw.isEmpty) return null;
    if (raw.contains('@') && !raw.startsWith('@')) {
      return raw.toLowerCase();
    }
    final usernameKey = UsernameValidation.normalize(
      raw.startsWith('@') ? raw.substring(1) : raw,
    );
    final normalizedDisplayName = raw.toLowerCase();
    try {
      if (usernameKey.isNotEmpty) {
        final byUsername = await _firestore
            .collection(_usersCollection)
            .where('username', isEqualTo: usernameKey)
            .limit(2)
            .get();
        if (byUsername.docs.length > 1) return null;
        if (byUsername.docs.isNotEmpty) {
          final email = (byUsername.docs.first.data()['email'] as String? ?? '')
              .trim();
          if (email.isNotEmpty) return email;
        }
      }

      final byDisplayName = await _firestore
          .collection(_usersCollection)
          .where('displayName', isEqualTo: raw)
          .limit(1)
          .get();
      if (byDisplayName.docs.isNotEmpty) {
        final email =
            (byDisplayName.docs.first.data()['email'] as String? ?? '').trim();
        if (email.isNotEmpty) return email;
      }

      // Case-insensitive fallback for display names (Firestore equality is case-sensitive).
      final byDisplayNameFallback = await _firestore
          .collection(_usersCollection)
          .limit(500)
          .get();
      for (final doc in byDisplayNameFallback.docs) {
        final data = doc.data();
        final displayName = (data['displayName'] as String? ?? '')
            .trim()
            .toLowerCase();
        if (displayName != normalizedDisplayName) continue;
        final email = (data['email'] as String? ?? '').trim();
        if (email.isNotEmpty) return email;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Resolve a normalized phone number to the account email.
  Future<String?> resolveEmailForPhone(String phoneNumber) async {
    final normalized = normalizePhone(phoneNumber);
    if (normalized.isEmpty) return null;
    try {
      final byNormalized = await _firestore
          .collection(_usersCollection)
          .where('normalizedPhone', isEqualTo: normalized)
          .limit(1)
          .get();
      if (byNormalized.docs.isNotEmpty) {
        final email = (byNormalized.docs.first.data()['email'] as String? ?? '')
            .trim();
        if (email.isNotEmpty) return email;
      }
      final byRaw = await _firestore
          .collection(_usersCollection)
          .where('phoneNumber', isEqualTo: phoneNumber.trim())
          .limit(1)
          .get();
      if (byRaw.docs.isNotEmpty) {
        final email = (byRaw.docs.first.data()['email'] as String? ?? '')
            .trim();
        if (email.isNotEmpty) return email;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Stream of user document for reactive updates.
  ///
  /// If a snapshot fails to parse, the last successfully parsed model is kept so
  /// [AuthWrapper] does not flash [CreateUsernameScreen] for transient bad payloads.
  Stream<AppUserModel?> userStream(String uid) {
    AppUserModel? lastGood;
    return _firestore
        .collection(_usersCollection)
        .doc(uid)
        .snapshots()
        .map((snap) {
          if (!snap.exists || snap.data() == null) {
            lastGood = null;
            return null;
          }
          try {
            lastGood = AppUserModel.fromJson(snap.data()!);
            return lastGood;
          } catch (e, st) {
            if (kDebugMode) {
              debugPrint('userStream fromJson failed uid=$uid: $e\n$st');
            }
            return lastGood;
          }
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
    final meSnap = await meRef.get();
    final meData = meSnap.data() ?? const <String, dynamic>{};
    final followingRaw = meData['following'];
    final alreadyFollowing =
        followingRaw is List &&
        followingRaw.map((e) => e.toString()).contains(targetUid);
    if (alreadyFollowing) return;

    await meRef.set({
      'following': FieldValue.arrayUnion([targetUid]),
      'blockedUsers': FieldValue.arrayRemove([targetUid]),
    }, SetOptions(merge: true));
    await _firestore.collection(_usersCollection).doc(targetUid).update({
      'followersCount': FieldValue.increment(1),
    });
    await NotificationService().create(
      recipientId: targetUid,
      type: AppNotificationType.follow,
      message: 'started following you.',
      extra: {'targetUserId': targetUid},
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
    await meRef.set({
      'following': FieldValue.arrayRemove([targetUid]),
    }, SetOptions(merge: true));
    await _firestore.collection(_usersCollection).doc(targetUid).update({
      'followersCount': FieldValue.increment(-1),
    });
  }

  Future<void> removeFollower({
    required String currentUid,
    required String followerUid,
  }) async {
    if (currentUid.isEmpty ||
        followerUid.isEmpty ||
        currentUid == followerUid) {
      throw ArgumentError('Invalid remove follower');
    }
    final followerRef = _firestore
        .collection(_usersCollection)
        .doc(followerUid);
    await followerRef.update({
      'following': FieldValue.arrayRemove([currentUid]),
    });
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
    await meRef.set({
      'blockedUsers': FieldValue.arrayUnion([targetUid]),
      'following': FieldValue.arrayRemove([targetUid]),
    }, SetOptions(merge: true));
  }

  Future<void> unblockUser({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid.isEmpty || targetUid.isEmpty) {
      throw ArgumentError('Invalid unblock');
    }
    final meRef = _firestore.collection(_usersCollection).doc(currentUid);
    await meRef.set({
      'blockedUsers': FieldValue.arrayRemove([targetUid]),
    }, SetOptions(merge: true));
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
      final snap = await _firestore
          .collection(_usersCollection)
          .limit(limit)
          .get();
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
      final displayName = (u.displayName ?? '').trim().isNotEmpty
          ? u.displayName!.trim()
          : username;
      out.add(
        UserDiscoveryItem(
          uid: uid,
          username: username,
          displayName: displayName,
          avatarUrl: (u.profileImage ?? '').trim(),
          isFollowing: following.contains(uid),
          followerCount: u.followersCount,
          isVerified: u.isVerified,
          accountType: u.accountType,
          vipVerified: u.vipVerified,
        ),
      );
    }
    out.sort(
      (a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()),
    );
    return out;
  }
}
