import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../services/username_validation.dart';
import 'auth_service.dart';
import '../models/app_user_model.dart';
import '../models/parent_consent_constants.dart';
import '../models/post_location_model.dart';
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
    this.monetizationEnabled = false,
    this.outgoingFollowRequestPending = false,
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
  final bool monetizationEnabled;
  /// True when [accountType] is private and we sent a follow request not yet accepted.
  final bool outgoingFollowRequestPending;
}

/// Outcome of submitting a report against a user profile.
enum UserReportResult { success, alreadyReported, notSignedIn, failed }

/// Firestore user document operations. No UI, no BuildContext.
/// Call createUserDocument AFTER successful registration.
class UserService {
  UserService._();
  static final UserService _instance = UserService._();
  factory UserService() => _instance;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static const String _usersCollection = 'users';
  static const String _followRequestsCollection = 'follow_requests';

  /// Materialized edge written by Cloud Function when a private follow is accepted.
  /// Same doc id as [follow_requests] for that pair; gives requesters a reliable listener
  /// independent of `users/{uid}.following` cache timing.
  static const String followEdgesCollection = 'follow_edges';

  /// Firestore doc id for [follow_requests] (requester first).
  static String followRequestDocId(String requesterUid, String targetUid) =>
      '${requesterUid}_$targetUid';

  /// Private accounts require an accepted follow request before content is visible.
  /// Treat legacy [personal] the same as [private] for client UX when payloads omit Firestore.
  static bool accountTypeRequiresFollowApproval(String? accountType) {
    final t = (accountType ?? 'private').trim().toLowerCase();
    return t == 'private' || t == 'personal';
  }

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
    'monetizationEnabled': false,
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
    'locationSetupComplete': false,
    'profileImageSetupComplete': false,
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

