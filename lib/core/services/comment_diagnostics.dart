import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Debug logging for comment / mention flows (visible in `flutter run` output).
abstract final class CommentDiagnostics {
  CommentDiagnostics._();

  static void log(String message) {
    if (kDebugMode) {
      debugPrint('[Comment] $message');
    }
  }

  static void logFailure(
    String operation,
    Object error,
    StackTrace stackTrace, {
    Map<String, Object?> extra = const {},
  }) {
    if (!kDebugMode) return;
    final details = extra.entries
        .map((e) => '${e.key}=${e.value}')
        .join(', ');
    debugPrint(
      '[Comment] $operation failed'
      '${details.isEmpty ? '' : ' ($details)'}: $error',
    );
    debugPrint(stackTrace.toString());
  }

  static void logFirestoreFailure(
    String operation,
    FirebaseException error,
    StackTrace stackTrace, {
    Map<String, Object?> extra = const {},
  }) {
    if (!kDebugMode) return;
    final details = extra.entries
        .map((e) => '${e.key}=${e.value}')
        .join(', ');
    debugPrint(
      '[Comment] $operation Firestore error'
      '${details.isEmpty ? '' : ' ($details)'}: '
      'code=${error.code}, message=${error.message}',
    );
    debugPrint(stackTrace.toString());
  }
}
