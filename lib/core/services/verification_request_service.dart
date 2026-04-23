import 'package:cloud_firestore/cloud_firestore.dart';

class VerificationRequestService {
  VerificationRequestService._();
  static final VerificationRequestService _instance = VerificationRequestService._();
  factory VerificationRequestService() => _instance;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  static const String _collection = 'verification_requests';

  Future<Map<String, dynamic>?> getLatestRequestForUser(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('uid', isEqualTo: uid)
          .limit(20)
          .get();
      if (snap.docs.isEmpty) return null;
      final docs = snap.docs.toList()
        ..sort((a, b) {
          final aTs = a.data()['submittedAt'];
          final bTs = b.data()['submittedAt'];
          final aMs = aTs is Timestamp ? aTs.millisecondsSinceEpoch : 0;
          final bMs = bTs is Timestamp ? bTs.millisecondsSinceEpoch : 0;
          return bMs.compareTo(aMs);
        });
      return docs.first.data();
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasOpenRequest(String uid) async {
    final latest = await getLatestRequestForUser(uid);
    if (latest == null) return false;
    final status = (latest['status'] as String? ?? 'none').toLowerCase();
    return status == 'pending' || status == 'in_review' || status == 'submitted';
  }

  Future<void> submitRequest({
    required String uid,
    required String email,
    required String fullName,
    required String country,
    required String idType,
    String notes = '',
    String? pdfUrl,
    String? pdfFileName,
  }) async {
    await _firestore.collection(_collection).add({
      'uid': uid,
      'email': email.trim(),
      'fullName': fullName.trim(),
      'country': country.trim(),
      'idType': idType.trim(),
      'notes': notes.trim(),
      'pdfUrl': (pdfUrl ?? '').trim(),
      'pdfFileName': (pdfFileName ?? '').trim(),
      'status': 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
      'reviewedAt': null,
      'reviewedBy': null,
      'reviewNote': null,
    });
  }
}

