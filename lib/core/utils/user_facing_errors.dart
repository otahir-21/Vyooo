import 'package:firebase_core/firebase_core.dart';

import 'internet_availability.dart';

/// True when [error] usually means the device cannot reach the network or DNS failed.
bool looksLikeOfflineOrTransportError(Object? error) {
  if (error == null) return false;
  if (error is FirebaseException) {
    final c = error.code.toLowerCase();
    if (c == 'unavailable' || c == 'deadline-exceeded') {
      return true;
    }
  }
  final t = error.toString().toLowerCase();
  return t.contains('socketexception') ||
      t.contains('failed host lookup') ||
      t.contains('network is unreachable') ||
      t.contains('connection refused') ||
      t.contains('connection reset') ||
      t.contains('connection timed out') ||
      t.contains('timed out waiting') ||
      t.contains('clientexception') ||
      t.contains('handshakeexception') ||
      t.contains('failed to connect') ||
      (t.contains('host lookup failed') && t.contains('os error'));
}

/// Short, user-safe copy for Firestore / network failures (no raw exception text in UI).
String messageForFirestore(Object? error) {
  if (looksLikeOfflineOrTransportError(error)) {
    return kNoInternetUserMessage;
  }
  if (error is FirebaseException) {
    switch (error.code) {
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
