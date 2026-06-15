import 'package:cloud_firestore/cloud_firestore.dart';

import '../moderation/content_moderation.dart';
import 'auth_service.dart';

enum ModerationDisputeResult {
  success,
  alreadyPending,
  notOwner,
  failed,
}

/// Owner disputes and staff moderation helpers.
class ModerationService {
  ModerationService._();
  static final ModerationService _instance = ModerationService._();
  factory ModerationService() => _instance;

  final _firestore = FirebaseFirestore.instance;

  static const _disputesCol = 'moderation_disputes';

  static bool isCurrentUserOwner(String ownerId) {
    final uid = AuthService().currentUser?.uid ?? '';
    return uid.isNotEmpty && uid == ownerId.trim();
  }

  String _collectionForKind(ModeratedContentKind kind) {
    switch (kind) {
      case ModeratedContentKind.imageStory:
      case ModeratedContentKind.videoStory:
        return 'stories';
      case ModeratedContentKind.imagePost:
      case ModeratedContentKind.videoPost:
      case ModeratedContentKind.vrStream:
        return 'reels';
    }
  }

  String _contentTypeField(ModeratedContentKind kind) {
    switch (kind) {
      case ModeratedContentKind.imageStory:
        return 'image_story';
      case ModeratedContentKind.videoStory:
        return 'video_story';
      case ModeratedContentKind.imagePost:
        return 'image_post';
      case ModeratedContentKind.videoPost:
        return 'video_post';
      case ModeratedContentKind.vrStream:
        return 'vr_stream';
    }
  }

  /// Submits an owner dispute for crowd-report coverage.
  Future<ModerationDisputeResult> submitDispute({
    required String contentId,
    required ModeratedContentKind contentKind,
    required String ownerId,
  }) async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null || uid.isEmpty) return ModerationDisputeResult.notOwner;
    if (uid != ownerId.trim()) return ModerationDisputeResult.notOwner;
    final id = contentId.trim();
    if (id.isEmpty) return ModerationDisputeResult.failed;

    final contentCol = _collectionForKind(contentKind);
    final disputeId = '${contentCol}_$id';

    try {
      final contentRef = _firestore.collection(contentCol).doc(id);
      final contentSnap = await contentRef.get();
      if (!contentSnap.exists) return ModerationDisputeResult.failed;
      final data = contentSnap.data() ?? {};
      if ((data['userId'] as String?) != uid) {
        return ModerationDisputeResult.notOwner;
      }
      final moderation = data['moderation'];
      if (moderation is! Map ||
          !ContentModeration.isReportCovered(
            Map<String, dynamic>.from(moderation),
          )) {
        return ModerationDisputeResult.failed;
      }
      if (ContentModeration.hasPendingDispute(
        Map<String, dynamic>.from(moderation),
      )) {
        return ModerationDisputeResult.alreadyPending;
      }

      final disputeRef = _firestore.collection(_disputesCol).doc(disputeId);
      final existing = await disputeRef.get();
      if (existing.exists &&
          (existing.data()?['status'] as String?) == 'pending') {
        return ModerationDisputeResult.alreadyPending;
      }

      final batch = _firestore.batch();
      batch.set(disputeRef, {
        'contentId': id,
        'contentCollection': contentCol,
        'contentType': _contentTypeField(contentKind),
        'ownerId': uid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(contentRef, {
        'moderation': {
          ...Map<String, dynamic>.from(moderation),
          'disputeStatus': 'pending',
          'disputeSubmittedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
      await batch.commit();
      return ModerationDisputeResult.success;
    } catch (_) {
      return ModerationDisputeResult.failed;
    }
  }

  /// Staff helper: pending disputes for admin dashboard / console tooling.
  Future<List<Map<String, dynamic>>> getPendingDisputes({int limit = 50}) async {
    try {
      final q = await _firestore
          .collection(_disputesCol)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return q.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList(growable: false);
    } catch (_) {
      try {
        final q = await _firestore
            .collection(_disputesCol)
            .where('status', isEqualTo: 'pending')
            .limit(limit)
            .get();
        return q.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList(growable: false);
      } catch (_) {
        return [];
      }
    }
  }

  /// Staff resolves a dispute — restores content or keeps it covered.
  Future<bool> resolveDispute({
    required String disputeId,
    required bool approve,
    String? staffNote,
  }) async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null || uid.isEmpty) return false;
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.data()?['isStaff'] != true) return false;

      final disputeRef = _firestore.collection(_disputesCol).doc(disputeId);
      final disputeSnap = await disputeRef.get();
      if (!disputeSnap.exists) return false;
      final dispute = disputeSnap.data() ?? {};
      final contentId = (dispute['contentId'] as String?) ?? '';
      final contentCol = (dispute['contentCollection'] as String?) ?? '';
      if (contentId.isEmpty || contentCol.isEmpty) return false;

      final contentRef = _firestore.collection(contentCol).doc(contentId);
      final contentSnap = await contentRef.get();
      if (!contentSnap.exists) return false;
      final moderation =
          Map<String, dynamic>.from(contentSnap.data()?['moderation'] as Map? ?? {});

      final batch = _firestore.batch();
      batch.update(disputeRef, {
        'status': approve ? 'approved' : 'rejected',
        'resolvedBy': uid,
        'staffNote': staffNote ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      if (approve) {
        batch.set(contentRef, {
          'moderation': {
            ...moderation,
            'status': 'clear',
            'disputeStatus': 'approved',
            'restoredAt': FieldValue.serverTimestamp(),
            'restoredBy': uid,
          },
          'reportCount': 0,
        }, SetOptions(merge: true));
      } else {
        batch.set(contentRef, {
          'moderation': {
            ...moderation,
            'disputeStatus': 'rejected',
            'disputeRejectedAt': FieldValue.serverTimestamp(),
            'disputeRejectedBy': uid,
          },
        }, SetOptions(merge: true));
      }
      await batch.commit();
      return true;
    } catch (_) {
      return false;
    }
  }
}
