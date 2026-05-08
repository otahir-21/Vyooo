import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

enum CreatorSubscriptionStatus { active, paused, cancelled }

class CreatorSubscriptionRecord {
  const CreatorSubscriptionRecord({
    required this.id,
    required this.subscriberId,
    required this.creatorId,
    required this.creatorName,
    required this.creatorHandle,
    required this.creatorAvatarUrl,
    required this.status,
    required this.billingCycle,
    required this.pricePerMonth,
    required this.currencyCode,
    this.createdAt,
    this.updatedAt,
    this.cancelledAt,
  });

  final String id;
  final String subscriberId;
  final String creatorId;
  final String creatorName;
  final String creatorHandle;
  final String creatorAvatarUrl;
  final CreatorSubscriptionStatus status;
  final String billingCycle;
  final double pricePerMonth;
  final String currencyCode;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? cancelledAt;

  bool get isActive => status == CreatorSubscriptionStatus.active;
  bool get isPaused => status == CreatorSubscriptionStatus.paused;
  bool get isCancelled => status == CreatorSubscriptionStatus.cancelled;

  String get monthlyPriceLabel => '${currencyCode.toUpperCase()} ${pricePerMonth.toStringAsFixed(2)}';

  factory CreatorSubscriptionRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawStatus = (data['status'] as String? ?? 'active').trim().toLowerCase();
    final status = switch (rawStatus) {
      'paused' => CreatorSubscriptionStatus.paused,
      'cancelled' => CreatorSubscriptionStatus.cancelled,
      _ => CreatorSubscriptionStatus.active,
    };
    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;
    return CreatorSubscriptionRecord(
      id: doc.id,
      subscriberId: (data['subscriberId'] as String? ?? '').trim(),
      creatorId: (data['creatorId'] as String? ?? '').trim(),
      creatorName: (data['creatorName'] as String? ?? '').trim(),
      creatorHandle: (data['creatorHandle'] as String? ?? '').trim(),
      creatorAvatarUrl: (data['creatorAvatarUrl'] as String? ?? '').trim(),
      status: status,
      billingCycle: (data['billingCycle'] as String? ?? 'monthly').trim(),
      pricePerMonth: (data['pricePerMonth'] as num?)?.toDouble() ?? 0,
      currencyCode: (data['currencyCode'] as String? ?? 'usd').trim(),
      createdAt: ts(data['createdAt']),
      updatedAt: ts(data['updatedAt']),
      cancelledAt: ts(data['cancelledAt']),
    );
  }
}

class CreatorSubscriptionService {
  CreatorSubscriptionService._();
  static final CreatorSubscriptionService _instance =
      CreatorSubscriptionService._();
  factory CreatorSubscriptionService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'creatorSubscriptions';
  static const String _requestsCollection = 'creator_subscription_requests';

  String get _currentUid => (AuthService().currentUser?.uid ?? '').trim();

  String _docIdFor(String subscriberId, String creatorId) =>
      '${subscriberId}_$creatorId';

