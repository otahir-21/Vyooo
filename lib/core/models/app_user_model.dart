import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore user document model. Do NOT store password.
class AppUserModel {
  const AppUserModel({
    required this.uid,
    required this.email,
    this.username,
    this.dob,
    this.profileImage,
    this.interests = const [],
    this.onboardingCompleted = false,
    required this.createdAt,
    this.following = const [],
    this.blockedUsers = const [],
    this.followersCount = 0,
  });

  final String uid;
  final String email;
  final String? username;
  final String? dob;
  final String? profileImage;
  final List<String> interests;
  final bool onboardingCompleted;
  final Timestamp createdAt;
  /// UIDs this user follows (stored on their Firestore user doc).
  final List<String> following;
  final List<String> blockedUsers;
  final int followersCount;

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'username': username ?? '',
      'dob': dob ?? '',
      'profileImage': profileImage ?? '',
      'interests': interests,
      'onboardingCompleted': onboardingCompleted,
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
      username: json['username'] as String?,
      dob: json['dob'] as String?,
      profileImage: json['profileImage'] as String?,
      interests: interestsList,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
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
    String? username,
    String? dob,
    String? profileImage,
    List<String>? interests,
    bool? onboardingCompleted,
    Timestamp? createdAt,
    List<String>? following,
    List<String>? blockedUsers,
    int? followersCount,
  }) {
    return AppUserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      dob: dob ?? this.dob,
      profileImage: profileImage ?? this.profileImage,
      interests: interests ?? this.interests,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      createdAt: createdAt ?? this.createdAt,
      following: following ?? this.following,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      followersCount: followersCount ?? this.followersCount,
    );
  }
}
