import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../utils/hashtag_utils.dart';

/// Server-side AI hashtags via Firestore-triggered Cloud Function (see
/// [processHashtagGenerationRequest]). API keys live in Functions env only.
class HashtagGenerationService {
  HashtagGenerationService._();

  static const String _collection = 'hashtag_generation_requests';
  static const int minHashtagCount = 30;
  static const Duration _waitTimeout = Duration(seconds: 55);

  static void _log(String message, [Object? err, StackTrace? st]) {
    debugPrint('[HashtagGeneration] $message');
    if (err != null) {
      debugPrint('[HashtagGeneration] error: $err');
    }
    if (st != null) {
      debugPrint('[HashtagGeneration] stack:\n$st');
    }
  }

  /// Waits until the request doc is `done` or `error`, then returns normalized tags.
  /// Deletes the request doc in a [finally] block (best-effort).
  static Future<List<String>> generate({
    required String title,
    required String description,
    String? category,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _log('generate aborted: not signed in');
      throw StateError('You must be signed in to generate hashtags.');
    }

    DocumentReference<Map<String, dynamic>> ref;
    try {
      ref = await FirebaseFirestore.instance.collection(_collection).add({
        'userId': user.uid,
        'title': title.trim(),
        'description': description.trim(),
        'category': (category ?? '').trim(),
        'minCount': minHashtagCount,
        'status': 'pending',
      });
      _log('request doc created: ${ref.path}');
    } on FirebaseException catch (e, st) {
      _log(
        'Firestore add failed code=${e.code} message=${e.message}',
        e,
        st,
      );
      if (e.code == 'permission-denied') {
        throw Exception(
          'Firestore permission denied. Deploy firestore.rules (hashtag_generation_requests) and sign in.',
        );
      }
      throw Exception('Could not start hashtag request: ${e.message ?? e.code}');
    } catch (e, st) {
      _log('Firestore add failed (non-FirebaseException)', e, st);
      rethrow;
    }

    try {
      final snap = await ref.snapshots().firstWhere(
        (s) {
          final st = s.data()?['status'] as String?;
          return st == 'done' || st == 'error';
        },
      ).timeout(_waitTimeout);

      final data = snap.data()!;
      final st = data['status'] as String?;
      _log('request ${ref.id} status=$st');
      if (st == 'error') {
        final serverMsg = data['error'] as String? ?? 'Hashtag generation failed.';
        _log('server returned error: $serverMsg');
        throw Exception(serverMsg);
      }
      final raw = data['hashtags'];
      if (raw is! List) {
        _log('invalid hashtags field type: ${raw.runtimeType}');
        throw Exception('Invalid response from server.');
      }
      final tags = raw
          .map((e) => HashtagUtils.normalizeForQuery(e.toString()))
          .where((t) => t.isNotEmpty)
          .toList();
      _log('success, ${tags.length} tags');
      return tags;
    } on TimeoutException catch (e, st) {
      _log('timeout waiting for function', e, st);
      throw Exception('Timed out waiting for hashtags. Try again.');
    } on FirebaseException catch (e, st) {
      _log(
        'listen failed code=${e.code} message=${e.message}',
        e,
        st,
      );
      rethrow;
    } catch (e, st) {
      _log('wait/parse failed', e, st);
      rethrow;
    } finally {
      try {
        await ref.delete();
        _log('request doc deleted (cleanup)');
      } catch (e, st) {
        _log('cleanup delete failed (ignored)', e, st);
      }
    }
  }
}