  Future<void> _submitActionRequest({
    required String action,
    required String creatorId,
    required Map<String, dynamic> payload,
  }) async {
    final userId = _currentUid;
    if (userId.isEmpty) {
      throw StateError('You must be signed in');
    }
    final cleanCreatorId = creatorId.trim();
    if (cleanCreatorId.isEmpty) {
      throw StateError('Creator id is required');
    }
    final reqRef = _firestore.collection(_requestsCollection).doc();
    await reqRef.set({
      'userId': userId,
      'creatorId': cleanCreatorId,
      'action': action,
      ...payload,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final result = await reqRef.snapshots().firstWhere(
      (snap) {
        final data = snap.data();
        if (data == null) return false;
        final status = (data['status'] as String? ?? '').trim().toLowerCase();
        return status == 'done' || status == 'error';
      },
    );
    final data = result.data() ?? const <String, dynamic>{};
    final status = (data['status'] as String? ?? '').trim().toLowerCase();
    if (status == 'error') {
      final message =
          (data['error'] as String?)?.trim() ?? 'Subscription action failed';
      throw StateError(message);
    }
  }

  Stream<List<CreatorSubscriptionRecord>> watchForCurrentSubscriber() {
    final uid = _currentUid;
    if (uid.isEmpty) return const Stream<List<CreatorSubscriptionRecord>>.empty();
    return _firestore
        .collection(_collection)
        .where('subscriberId', isEqualTo: uid)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(CreatorSubscriptionRecord.fromDoc)
              .toList(growable: false),
        );
  }

  Future<CreatorSubscriptionRecord?> getForCurrentSubscriberByCreator(
    String creatorId,
  ) async {
    final uid = _currentUid;
    final cleanCreatorId = creatorId.trim();
    if (uid.isEmpty || cleanCreatorId.isEmpty) return null;
    final doc = await _firestore
        .collection(_collection)
        .doc(_docIdFor(uid, cleanCreatorId))
        .get();
    if (!doc.exists) return null;
    return CreatorSubscriptionRecord.fromDoc(doc);
  }

  Future<void> subscribeToCreator({
    required String creatorId,
    required String creatorName,
    required String creatorHandle,
    required String creatorAvatarUrl,
    required String billingCycle,
    required double pricePerMonth,
    String currencyCode = 'usd',
  }) async {
    final subscriberId = _currentUid;
    final cleanCreatorId = creatorId.trim();
    if (subscriberId.isEmpty || cleanCreatorId.isEmpty) {
      throw StateError('Missing subscriber or creator id');
    }
    if (subscriberId == cleanCreatorId) {
      throw StateError('Cannot subscribe to your own profile');
    }
    await _submitActionRequest(
      action: 'subscribe',
      creatorId: cleanCreatorId,
      payload: {
        'subscriberId': subscriberId,
        'creatorName': creatorName.trim(),
        'creatorHandle': creatorHandle.trim(),
        'creatorAvatarUrl': creatorAvatarUrl.trim(),
        'billingCycle': billingCycle.trim(),
        'pricePerMonth': pricePerMonth,
        'currencyCode': currencyCode.trim().toLowerCase(),
      },
    );
  }

  Future<void> cancelSubscription({
    required String creatorId,
  }) async {
    final subscriberId = _currentUid;
    final cleanCreatorId = creatorId.trim();
    if (subscriberId.isEmpty || cleanCreatorId.isEmpty) return;
    await _submitActionRequest(
      action: 'cancel',
      creatorId: cleanCreatorId,
      payload: {'subscriberId': subscriberId},
    );
  }

  Future<void> resumeSubscription({
    required String creatorId,
  }) async {
    final subscriberId = _currentUid;
    final cleanCreatorId = creatorId.trim();
    if (subscriberId.isEmpty || cleanCreatorId.isEmpty) return;
    await _submitActionRequest(
      action: 'resume',
      creatorId: cleanCreatorId,
      payload: {'subscriberId': subscriberId},
    );
  }

  /// Reactive stream of active subscriber count for a creator.
  Stream<int> subscriberCountStream(String creatorId) {
    if (creatorId.isEmpty) return const Stream<int>.empty();
    return _firestore
        .collection(_collection)
        .where('creatorId', isEqualTo: creatorId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((q) => q.docs.length);
  }

  /// One-time fetch of active subscriber count for a creator.
  Future<int> getSubscriberCount(String creatorId) async {
    if (creatorId.isEmpty) return 0;
    try {
      final agg = await _firestore
          .collection(_collection)
          .where('creatorId', isEqualTo: creatorId)
          .where('status', isEqualTo: 'active')
          .count()
          .get();
      return agg.count ?? 0;
    } catch (_) {
      try {
        final q = await _firestore
            .collection(_collection)
            .where('creatorId', isEqualTo: creatorId)
            .where('status', isEqualTo: 'active')
            .get();
        return q.docs.length;
      } catch (_) {
        return 0;
      }
    }
  }
}
