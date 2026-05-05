class ChatParticipant {
  const ChatParticipant({
    required this.uid,
    this.displayName = '',
    this.username = '',
    this.avatarUrl = '',
    this.role = 'member',
  });

  final String uid;
  final String displayName;
  final String username;
  final String avatarUrl;
  final String role;

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      uid: json['uid'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      username: json['username'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'displayName': displayName,
      'username': username,
      'avatarUrl': avatarUrl,
      'role': role,
    };
  }

  ChatParticipant copyWith({
    String? uid,
    String? displayName,
    String? username,
    String? avatarUrl,
    String? role,
  }) {
    return ChatParticipant(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
    );
  }
}