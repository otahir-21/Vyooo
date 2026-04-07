/// Single comment or reply. [replies] are nested (e.g. "View more replies (31)").
class Comment {
  const Comment({
    required this.id,
    required this.username,
    required this.avatarUrl,
    this.isVerified = false,
    required this.timeAgo,
    required this.text,
    this.likeCount = 0,
    this.isLiked = false,
    this.replyCount = 0,
    this.replies = const [],
    this.isOwnComment = false,
    this.authorUserId = '',
  });

  final String id;
  final String username;
  final String avatarUrl;
  final bool isVerified;
  final String timeAgo;
  final String text;
  final int likeCount;
  final bool isLiked;
  final int replyCount;
  final List<Comment> replies;
  /// When true, show delete (trash) icon instead of like count.
  final bool isOwnComment;

  /// Firestore [users] uid of the author — used for reports / moderation.
  final String authorUserId;

  Comment copyWith({
    String? id,
    String? username,
    String? avatarUrl,
    bool? isVerified,
    String? timeAgo,
    String? text,
    int? likeCount,
    bool? isLiked,
    int? replyCount,
    List<Comment>? replies,
    bool? isOwnComment,
    String? authorUserId,
  }) {
    return Comment(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVerified: isVerified ?? this.isVerified,
      timeAgo: timeAgo ?? this.timeAgo,
      text: text ?? this.text,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      replyCount: replyCount ?? this.replyCount,
      replies: replies ?? this.replies,
      isOwnComment: isOwnComment ?? this.isOwnComment,
      authorUserId: authorUserId ?? this.authorUserId,
    );
  }
}
