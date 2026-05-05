import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/call_session_model.dart';

class CallSignalingService {
  CallSignalingService._();
  static final CallSignalingService _instance = CallSignalingService._();
  factory CallSignalingService() => _instance;

  FirebaseFirestore get _fs => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _callsCol =>
      _fs.collection('callSessions');

  Future<CallSessionModel> startCall({
    required String chatId,
    required String callerId,
    required List<String> participantIds,
    required String type,
  }) async {
    if (!participantIds.contains(callerId)) {
      throw ArgumentError('callerId must be in participantIds');
    }
    if (type != CallType.audio && type != CallType.video) {
      throw ArgumentError('type must be audio or video');
    }

    debugPrint(
      '[CallSignaling] startCall: chatId=$chatId callerId=$callerId '
      'participantIds=$participantIds type=$type',
    );

    final activeQuery = await _callsCol
        .where('chatId', isEqualTo: chatId)
        .where('participantIds', arrayContains: callerId)
        .where('status', whereIn: [CallStatus.ringing, CallStatus.active])
        .limit(1)
        .get();
    if (activeQuery.docs.isNotEmpty) {
      throw StateError('An active or ringing call already exists in this chat');
    }

    final ref = _callsCol.doc();
    final calleeIds = participantIds.where((id) => id != callerId).toList();
    final channelName = 'call_${ref.id}';

    debugPrint(
      '[CallSignaling] creating callSession: ${ref.id} channel=$channelName (len=${channelName.length})',
    );

    final model = CallSessionModel(
      id: ref.id,
      chatId: chatId,
      callerId: callerId,
      calleeIds: calleeIds,
      participantIds: participantIds,
      type: type,
      status: CallStatus.ringing,
      agoraChannelName: channelName,
    );

    await ref.set(model.toJson());
    debugPrint('[CallSignaling] callSession created successfully');
    return model;
  }

  Future<void> acceptCall({required String callId, required String uid}) async {
    debugPrint('[CallSignaling] acceptCall: callId=$callId uid=$uid');
    final ref = _callsCol.doc(callId);
    try {
      await _fs.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) {
          debugPrint('[CallSignaling] acceptCall: doc not found');
          return;
        }
        final data = snap.data()!;
        final status = data['status'] as String? ?? '';
        debugPrint('[CallSignaling] acceptCall: current status=$status');
        if (status != CallStatus.ringing) {
          debugPrint('[CallSignaling] acceptCall: not ringing, skipping');
          return;
        }
        final calleeIds =
            (data['calleeIds'] as List?)?.whereType<String>().toList() ?? [];
        if (!calleeIds.contains(uid)) {
          debugPrint('[CallSignaling] acceptCall: uid not in calleeIds');
          return;
        }
        debugPrint('[CallSignaling] acceptCall: updating to active');
        txn.update(ref, {
          'status': CallStatus.active,
          'acceptedAt': FieldValue.serverTimestamp(),
          'startedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      debugPrint('[CallSignaling] acceptCall: transaction complete');
    } catch (e, st) {
      debugPrint('[CallSignaling] acceptCall FAILED: $e');
      dev.log(
        'CallSignalingService.acceptCall failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> declineCall({
    required String callId,
    required String uid,
  }) async {
    final ref = _callsCol.doc(callId);
    try {
      await _fs.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) return;
        final data = snap.data()!;
        final status = data['status'] as String? ?? '';
        if (status != CallStatus.ringing) return;
        final calleeIds =
            (data['calleeIds'] as List?)?.whereType<String>().toList() ?? [];
        if (!calleeIds.contains(uid)) return;
        txn.update(ref, {
          'status': CallStatus.declined,
          'endedAt': FieldValue.serverTimestamp(),
          'endedBy': uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e, st) {
      dev.log(
        'CallSignalingService.declineCall failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> endCall({required String callId, required String uid}) async {
    final ref = _callsCol.doc(callId);
    try {
      await _fs.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) return;
        final data = snap.data()!;
        final status = data['status'] as String? ?? '';
        if (status != CallStatus.ringing && status != CallStatus.active) return;
        final participantIds =
            (data['participantIds'] as List?)?.whereType<String>().toList() ??
            [];
        if (!participantIds.contains(uid)) return;

        int? duration;
        if (status == CallStatus.active) {
          final acceptedAt = data['acceptedAt'] as Timestamp?;
          if (acceptedAt != null) {
            duration = DateTime.now().difference(acceptedAt.toDate()).inSeconds;
          }
        }

        txn.update(ref, {
          'status': status == CallStatus.ringing
              ? CallStatus.missed
              : CallStatus.ended,
          'endedAt': FieldValue.serverTimestamp(),
          'endedBy': uid,
          if (duration != null) 'durationSeconds': duration,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e, st) {
      dev.log('CallSignalingService.endCall failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Stream<CallSessionModel?> watchCall(String callId) {
    if (callId.isEmpty) return Stream.value(null);
    return _callsCol.doc(callId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return CallSessionModel.fromFirestore(snap);
    });
  }

  Stream<List<CallSessionModel>> watchIncomingCalls(String uid) {
    if (uid.isEmpty) return Stream.value([]);
    return _callsCol
        .where('participantIds', arrayContains: uid)
        .where('status', isEqualTo: CallStatus.ringing)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => CallSessionModel.fromFirestore(d))
              .where((c) => c.calleeIds.contains(uid))
              .toList(),
        );
  }

  Future<void> updateAgoraUid({
    required String callId,
    required String uid,
    required int agoraUid,
  }) async {
    try {
      await _callsCol.doc(callId).update({
        'agoraUidMap.$uid': agoraUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      dev.log(
        'CallSignalingService.updateAgoraUid failed',
        error: e,
        stackTrace: st,
      );
    }
  }
}
