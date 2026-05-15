import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/notification_preferences.dart';
import 'auth_service.dart';

/// Reads/writes `users/{uid}/settings/notifications`.
class NotificationPreferencesService {
  NotificationPreferencesService._();
  static final NotificationPreferencesService instance =
      NotificationPreferencesService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>>? _docRef(String uid) {
    if (uid.isEmpty) return null;
    return _db
        .collection('users')
        .doc(uid)
        .collection(NotificationPreferences.collectionName)
        .doc(NotificationPreferences.firestoreDocId);
  }

  String? get _uid => AuthService().currentUser?.uid;

  Stream<NotificationPreferences> watchForCurrentUser() {
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      final uid = user?.uid ?? '';
      if (uid.isEmpty) {
        return Stream.value(const NotificationPreferences());
      }
      final ref = _docRef(uid);
      if (ref == null) {
        return Stream.value(const NotificationPreferences());
      }
      return ref.snapshots().map(
            (snap) => NotificationPreferences.fromMap(snap.data()),
          );
    });
  }

  Future<NotificationPreferences> getForCurrentUser() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      return const NotificationPreferences();
    }
    final ref = _docRef(uid);
    if (ref == null) return const NotificationPreferences();
    final snap = await ref.get();
    return NotificationPreferences.fromMap(snap.data());
  }

  Future<void> save(NotificationPreferences prefs) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    final ref = _docRef(uid);
    if (ref == null) return;
    await ref.set(prefs.toMap(), SetOptions(merge: true));
  }
}
