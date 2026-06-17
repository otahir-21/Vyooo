/// Thrown when a comment cannot be posted (validation / auth).
class CommentPostException implements Exception {
  const CommentPostException(this.message);

  final String message;

  @override
  String toString() => message;
}
