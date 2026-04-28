import 'package:cloud_firestore/cloud_firestore.dart';

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
    this.accountType = 'personal',
    this.vipVerified = false,
    this.orgProfileCompleted = false,
    this.organizationDetails = const {},
    required this.createdAt,
    this.following = const [],
    this.blockedUsers = const [],
    this.followersCount = 0,
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
  final bool vipVerified;
  final bool orgProfileCompleted;
  final Map<String, dynamic> organizationDetails;
  final Timestamp createdAt;
  /// UIDs this user follows (stored on their Firestore user doc).
  final List<String> following;
  final List<String> blockedUsers;
  final int followersCount;

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
      'vipVerified': vipVerified,
      'orgProfileCompleted': orgProfileCompleted,
      'organizationDetails': organizationDetails,
      'createdAt': createdAt,
      'following': following,
      'blockedUsers': blockedUsers,
      'followersCount': followersCount,
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
      accountType: json['accountType'] as String? ?? 'personal',
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
    bool? vipVerified,
    bool? orgProfileCompleted,
    Map<String, dynamic>? organizationDetails,
    Timestamp? createdAt,
    List<String>? following,
    List<String>? blockedUsers,
    int? followersCount,
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
      vipVerified: vipVerified ?? this.vipVerified,
      orgProfileCompleted: orgProfileCompleted ?? this.orgProfileCompleted,
      organizationDetails: organizationDetails ?? this.organizationDetails,
      createdAt: createdAt ?? this.createdAt,
      following: following ?? this.following,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      followersCount: followersCount ?? this.followersCount,
    );
  }
}
