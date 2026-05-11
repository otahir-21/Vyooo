import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'username_service.dart';
import 'username_validation.dart';

/// Live username availability using `users` + `username` field (case-sensitive).
class FirestoreUsernameService implements UsernameService {
  static const Set<String> _reserved = {
    'admin',
    'vyooo',
    'test',
    'user',
    'support',
    'official',
    'help',
    'metatech',
    'api',
    'www',
    'mail',
    'root',
    'null',
    'vyoooapp',
    'system',
  };

  static List<String> _suggestionsFor(String base) {
    if (base.isEmpty) return [];
    return [
      '${base}_official',
      '${base}123',
      'the_$base',
      '${base}_app',
    ];
  }

  static UsernameCheckResult _reservedResult(String normalized) {
    return UsernameCheckResult(
      available: false,
      suggestions: _suggestionsFor(normalized),
    );
  }

  static bool _takenByOther(
    QuerySnapshot<Map<String, dynamic>> snap,
    String excludeUid,
  ) {
    for (final d in snap.docs) {
      final data = d.data();
      final docUid = (data['uid'] as String?)?.trim() ?? d.id;
      if (docUid != excludeUid) return true;
    }
    return false;
  }

  @override
  Future<UsernameCheckResult> checkAvailability(String username) async {
    final normalized = UsernameValidation.normalize(username);
    if (!UsernameValidation.shouldCheckAvailability(normalized)) {
      return const UsernameCheckResult(available: true);
    }
    if (_reserved.contains(normalized.toLowerCase())) {
      return _reservedResult(normalized);
    }
    final excludeUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: normalized)
        .limit(25)
        .get();
    final taken = _takenByOther(snap, excludeUid);
    return UsernameCheckResult(
      available: !taken,
      suggestions: taken ? _suggestionsFor(normalized) : const [],
    );
  }

  @override
  Stream<UsernameCheckResult> watchAvailability(
    String username, {
    required String excludeUid,
  }) {
    final normalized = UsernameValidation.normalize(username);
    if (!UsernameValidation.shouldCheckAvailability(normalized)) {
      return Stream.value(const UsernameCheckResult(available: true));
    }
    if (_reserved.contains(normalized.toLowerCase())) {
      return Stream.value(_reservedResult(normalized));
    }
    return FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: normalized)
        .limit(25)
        .snapshots()
        .map((snap) {
          final taken = _takenByOther(snap, excludeUid);
          return UsernameCheckResult(
            available: !taken,
            suggestions: taken ? _suggestionsFor(normalized) : const [],
          );
        });
  }
}