  /// Merges [patch] into the user's existing [organizationDetails] map.
  Future<void> patchOrganizationDetails({
    required String uid,
    required Map<String, dynamic> patch,
  }) async {
    final snap = await _firestore.collection(_usersCollection).doc(uid).get();
    final raw = snap.data()?['organizationDetails'];
    final base = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    base.addAll(patch);
    await updateUserProfile(uid: uid, organizationDetails: base);
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
    PostLocation? profileLocation,
    bool? locationSetupComplete,
    bool? profileImageSetupComplete,
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
      if (profileLocation != null) {
        data['location'] = profileLocation.toMap();
      }
      if (locationSetupComplete != null) {
        data['locationSetupComplete'] = locationSetupComplete;
      }
      if (profileImageSetupComplete != null) {
        data['profileImageSetupComplete'] = profileImageSetupComplete;
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
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[UserService] getUserByUsername($key) failed: $e\n$st');
      }
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
              .trim()
              .toLowerCase();
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
            (byDisplayName.docs.first.data()['email'] as String? ?? '')
                .trim()
                .toLowerCase();
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
        final email = (data['email'] as String? ?? '').trim().toLowerCase();
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
            .trim()
            .toLowerCase();
        if (email.isNotEmpty) return email;
      }
      final byRaw = await _firestore
          .collection(_usersCollection)
          .where('phoneNumber', isEqualTo: phoneNumber.trim())
          .limit(1)
          .get();
      if (byRaw.docs.isNotEmpty) {
        final email = (byRaw.docs.first.data()['email'] as String? ?? '')
            .trim()
            .toLowerCase();
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
  ///
  /// Set [server] to true after follow/accept flows to avoid a stale local cache read.
  Future<List<String>> getFollowing(String uid, {bool server = false}) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get(
            GetOptions(
              source: server ? Source.server : Source.serverAndCache,
            ),
          );
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
    bool server = false,
  }) async {
    final list = await getFollowing(currentUid, server: server);
    return list.contains(targetUid);
  }

  Future<bool> isUserBlocked({
    required String currentUid,
    required String targetUid,
  }) async {
    final blocked = await getBlockedUserIds(currentUid);
    return blocked.contains(targetUid);
  }

  /// True while a follow request doc exists for this pair and the owner has not
  /// finished the flow (CF still may be applying `following` + [follow_edges]).
  ///
  /// Includes [status] `accepted`: the accepter's client sets that before the
  /// Cloud Function deletes the doc; treating only `pending` as outstanding
  /// caused a race where the requester briefly saw **Follow** instead of
  /// **Requested**/**Following**.
  Future<bool> outgoingFollowRequestPending({
    required String requesterUid,
    required String targetUid,
    bool server = false,
  }) async {
    if (requesterUid.isEmpty || targetUid.isEmpty) return false;
    try {
      final snap = await _firestore
          .collection(_followRequestsCollection)
          .doc(followRequestDocId(requesterUid, targetUid))
          .get(
            GetOptions(
              source: server ? Source.server : Source.serverAndCache,
            ),
          );
      if (!snap.exists) return false;
      final st = (snap.data()?['status'] as String?)?.trim() ?? '';
      return st == 'pending' || st == 'accepted';
    } catch (_) {
      return false;
    }
  }

  /// Server-owned doc: exists with `active: true` after a private follow is accepted.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchFollowEdgeDoc({
    required String requesterUid,
    required String targetUid,
  }) {
    if (requesterUid.isEmpty || targetUid.isEmpty) {
      return const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();
    }
    return _firestore
        .collection(followEdgesCollection)
        .doc(followRequestDocId(requesterUid, targetUid))
        .snapshots();
  }

  /// One-shot read for refresh logic; pairs with [isFollowingUser] to avoid races
  /// after accept (see [outgoingFollowRequestPending]).
  Future<bool> isFollowEdgeActive({
    required String requesterUid,
    required String targetUid,
    bool server = false,
  }) async {
    if (requesterUid.isEmpty || targetUid.isEmpty) return false;
    try {
      final snap = await _firestore
          .collection(followEdgesCollection)
          .doc(followRequestDocId(requesterUid, targetUid))
          .get(
            GetOptions(
              source: server ? Source.server : Source.serverAndCache,
            ),
          );
      if (!snap.exists) return false;
      final d = snap.data();
      return d != null && (d['active'] as bool? ?? true);
    } catch (_) {
      return false;
    }
  }

  Stream<bool> watchOutgoingFollowRequestPending({
    required String requesterUid,
    required String targetUid,
  }) {
    if (requesterUid.isEmpty || targetUid.isEmpty) {
      return Stream<bool>.value(false);
    }
    return _firestore
        .collection(_followRequestsCollection)
        .doc(followRequestDocId(requesterUid, targetUid))
        .snapshots()
        .map((s) {
          if (!s.exists) return false;
          final st = (s.data()?['status'] as String?)?.trim() ?? '';
          return st == 'pending' || st == 'accepted';
        });
  }

  /// Cancels a pending follow request (no-op if missing).
  Future<void> cancelFollowRequest({
    required String requesterUid,
    required String targetUid,
  }) async {
    if (requesterUid.isEmpty || targetUid.isEmpty) return;
    try {
      await _firestore
          .collection(_followRequestsCollection)
          .doc(followRequestDocId(requesterUid, targetUid))
          .delete();
    } catch (_) {}
  }

  /// Private-account owner accepts [requesterUid]. Cloud Function adds the follow edge.
  Future<void> acceptFollowRequest({
    required String ownerUid,
    required String requesterUid,
  }) async {
    if (ownerUid.isEmpty || requesterUid.isEmpty || ownerUid == requesterUid) {
      throw ArgumentError('Invalid accept');
    }
    final ref = _firestore
        .collection(_followRequestsCollection)
        .doc(followRequestDocId(requesterUid, ownerUid));
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data() ?? {};
    if ((data['targetUid'] as String?) != ownerUid) {
      throw StateError('Not your follow request');
    }
    if ((data['status'] as String?)?.trim() != 'pending') return;
    await ref.update({
      'status': 'accepted',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Private-account owner declines; requester can send again later.
  Future<void> declineFollowRequest({
    required String ownerUid,
    required String requesterUid,
  }) async {
    if (ownerUid.isEmpty || requesterUid.isEmpty) return;
    final ref = _firestore
        .collection(_followRequestsCollection)
        .doc(followRequestDocId(requesterUid, ownerUid));
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data() ?? {};
    if ((data['targetUid'] as String?) != ownerUid) {
      throw StateError('Not your follow request');
    }
    await ref.delete();
  }

  /// Creates a follow request for a private profile (no-op if already following or pending).
  Future<void> sendFollowRequest({
    required String requesterUid,
    required String targetUid,
  }) async {
    if (requesterUid.isEmpty || targetUid.isEmpty || requesterUid == targetUid) {
      throw ArgumentError('Invalid follow request');
    }
    final target = await getUser(targetUid);
    if (target == null) {
      throw StateError('User not found');
    }
    if (!accountTypeRequiresFollowApproval(target.accountType)) {
      await followUser(currentUid: requesterUid, targetUid: targetUid);
      return;
    }
    if (await isFollowingUser(currentUid: requesterUid, targetUid: targetUid)) {
      return;
    }
    if (await isUserBlocked(currentUid: requesterUid, targetUid: targetUid) ||
        await isUserBlocked(currentUid: targetUid, targetUid: requesterUid)) {
      throw StateError('Cannot send follow request');
    }
    final id = followRequestDocId(requesterUid, targetUid);
    final ref = _firestore.collection(_followRequestsCollection).doc(id);
    final existing = await ref.get();
    if (existing.exists) {
      final st = (existing.data()?['status'] as String?)?.trim() ?? '';
      if (st == 'pending') return;
      // Accepted/declined/stale docs: requester cannot client-update (rules only
      // allow target to patch status). Re-check follow, then delete so a clean
      // create is allowed — avoids permission-denied on blind .set().
      if (await isFollowingUser(currentUid: requesterUid, targetUid: targetUid)) {
        return;
      }
      try {
        await ref.delete();
      } catch (_) {
        return;
      }
    }
    await ref.set({
      'requesterUid': requesterUid,
      'targetUid': targetUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await NotificationService().create(
      recipientId: targetUid,
      type: AppNotificationType.followRequest,
      message: 'requested to follow you.',
      extra: {'targetUserId': targetUid},
    );
  }

  /// Adds [targetUid] to users/{currentUid}.following for public (and non-private) accounts,
  /// or sends a follow request when the target is [private].
  ///
  /// [followersCount] is maintained by [syncFollowersCountOnFollowingChange] (Cloud Function).
  Future<void> followUser({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid.isEmpty || targetUid.isEmpty || currentUid == targetUid) {
      throw ArgumentError('Invalid follow');
    }
    final target = await getUser(targetUid);
    if (target == null) {
      throw StateError('User not found');
    }
    if (accountTypeRequiresFollowApproval(target.accountType)) {
      await sendFollowRequest(requesterUid: currentUid, targetUid: targetUid);
      return;
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
    await cancelFollowRequest(requesterUid: currentUid, targetUid: targetUid);
    final meRef = _firestore.collection(_usersCollection).doc(currentUid);
    final edgeRef = _firestore
        .collection(followEdgesCollection)
        .doc(followRequestDocId(currentUid, targetUid));
    final batch = _firestore.batch();
    batch.set(
      meRef,
      {'following': FieldValue.arrayRemove([targetUid])},
      SetOptions(merge: true),
    );
    batch.delete(edgeRef);
    await batch.commit();
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

  /// Submit a user report against a profile.
  ///
  /// Uses a deterministic document id (`<reporterUid>_<reportedUserId>`) so a
  /// given user can only report a given profile once.
  Future<UserReportResult> reportUser({
    required String reportedUserId,
    required String reason,
  }) async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null || uid.isEmpty) return UserReportResult.notSignedIn;
    final target = reportedUserId.trim();
    if (target.isEmpty || target == uid) return UserReportResult.failed;
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) return UserReportResult.failed;
    try {
      final docRef =
          _firestore.collection('user_reports').doc('${uid}_$target');
      final existing = await docRef.get();
      if (existing.exists) return UserReportResult.alreadyReported;
      await docRef.set({
        'reportedUserId': target,
        'reporterId': uid,
        'reason': trimmedReason,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return UserReportResult.success;
    } catch (_) {
      return UserReportResult.failed;
    }
  }

  /// Blocks [targetUid]: adds to blockedUsers and removes from following (local doc only).
  /// When [reason] is provided, also records the block reason in `user_blocks`.
  Future<void> blockUser({
    required String currentUid,
    required String targetUid,
    String? reason,
  }) async {
    if (currentUid.isEmpty || targetUid.isEmpty || currentUid == targetUid) {
      throw ArgumentError('Invalid block');
    }
    final meRef = _firestore.collection(_usersCollection).doc(currentUid);
    await cancelFollowRequest(requesterUid: currentUid, targetUid: targetUid);

    final trimmedReason = reason?.trim() ?? '';
    final batch = _firestore.batch();
    batch.set(
      meRef,
      {
        'blockedUsers': FieldValue.arrayUnion([targetUid]),
        'following': FieldValue.arrayRemove([targetUid]),
      },
      SetOptions(merge: true),
    );
    if (trimmedReason.isNotEmpty) {
      batch.set(
        _firestore.collection('user_blocks').doc('${currentUid}_$targetUid'),
        {
          'blockedUserId': targetUid,
          'blockerId': currentUid,
          'reason': trimmedReason,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    }
    await batch.commit();
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
    await _firestore
        .collection('user_blocks')
        .doc('${currentUid}_$targetUid')
        .delete();
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

  /// [uid] -> [accountType] for feed privacy filtering (batched reads).
  Future<Map<String, String>> getAccountTypesByIds(Iterable<String> uids) async {
    final users = await getUsersByIds(uids.where((e) => e.trim().isNotEmpty).toSet().toList());
    return {for (final u in users) u.uid: u.accountType};
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
        final displayName = (model.displayName ?? '').trim().toLowerCase();
        final emailName = model.email.split('@').first.toLowerCase();
        final searchable = '$name $displayName $emailName';
        if (q.isNotEmpty && !searchable.contains(q)) continue;
        out.add(model.copyWith(uid: uid));
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  bool _userMatchesMentionQuery(AppUserModel user, String queryLower) {
    if (queryLower.isEmpty) return true;
    final username = (user.username ?? '').trim().toLowerCase();
    final displayName = (user.displayName ?? '').trim().toLowerCase();
    if (username.startsWith(queryLower) || displayName.startsWith(queryLower)) {
      return true;
    }
    return username.contains(queryLower) || displayName.contains(queryLower);
  }

  UserDiscoveryItem _discoveryItemFromUser(
    AppUserModel user, {
    required Set<String> following,
    bool outgoingFollowRequestPending = false,
  }) {
    final uid = user.uid;
    final username = (user.username ?? '').trim().isNotEmpty
        ? user.username!.trim()
        : (user.email.contains('@') ? user.email.split('@').first : uid);
    final displayName = (user.displayName ?? '').trim().isNotEmpty
        ? user.displayName!.trim()
        : username;
    return UserDiscoveryItem(
      uid: uid,
      username: username,
      displayName: displayName,
      avatarUrl: (user.profileImage ?? '').trim(),
      isFollowing: following.contains(uid),
      followerCount: user.followersCount,
      isVerified: user.isVerified,
      accountType: user.accountType,
      vipVerified: user.vipVerified,
      monetizationEnabled: user.monetizationEnabled,
      outgoingFollowRequestPending: outgoingFollowRequestPending,
    );
  }

  /// Mention autocomplete: following first, then username prefix query.
  Future<List<UserDiscoveryItem>> searchUsersForMention({
    required String currentUid,
    String query = '',
    int limit = 8,
  }) async {
    if (currentUid.isEmpty) return const [];
    final q = query.trim().toLowerCase();
    final blocked = await getBlockedUserIds(currentUid);
    final following = await getFollowing(currentUid);
    final followingSet = following.toSet();

    final models = <AppUserModel>[];
    final seen = <String>{};

    void tryAdd(AppUserModel user) {
      final uid = user.uid.trim().isNotEmpty ? user.uid.trim() : '';
      if (uid.isEmpty ||
          uid == currentUid ||
          blocked.contains(uid) ||
          seen.contains(uid)) {
        return;
      }
      if (!_userMatchesMentionQuery(user, q)) return;
      seen.add(uid);
      models.add(user);
    }

    if (following.isNotEmpty) {
      final followingUsers = await getUsersByIds(following);
      followingUsers.sort(
        (a, b) => (a.username ?? '').toLowerCase().compareTo(
          (b.username ?? '').toLowerCase(),
        ),
      );
      for (final user in followingUsers) {
        tryAdd(user);
        if (models.length >= limit) break;
      }
    }

    if (models.length < limit && q.isNotEmpty) {
      final normalized = UsernameValidation.normalize(q);
      if (normalized.isNotEmpty) {
        try {
          final snap = await _firestore
              .collection(_usersCollection)
              .where('username', isGreaterThanOrEqualTo: normalized)
              .where('username', isLessThanOrEqualTo: '$normalized\uf8ff')
              .limit(limit)
              .get();
          for (final doc in snap.docs) {
            final data = doc.data();
            final uid = (data['uid'] as String?)?.trim().isNotEmpty == true
                ? (data['uid'] as String).trim()
                : doc.id;
            tryAdd(AppUserModel.fromJson(data).copyWith(uid: uid));
            if (models.length >= limit) break;
          }
        } catch (e, st) {
          if (kDebugMode) {
            debugPrint(
              '[UserService] mention username prefix search failed: $e\n$st',
            );
          }
        }
      }
    }

    if (models.length < limit) {
      final extra = await discoverUsers(
        currentUid: currentUid,
        query: q,
        excludeIds: blocked.toSet(),
        limit: 80,
      );
      for (final user in extra) {
        tryAdd(user);
        if (models.length >= limit) break;
      }
    }

    models.sort((a, b) {
      final aFollow = followingSet.contains(a.uid);
      final bFollow = followingSet.contains(b.uid);
      if (aFollow != bFollow) return aFollow ? -1 : 1;
      return (a.username ?? '').toLowerCase().compareTo(
        (b.username ?? '').toLowerCase(),
      );
    });

    return models
        .take(limit)
        .map(
          (user) => _discoveryItemFromUser(
            user,
            following: followingSet,
          ),
        )
        .toList();
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
    final pendingChecks = <Future<void>>[];
    final pendingByUid = <String, bool>{};
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
      final isFollowing = following.contains(uid);
      if (!isFollowing && accountTypeRequiresFollowApproval(u.accountType)) {
        pendingChecks.add(
          outgoingFollowRequestPending(
            requesterUid: currentUid,
            targetUid: uid,
          ).then((p) {
            pendingByUid[uid] = p;
          }),
        );
      }
      out.add(
        UserDiscoveryItem(
          uid: uid,
          username: username,
          displayName: displayName,
          avatarUrl: (u.profileImage ?? '').trim(),
          isFollowing: isFollowing,
          followerCount: u.followersCount,
          isVerified: u.isVerified,
          accountType: u.accountType,
          vipVerified: u.vipVerified,
          monetizationEnabled: u.monetizationEnabled,
          outgoingFollowRequestPending: false,
        ),
      );
    }
    if (pendingChecks.isNotEmpty) {
      await Future.wait(pendingChecks);
      for (var i = 0; i < out.length; i++) {
        final item = out[i];
        if (!item.isFollowing &&
            accountTypeRequiresFollowApproval(item.accountType)) {
          final p = pendingByUid[item.uid] ?? false;
          out[i] = UserDiscoveryItem(
            uid: item.uid,
            username: item.username,
            displayName: item.displayName,
            avatarUrl: item.avatarUrl,
            isFollowing: item.isFollowing,
            followerCount: item.followerCount,
            isVerified: item.isVerified,
            accountType: item.accountType,
            vipVerified: item.vipVerified,
            monetizationEnabled: item.monetizationEnabled,
            outgoingFollowRequestPending: p,
          );
        }
      }
    }
    out.sort(
      (a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()),
    );
    return out;
  }
}
