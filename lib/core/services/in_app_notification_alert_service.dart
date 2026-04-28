import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'local_notification_service.dart';

class InAppNotificationAlertService {
  InAppNotificationAlertService._();
  static final InAppNotificationAlertService instance =
      InAppNotificationAlertService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  String? _uid;
  bool _primed = false;
  final Set<String> _shownIds = <String>{};
  final List<String> _pendingTexts = <String>[];
  bool _showingBanner = false;

  void startForUser(String uid) {
    if (uid.isEmpty) return;
    if (_uid == uid && _sub != null) return;
    stop();
    _uid = uid;
    _sub = _db
        .collection('notifications')
        .where('recipientId', isEqualTo: uid)
        .limit(50)
        .snapshots()
        .listen(_onSnapshot, onError: (_) {});
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _uid = null;
    _primed = false;
    _shownIds.clear();
    _pendingTexts.clear();
    _showingBanner = false;
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    if (!_primed) {
      _primed = true;
      return;
    }
    for (final change in snap.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      final id = change.doc.id;
      if (_shownIds.contains(id)) continue;
      final text = _textFromData(change.doc.data() ?? const <String, dynamic>{});
      if (text.isEmpty) continue;
      _shownIds.add(id);
      _pendingTexts.add(text);
    }
    _drainBannerQueue();
  }

  String _textFromData(Map<String, dynamic> data) {
    final actor = ((data['actorUsername'] as String?) ?? '').trim();
    final message = ((data['message'] as String?) ?? '').trim();
    return actor.isEmpty ? message : '$actor $message';
  }

  Future<void> _drainBannerQueue() async {
    if (_showingBanner) return;
    if (_pendingTexts.isEmpty) return;
    _showingBanner = true;
    try {
      while (_pendingTexts.isNotEmpty) {
        final text = _pendingTexts.removeAt(0);
        await LocalNotificationService.instance.show(
          title: 'Vyooo',
          body: text,
        );
        await Future<void>.delayed(const Duration(milliseconds: 1800));
      }
    } finally {
      _showingBanner = false;
    }
  }
}
