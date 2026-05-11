import 'package:cloud_firestore/cloud_firestore.dart';

import 'parent_consent_constants.dart';

String _readFirestoreString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

String? _readFirestoreStringNullable(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  final s = value.toString();
  return s.isEmpty ? null : s;
}

bool _readFirestoreBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final t = value.trim().toLowerCase();
    return t == 'true' || t == '1' || t == 'yes';
  }
  return fallback;
}

int _readFirestoreInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

/// Firestore auto-ids never contain spaces; strip accidental whitespace from bad data.
String _sanitizeParentConsentId(String raw) {
  return raw.replaceAll(RegExp(r'\s+'), '');
}

/// Firestore user document model. Do NOT store password.
class AppUserModel {
  const AppUserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.username,
    this.bio,
    this.dob,
    this.profileImage,
    this.phoneNumber,
    this.interests = const [],
    this.onboardingCompleted = false,
    this.emailOtpVerified = true,
    this.isVerified = false,
    this.verificationStatus = 'none',
    this.accountType = 'private',
    this.publicPersona = '',
    this.vipVerified = false,
    this.orgProfileCompleted = false,
    this.organizationDetails = const {},
    required this.createdAt,
    this.following = const [],
    this.blockedUsers = const [],
    this.followersCount = 0,
    this.parentConsentStatus = ParentConsentStatusValue.notRequired,
    this.parentConsentId = '',
    this.parentUid = '',
    this.parentInviteEmail = '',
    this.parentInvitePhone = '',
    this.parentConsentAt,
  });

  final String uid;
  final String email;
  final String? displayName;
  final String? username;
  final String? bio;
  final String? dob;
  final String? profileImage;
  final String? phoneNumber;
  final List<String> interests;
  final bool onboardingCompleted;
  /// False until email OTP is confirmed (email/password signups). Missing in Firestore = treated verified (legacy).
  final bool emailOtpVerified;
  final bool isVerified;
  final String verificationStatus;
  final String accountType;
  /// Free-text label for [accountType] `public` (e.g. creator, entrepreneur).
  final String publicPersona;
  final bool vipVerified;
  final bool orgProfileCompleted;
  final Map<String, dynamic> organizationDetails;
  final Timestamp createdAt;
  /// UIDs this user follows (stored on their Firestore user doc).
  final List<String> following;
  final List<String> blockedUsers;
  final int followersCount;

  /// Parental gate for users under 16. See [ParentConsentStatusValue].
  final String parentConsentStatus;

  /// Active `parental_consents/{id}` document id when status is pending or denied.
  final String parentConsentId;

  /// Firebase uid of the approving parent/guardian after approval.
  final String parentUid;

  /// Parent contact used for the invite (lowercase email or normalized phone).
  final String parentInviteEmail;
  final String parentInvitePhone;

  /// When parental consent was granted or denied.
  final Timestamp? parentConsentAt;

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName ?? '',
      'username': username ?? '',
      'bio': bio ?? '',
      'dob': dob ?? '',
      'profileImage': profileImage ?? '',
      'phoneNumber': phoneNumber ?? '',
      'interests': interests,
      'onboardingCompleted': onboardingCompleted,
      'emailOtpVerified': emailOtpVerified,
      'isVerified': isVerified,
      'verificationStatus': verificationStatus,
      'accountType': accountType,
      'publicPersona': publicPersona,
      'vipVerified': vipVerified,
      'orgProfileCompleted': orgProfileCompleted,
      'organizationDetails': organizationDetails,
      'createdAt': createdAt,
      'following': following,
      'blockedUsers': blockedUsers,
      'followersCount': followersCount,
      'parentConsentStatus': parentConsentStatus,
      'parentConsentId': parentConsentId,
      'parentUid': parentUid,
      'parentInviteEmail': parentInviteEmail,
      'parentInvitePhone': parentInvitePhone,
      if (parentConsentAt != null) 'parentConsentAt': parentConsentAt,
    };
  }

  factory AppUserModel.fromJson(Map<String, dynamic> json) {
    final interestsRaw = json['interests'];
    final interestsList = interestsRaw is List
        ? (interestsRaw).map((e) => e.toString()).toList()
        : <String>[];

    List<String> listField(String key) {
      final raw = json[key];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return [];
    }

    final orgJson = json['organizationDetails'];
    final org = orgJson is Map<String, dynamic>
        ? Map<String, dynamic>.from(orgJson)
        : <String, dynamic>{};

    /// Some legacy / hand-edited docs stored parental fields under [organizationDetails]
    /// instead of top-level keys. Prefer top-level when present.
    String parentString(String key) {
      final top = _readFirestoreString(json[key]).trim();
      if (top.isNotEmpty) return top;
      return _readFirestoreString(org[key]).trim();
    }

    final fromTopStatus = _readFirestoreStringNullable(
      json['parentConsentStatus'],
    )?.trim();
    final parentStatusRaw = (fromTopStatus != null && fromTopStatus.isNotEmpty)
        ? fromTopStatus
        : _readFirestoreStringNullable(org['parentConsentStatus'])?.trim();

    Timestamp? parentConsentAtField() {
      if (json['parentConsentAt'] is Timestamp) {
        return json['parentConsentAt'] as Timestamp;
      }
      if (org['parentConsentAt'] is Timestamp) {
        return org['parentConsentAt'] as Timestamp;
      }
      return null;
    }

    return AppUserModel(
      uid: _readFirestoreString(json['uid']),
      email: _readFirestoreString(json['email']),
      displayName: _readFirestoreStringNullable(json['displayName']),
      username: _readFirestoreStringNullable(json['username']),
      bio: _readFirestoreStringNullable(json['bio']),
      dob: _readFirestoreStringNullable(json['dob']),
      profileImage: _readFirestoreStringNullable(json['profileImage']),
      phoneNumber: _readFirestoreStringNullable(json['phoneNumber']),
      interests: interestsList,
      onboardingCompleted: _readFirestoreBool(
        json['onboardingCompleted'],
        fallback: false,
      ),
      emailOtpVerified: _readFirestoreBool(
        json['emailOtpVerified'],
        fallback: true,
      ),
      isVerified: _readFirestoreBool(json['isVerified'], fallback: false),
      verificationStatus:
          _readFirestoreString(json['verificationStatus'], fallback: 'none'),
      accountType:
          _readFirestoreString(json['accountType'], fallback: 'private'),
      publicPersona:
          _readFirestoreString(json['publicPersona']).trim(),
      vipVerified: _readFirestoreBool(json['vipVerified'], fallback: false),
      orgProfileCompleted: _readFirestoreBool(
        json['orgProfileCompleted'],
        fallback: false,
      ),
      organizationDetails: org,
      createdAt: json['createdAt'] is Timestamp
          ? json['createdAt'] as Timestamp
          : Timestamp.now(),
      following: listField('following'),
      blockedUsers: listField('blockedUsers'),
      followersCount: _readFirestoreInt(json['followersCount']),
      parentConsentStatus: parentStatusRaw != null && parentStatusRaw.isNotEmpty
          ? parentStatusRaw
          : ParentConsentStatusValue.notRequired,
      parentConsentId: _sanitizeParentConsentId(parentString('parentConsentId')),
      parentUid: parentString('parentUid'),
      parentInviteEmail: parentString('parentInviteEmail'),
      parentInvitePhone: parentString('parentInvitePhone'),
      parentConsentAt: parentConsentAtField(),
    );
  }

  AppUserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? username,
    String? bio,
    String? dob,
    String? profileImage,
    String? phoneNumber,
    List<String>? interests,
    bool? onboardingCompleted,
    bool? emailOtpVerified,
    bool? isVerified,
    String? verificationStatus,
    String? accountType,
    String? publicPersona,
    bool? vipVerified,
    bool? orgProfileCompleted,
    Map<String, dynamic>? organizationDetails,
    Timestamp? createdAt,
    List<String>? following,
    List<String>? blockedUsers,
    int? followersCount,
    String? parentConsentStatus,
    String? parentConsentId,
    String? parentUid,
    String? parentInviteEmail,
    String? parentInvitePhone,
    Timestamp? parentConsentAt,
  }) {
    return AppUserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      dob: dob ?? this.dob,
      profileImage: profileImage ?? this.profileImage,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      interests: interests ?? this.interests,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      emailOtpVerified: emailOtpVerified ?? this.emailOtpVerified,
      isVerified: isVerified ?? this.isVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      accountType: accountType ?? this.accountType,
      publicPersona: publicPersona ?? this.publicPersona,
      vipVerified: vipVerified ?? this.vipVerified,
      orgProfileCompleted: orgProfileCompleted ?? this.orgProfileCompleted,
      organizationDetails: organizationDetails ?? this.organizationDetails,
      createdAt: createdAt ?? this.createdAt,
      following: following ?? this.following,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      followersCount: followersCount ?? this.followersCount,
      parentConsentStatus: parentConsentStatus ?? this.parentConsentStatus,
      parentConsentId: parentConsentId ?? this.parentConsentId,
      parentUid: parentUid ?? this.parentUid,
      parentInviteEmail: parentInviteEmail ?? this.parentInviteEmail,
      parentInvitePhone: parentInvitePhone ?? this.parentInvitePhone,
      parentConsentAt: parentConsentAt ?? this.parentConsentAt,
    );
  }
}
