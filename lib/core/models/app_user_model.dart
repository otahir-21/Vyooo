import 'package:cloud_firestore/cloud_firestore.dart';

import 'parent_consent_constants.dart';

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

    return AppUserModel(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String?,
      username: json['username'] as String?,
      bio: json['bio'] as String?,
      dob: json['dob'] as String?,
      profileImage: json['profileImage'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      interests: interestsList,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      emailOtpVerified: json['emailOtpVerified'] as bool? ?? true,
      isVerified: json['isVerified'] as bool? ?? false,
      verificationStatus: json['verificationStatus'] as String? ?? 'none',
      accountType: json['accountType'] as String? ?? 'private',
      publicPersona: (json['publicPersona'] as String?)?.trim() ?? '',
      vipVerified: json['vipVerified'] as bool? ?? false,
      orgProfileCompleted: json['orgProfileCompleted'] as bool? ?? false,
      organizationDetails: json['organizationDetails'] is Map<String, dynamic>
          ? (json['organizationDetails'] as Map<String, dynamic>)
          : <String, dynamic>{},
      createdAt: json['createdAt'] is Timestamp
          ? json['createdAt'] as Timestamp
          : Timestamp.now(),
      following: listField('following'),
      blockedUsers: listField('blockedUsers'),
      followersCount: (json['followersCount'] as num?)?.toInt() ?? 0,
      parentConsentStatus:
          (json['parentConsentStatus'] as String?)?.trim().isNotEmpty == true
          ? (json['parentConsentStatus'] as String).trim()
          : ParentConsentStatusValue.notRequired,
      parentConsentId: (json['parentConsentId'] as String?)?.trim() ?? '',
      parentUid: (json['parentUid'] as String?)?.trim() ?? '',
      parentInviteEmail: (json['parentInviteEmail'] as String?)?.trim() ?? '',
      parentInvitePhone: (json['parentInvitePhone'] as String?)?.trim() ?? '',
      parentConsentAt: json['parentConsentAt'] is Timestamp
          ? json['parentConsentAt'] as Timestamp
          : null,
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
