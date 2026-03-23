import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/live_chat_message_model.dart';
import '../models/live_stream_model.dart';

/// Firestore operations for live streams.
/// Collection: streams/{streamId}
/// Subcollection: streams/{streamId}/messages/{msgId}
class LiveStreamService {
  LiveStreamService._();
  static final LiveStreamService _instance = LiveStreamService._();
  factory LiveStreamService() => _instance;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  static const String _streamsCol = 'streams';
  static const String _messagesCol = 'messages';

  // ── Stream CRUD ─────────────────────────────────────────────────────────────

  /// Creates a new stream document. Returns the generated stream ID.
  Future<String> createStream({
    required String hostId,
    required String hostUsername,
    String? hostProfileImage,
    required String title,
    String description = '',
    String category = '',
    List<String> tags = const [],
    int pricePerMinute = 0,
  }) async {
    // End any stale live streams for this host before creating a new one
    final stale = await _db
        .collection(_streamsCol)
        .where('hostId', isEqualTo: hostId)
        .where('status', isEqualTo: LiveStreamStatus.live.name)
        .get();
    for (final doc in stale.docs) {
      doc.reference.update({
        'status': LiveStreamStatus.ended.name,
        'endedAt': FieldValue.serverTimestamp(),
      }).ignore();
    }

    final ref = _db.collection(_streamsCol).doc();
    final model = LiveStreamModel(
      id: ref.id,
      hostId: hostId,
      hostUsername: hostUsername,
      hostProfileImage: hostProfileImage,
      title: title,
      description: description,
      category: category,
      tags: tags,
      pricePerMinute: pricePerMinute,
      status: LiveStreamStatus.live,
      viewerCount: 0,
      likeCount: 0,
      agoraChannelName: ref.id, // channel name = doc ID
      hostAgoraUid: 0, // updated after Agora join
      createdAt: Timestamp.now(),
      savedToProfile: false,
    );
    await ref.set(model.toJson());
    return ref.id;
  }

  /// Updates the host's Agora UID after joining the channel.
  Future<void> updateHostAgoraUid(String streamId, int uid) async {
    await _db.collection(_streamsCol).doc(streamId).update({'hostAgoraUid': uid});
  }

  /// Updates stream metadata (title, description, etc).
  Future<void> updateStreamMetadata({
    required String streamId,
    String? title,
    String? description,
    String? category,
    List<String>? tags,
    int? pricePerMinute,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    if (category != null) data['category'] = category;
    if (tags != null) data['tags'] = tags;
    if (pricePerMinute != null) data['pricePerMinute'] = pricePerMinute;
    if (data.isEmpty) return;
    await _db.collection(_streamsCol).doc(streamId).update(data);
  }

  /// Writes a heartbeat timestamp so the discover list can filter out crashed/stale streams.
  Future<void> updateHeartbeat(String streamId) async {
    await _db.collection(_streamsCol).doc(streamId).update({
      'lastHeartbeat': FieldValue.serverTimestamp(),
    });
  }

  /// Marks stream as ended.
  Future<void> endStream(String streamId, {bool savedToProfile = false}) async {
    await _db.collection(_streamsCol).doc(streamId).update({
      'status': LiveStreamStatus.ended.name,
      'endedAt': FieldValue.serverTimestamp(),
      'savedToProfile': savedToProfile,
    });
  }

  /// Fetches a single stream document once.
  Future<LiveStreamModel?> getStream(String streamId) async {
    final doc = await _db.collection(_streamsCol).doc(streamId).get();
    if (!doc.exists || doc.data() == null) return null;
    return LiveStreamModel.fromJson(doc.data()!);
  }

  /// Real-time stream of a single stream document.
  Stream<LiveStreamModel?> streamDoc(String streamId) {
    return _db.collection(_streamsCol).doc(streamId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return LiveStreamModel.fromJson(snap.data()!);
    });
  }

  /// Real-time list of all currently live streams (for discover / feed).
  /// Only returns streams started within the last 8 hours to avoid stale docs.
  /// Deduplicates by hostId — shows only the most recent stream per host.
  Stream<List<LiveStreamModel>> liveStreams() {
    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 8)),
    );
    return _db
        .collection(_streamsCol)
        .where('status', isEqualTo: LiveStreamStatus.live.name)
        .where('createdAt', isGreaterThan: cutoff)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      final now = DateTime.now();
      final heartbeatCutoff = now.subtract(const Duration(minutes: 2));
      final newStreamCutoff = now.subtract(const Duration(minutes: 1));
      final seen = <String>{};
      final result = <LiveStreamModel>[];
      for (final d in snap.docs) {
        final data = d.data();
        final heartbeat = (data['lastHeartbeat'] as Timestamp?)?.toDate();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? now;
        // Keep if heartbeat is recent, OR stream just started (no heartbeat yet)
        final isActive = (heartbeat != null && heartbeat.isAfter(heartbeatCutoff)) ||
            (heartbeat == null && createdAt.isAfter(newStreamCutoff));
        if (!isActive) continue;
        final model = LiveStreamModel.fromJson(data);
        if (seen.add(model.hostId)) result.add(model);
      }
      return result;
    });
  }

  /// Real-time list of past streams saved to a user's profile.
  Stream<List<LiveStreamModel>> savedStreams(String hostId) {
    return _db
        .collection(_streamsCol)
        .where('hostId', isEqualTo: hostId)
        .where('savedToProfile', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => LiveStreamModel.fromJson(d.data())).toList());
  }

  // ── Viewer count ────────────────────────────────────────────────────────────

  /// Atomically increments viewer count when a viewer joins.
  Future<void> viewerJoined(String streamId) async {
    await _db.collection(_streamsCol).doc(streamId).update({
      'viewerCount': FieldValue.increment(1),
    });
  }

  /// Atomically decrements viewer count when a viewer leaves.
  Future<void> viewerLeft(String streamId) async {
    await _db.collection(_streamsCol).doc(streamId).update({
      'viewerCount': FieldValue.increment(-1),
    });
  }

  // ── Likes ───────────────────────────────────────────────────────────────────

  Future<void> addLike(String streamId) async {
    await _db.collection(_streamsCol).doc(streamId).update({
      'likeCount': FieldValue.increment(1),
    });
  }

  // ── Chat ────────────────────────────────────────────────────────────────────

  /// Sends a chat message. Capped to last 200 per stream (enforced by Security Rules).
  Future<void> sendMessage({
    required String streamId,
    required String userId,
    required String username,
    String? profileImage,
    required String message,
    ChatMessageType type = ChatMessageType.text,
  }) async {
    final ref = _db.collection(_streamsCol).doc(streamId).collection(_messagesCol).doc();
    await ref.set({
      'id': ref.id,
      'userId': userId,
      'username': username,
      'profileImage': profileImage ?? '',
      'message': message,
      'type': type.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Real-time stream of chat messages, newest last, limited to 50.
  Stream<List<LiveChatMessageModel>> chatMessages(String streamId) {
    return _db
        .collection(_streamsCol)
        .doc(streamId)
        .collection(_messagesCol)
        .orderBy('createdAt', descending: false)
        .limitToLast(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LiveChatMessageModel.fromJson(d.id, d.data()))
            .toList());
  }
}
