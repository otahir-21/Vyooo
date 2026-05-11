import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/parent_consent_constants.dart';
import 'user_service.dart';

/// Firestore collection [parental_consents]: minor-initiated requests; parent approves/denies.
class ParentalConsentService {
  ParentalConsentService._();
  static final ParentalConsentService _instance = ParentalConsentService._();
  factory ParentalConsentService() => _instance;

  static const String collectionName = 'parental_consents';

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Creates a pending consent doc and moves the minor to [ParentConsentStatusValue.pending].
  Future<String> createPendingRequest({
    required String minorUid,
    required String minorUsername,
    required String parentEmail,
    required String parentPhoneRaw,
  }) async {
    final email = parentEmail.trim().toLowerCase();
    final phone = UserService.normalizePhone(parentPhoneRaw);
    if (email.isEmpty && (phone.isEmpty || !phone.startsWith('+'))) {
      throw StateError('Enter your parent or guardian’s email or phone number.');
    }
    final ref = _db.collection(collectionName).doc();
    final consentId = ref.id;
    final consentPayload = <String, dynamic>{
      'minorUid': minorUid,
      'minorUsername': minorUsername.trim(),
      'parentEmailLower': email,
      'parentPhoneNormalized': phone,
      'status': 'pending',
      // Rules require a real Firestore timestamp (not [FieldValue.serverTimestamp]).
      'createdAt': Timestamp.now(),
    };
    final userRef = _db.collection('users').doc(minorUid);
    final userPayload = <String, dynamic>{
      'parentConsentStatus': ParentConsentStatusValue.pending,
      'parentConsentId': consentId,
      'parentInviteEmail': email,
      'parentInvitePhone': phone,
    };
    // Two sequential writes (not one batch): [minorParentInviteSubmit] uses [get] on the
    // consent doc; evaluating that against an in-batch write is fragile across SDKs.
    // Consent is created first; then the user merge sees a committed consent id.
    await ref.set(consentPayload);
    try {
      await userRef.set(userPayload, SetOptions(merge: true));
    } catch (e) {
      try {
        await ref.delete();
      } catch (_) {
        // Best-effort rollback; rules allow the minor to delete own [pending] consent.
      }
      rethrow;
    }
    return consentId;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> consentStream(String consentId) {
    return _db.collection(collectionName).doc(consentId).snapshots();
  }

  /// Pending requests where the signed-in parent matches invite email (normalized).
  Stream<QuerySnapshot<Map<String, dynamic>>> pendingByParentEmail(String emailLower) {
    if (emailLower.isEmpty) {
      return const Stream.empty();
    }
    return _db
        .collection(collectionName)
        .where('parentEmailLower', isEqualTo: emailLower)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// Pending requests where the signed-in parent matches invite phone.
  Stream<QuerySnapshot<Map<String, dynamic>>> pendingByParentPhone(String normalizedPhone) {
    if (normalizedPhone.isEmpty || !normalizedPhone.startsWith('+')) {
      return const Stream.empty();
    }
    return _db
        .collection(collectionName)
        .where('parentPhoneNormalized', isEqualTo: normalizedPhone)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> approveAsParent(String consentId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Sign in to approve.');
    }
    await _db.collection(collectionName).doc(consentId).update({
      'status': 'approved',
      'parentUid': uid,
      'respondedAt': Timestamp.now(),
    });
  }

  Future<void> denyAsParent(String consentId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Sign in to respond.');
    }
    await _db.collection(collectionName).doc(consentId).update({
      'status': 'denied',
      'parentUid': '',
      'respondedAt': Timestamp.now(),
    });
  }

  /// Minor device: mirror consent outcome onto [users/{minorUid}] (Firestore rules enforce).
  Future<void> minorSyncUserDocFromConsent({
    required String minorUid,
    required String consentId,
  }) async {
    final cid = consentId.replaceAll(RegExp(r'\s+'), '');
    if (cid.isEmpty) return;
    final snap = await _db.collection(collectionName).doc(cid).get();
    final data = snap.data();
    if (data == null) return;
    if ((data['minorUid'] as String?) != minorUid) return;
    final status = (data['status'] as String?) ?? '';
    if (status == 'approved') {
      final parentUid = (data['parentUid'] as String?)?.trim() ?? '';
      if (parentUid.isEmpty) return;
      await UserService().mergeMinorParentConsentOutcome(
        uid: minorUid,
        parentConsentStatus: ParentConsentStatusValue.approved,
        parentUid: parentUid,
      );
    } else if (status == 'denied') {
      await UserService().mergeMinorParentConsentOutcome(
        uid: minorUid,
        parentConsentStatus: ParentConsentStatusValue.denied,
        parentUid: '',
      );
    }
  }
}
