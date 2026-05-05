import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

class PresenceService with WidgetsBindingObserver {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _uid;
  Timer? _throttle;
  bool _observing = false;

  DocumentReference<Map<String, dynamic>> _presenceDoc(String uid) =>
      _db.collection('users').doc(uid).collection('presence').doc('current');

  void start(String uid) {
    if (uid.isEmpty) return;
    _uid = uid;
    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
    }
    _setOnline(true);
  }

  void stop() {
    if (_uid != null) _setOnline(false);
    _throttle?.cancel();
    _throttle = null;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    _uid = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_uid == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _setOnline(true);
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _setOnline(false);
    }
  }

  void _setOnline(bool online) {
    final uid = _uid;
    if (uid == null) return;
    if (_throttle?.isActive == true && online) return;
    _throttle?.cancel();
    _throttle = Timer(const Duration(seconds: 5), () {});
    _presenceDoc(uid).set({
      'isOnline': online,
      'lastActiveAt': FieldValue.serverTimestamp(),
    }).catchError((_) {});
  }

  Stream<Map<String, dynamic>?> watchPresence(String uid) {
    if (uid.isEmpty) return Stream.value(null);
    return _presenceDoc(uid).snapshots().map((snap) => snap.data());
  }
}
