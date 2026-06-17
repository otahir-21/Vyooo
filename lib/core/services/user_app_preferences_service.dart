import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_app_preferences.dart';
import 'auth_service.dart';

/// Reads/writes `users/{uid}/settings/app`.
class UserAppPreferencesService {
  UserAppPreferencesService._();
  static final UserAppPreferencesService instance =
      UserAppPreferencesService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>>? _docRef(String uid) {
    if (uid.isEmpty) return null;
    return _db
        .collection('users')
        .doc(uid)
        .collection(UserAppPreferences.collectionName)
        .doc(UserAppPreferences.firestoreDocId);
  }

  String? get _uid => AuthService().currentUser?.uid;

  Stream<UserAppPreferences> watchForCurrentUser() {
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      final uid = user?.uid ?? '';
      if (uid.isEmpty) {
        return Stream.value(const UserAppPreferences());
      }
      final ref = _docRef(uid);
      if (ref == null) {
        return Stream.value(const UserAppPreferences());
      }
      return ref.snapshots().map(
            (snap) => UserAppPreferences.fromMap(snap.data()),
          );
    });
  }

  Future<UserAppPreferences> getForCurrentUser() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      return const UserAppPreferences();
    }
    final prefs = await getForUser(uid);
    await _mirrorAllowTagsFrom(uid, prefs.allowTagsFrom);
    return prefs;
  }

  Future<UserAppPreferences> getForUser(String uid) async {
    if (uid.isEmpty) return const UserAppPreferences();
    final ref = _docRef(uid);
    if (ref == null) return const UserAppPreferences();
    final snap = await ref.get();
    return UserAppPreferences.fromMap(snap.data());
  }

  Future<void> save(UserAppPreferences prefs) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    final ref = _docRef(uid);
    if (ref == null) return;
    await ref.set(prefs.toMap(), SetOptions(merge: true));
    await _mirrorAllowTagsFrom(uid, prefs.allowTagsFrom);
  }

  /// Public copy on `users/{uid}` for mention privacy checks by other clients.
  Future<void> _mirrorAllowTagsFrom(String uid, String allowTagsFrom) async {
    if (uid.isEmpty) return;
    await _db.collection('users').doc(uid).set(
      {'allowTagsFrom': allowTagsFrom},
      SetOptions(merge: true),
    );
  }
}
