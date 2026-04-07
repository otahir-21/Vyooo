import 'package:firebase_core/firebase_core.dart';

/// Short, user-safe copy for Firestore / network failures (no raw exception text in UI).
String messageForFirestore(Object? error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return "We couldn't reach the server. Check your connection and try again.";
      case 'permission-denied':
        return "You don't have permission to do that.";
      case 'resource-exhausted':
        return 'Too many requests. Please wait a moment and try again.';
      case 'not-found':
        return 'That content is no longer available.';
      case 'aborted':
        return 'The action was cancelled. Try again.';
      default:
        break;
    }
  }
  return 'Something went wrong. Please try again.';
}
