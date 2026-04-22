import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Handles incoming app/universal links and extracts reel ids.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  AppLinks? _appLinks;
  StreamSubscription<Uri>? _sub;
  bool _initialized = false;

  final StreamController<String> _reelLinkController =
      StreamController<String>.broadcast();
  final StreamController<String> _profileLinkController =
      StreamController<String>.broadcast();

  String? _pendingReelId;
  String? _pendingProfileRef;

  Stream<String> get reelLinkStream => _reelLinkController.stream;
  Stream<String> get profileLinkStream => _profileLinkController.stream;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _appLinks = AppLinks();
    } on MissingPluginException catch (e) {
      debugPrint('Deep links unavailable (plugin not registered yet): $e');
      return;
    }
    try {
      final initial = await _appLinks!.getInitialLink();
      _handleUri(initial);
    } on MissingPluginException catch (e) {
      debugPrint('Deep links unavailable (initial link): $e');
      return;
    } catch (e) {
      debugPrint('Deep link initial parse failed: $e');
    }
    try {
      _sub = _appLinks!.uriLinkStream.listen(
        _handleUri,
        onError: (Object error) {
          debugPrint('Deep link stream error: $error');
        },
      );
    } on MissingPluginException catch (e) {
      debugPrint('Deep links unavailable (stream): $e');
    }
  }

  String? takePendingReelId() {
    final id = _pendingReelId;
    _pendingReelId = null;
    return id;
  }

  String? takePendingProfileRef() {
    final profile = _pendingProfileRef;
    _pendingProfileRef = null;
    return profile;
  }

  void _handleUri(Uri? uri) {
    if (uri == null) return;
    final reelId = _extractReelId(uri);
    if (reelId != null && reelId.isNotEmpty) {
      _pendingReelId = reelId;
      _reelLinkController.add(reelId);
    }
    final profileRef = _extractProfileRef(uri);
    if (profileRef != null && profileRef.isNotEmpty) {
      _pendingProfileRef = profileRef;
      _profileLinkController.add(profileRef);
    }
  }

  String? _extractReelId(Uri uri) {
    final q = uri.queryParameters['reel']?.trim();
    if (q != null && q.isNotEmpty) return q;

    if (uri.scheme == 'vyooo' &&
        uri.host == 'reel' &&
        uri.pathSegments.isNotEmpty) {
      final id = uri.pathSegments.first.trim();
      if (id.isNotEmpty) return id;
    }

    final path = uri.pathSegments;
    if (path.length >= 2 && path.first == 'reel') {
      final id = path[1].trim();
      if (id.isNotEmpty) return id;
    }
    return null;
  }

  String? _extractProfileRef(Uri uri) {
    final q = uri.queryParameters['profile']?.trim();
    if (q != null && q.isNotEmpty) return q;

    if (uri.scheme == 'vyooo' &&
        uri.host == 'profile' &&
        uri.pathSegments.isNotEmpty) {
      final id = uri.pathSegments.first.trim();
      if (id.isNotEmpty) return id;
    }

    final path = uri.pathSegments;
    if (path.length >= 2 && path.first == 'profile') {
      final id = path[1].trim();
      if (id.isNotEmpty) return id;
    }
    return null;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _reelLinkController.close();
    await _profileLinkController.close();
  }
}
