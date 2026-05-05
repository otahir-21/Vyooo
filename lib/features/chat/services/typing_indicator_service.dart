import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class TypingIndicatorService {
  TypingIndicatorService._();
  static final TypingIndicatorService instance = TypingIndicatorService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  DateTime? _lastWrite;
  static const _throttleMs = 3000;

  Future<void> setTyping({
    required String chatId,
    required String uid,
    required String displayName,
  }) async {
    if (chatId.isEmpty || uid.isEmpty) return;
    final now = DateTime.now();
    if (_lastWrite != null &&
        now.difference(_lastWrite!).inMilliseconds < _throttleMs) {
      return;
    }
    _lastWrite = now;
    try {
      await _db
          .collection('chats')
          .doc(chatId)
          .collection('typing')
          .doc(uid)
          .set({
        'uid': uid,
        'displayName': displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> clearTyping({
    required String chatId,
    required String uid,
  }) async {
    if (chatId.isEmpty || uid.isEmpty) return;
    _lastWrite = null;
    try {
      await _db
          .collection('chats')
          .doc(chatId)
          .collection('typing')
          .doc(uid)
          .delete();
    } catch (_) {}
  }

  Stream<List<Map<String, dynamic>>> watchTyping({
    required String chatId,
    required String excludeUid,
  }) {
    if (chatId.isEmpty) return Stream.value([]);
    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(seconds: 10)),
    );
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('typing')
        .where('updatedAt', isGreaterThan: cutoff)
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((d) => d.data())
              .where((data) => (data['uid'] as String?) != excludeUid)
              .toList();
        });
  }
}
